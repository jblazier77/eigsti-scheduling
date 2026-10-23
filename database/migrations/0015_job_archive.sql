-- Apply once after 0014. Archive is reversible job organization, not work completion.
begin;
create table private.job_archive_events(
 id uuid primary key default gen_random_uuid(),job_id uuid not null references public.jobs(id),
 actor_id uuid not null references public.app_users(id),request_id uuid not null,
 before_state text not null,after_state text not null,created_at timestamptz not null default now()
);
alter table private.job_archive_events enable row level security;
revoke all on private.job_archive_events from public,anon,authenticated;
create function public.set_job_archive(p_job_id uuid,p_request_id uuid,p_action text,p_expected text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.jobs%rowtype;prior private.command_requests%rowtype;payload jsonb;target text;old_state text;today date:=(now() at time zone 'America/Chicago')::date;
begin
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_job_id is null or p_request_id is null or p_action is null or p_action not in ('archive','restore') or p_expected is null or p_expected not in ('open','closed','archived') then raise exception using errcode='22023',message='Invalid archive request'; end if;
 payload:=jsonb_build_object('job',p_job_id,'action',p_action,'expected',p_expected);
 -- Same lock order as scheduling; no future booking can slip in while archiving.
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 select * into j from public.jobs where id=p_job_id for update;
 if not found then raise exception using errcode='P0002',message='Job unavailable'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='set_job_archive' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',j.id,'lifecycle',j.lifecycle,'replayed',true);
 end if;
 if j.lifecycle<>p_expected or (p_action='archive' and j.lifecycle='archived') or (p_action='restore' and j.lifecycle='open') then raise exception using errcode='22023',message='Job status changed. Refresh the job before trying again.'; end if;
 if p_action='archive' then
  if exists(select 1 from public.visits v join public.work_items w on w.id=v.work_item_id where w.job_id=j.id and v.state='planned' and v.end_date>=today) then raise exception using errcode='22023',message='Resolve today or future crew dates before archiving this job.'; end if;
  if exists(select 1 from public.contact_commitments c join public.job_contacts t on t.id=c.contact_id and t.job_id=c.job_id where c.job_id=j.id and c.archived_at is null and t.archived_at is null and lower(btrim(t.relationship))='subcontractor' and c.commitment_date>=today) then raise exception using errcode='22023',message='Resolve today or future subcontractor commitments before archiving this job.'; end if;
 end if;
 old_state:=j.lifecycle;target:=case when p_action='archive' then 'archived' else 'open' end;
 update public.jobs set lifecycle=target,updated_at=clock_timestamp(),updated_by=auth.uid() where id=j.id;
 insert into private.job_archive_events(job_id,actor_id,request_id,before_state,after_state) values(j.id,auth.uid(),p_request_id,old_state,target);
 insert into public.audit_events(job_id,actor_id,request_id,operation,changed_fields) values(j.id,auth.uid(),p_request_id,'set_job_archive',array['lifecycle']);
 insert into private.command_requests(actor_id,request_id,operation,payload,result_id) values(auth.uid(),p_request_id,'set_job_archive',payload,j.id);
 return jsonb_build_object('id',j.id,'lifecycle',target,'replayed',false);
end; $$;
revoke all on function public.set_job_archive(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.set_job_archive(uuid,uuid,text,text) to authenticated;

-- Archived/closed jobs remain available as history, outside operational calendars.
create or replace function public.list_schedule(p_start date,p_end date,p_all boolean default false) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not (private.has_role('pm') or private.has_role('lead') or private.has_role('helper')) then raise exception using errcode='42501',message='Schedule access required'; end if;
 if p_start is null or p_end is null or p_end<p_start or p_end-p_start>30 then raise exception using errcode='22023',message='Invalid schedule range'; end if;
 if p_all and not private.has_role('pm') then raise exception using errcode='42501',message='PM required'; end if;
 if (select count(*) from public.visits v join public.work_items w on w.id=v.work_item_id join public.jobs j on j.id=w.job_id
 where j.lifecycle='open' and v.start_date<=p_end and v.end_date>=p_start and v.state<>'cancelled' and
 ((private.has_role('pm') and (p_all or j.responsible_pm=auth.uid())) or (not private.has_role('pm') and exists(select 1 from public.visit_participants p where p.visit_id=v.id and p.user_id=auth.uid()))))>500 then raise exception using errcode='22023',message='Schedule limit exceeded'; end if;
 return coalesce((select jsonb_agg(private.visit_result(v.id) order by v.start_date,v.start_time nulls first,v.id)
 from public.visits v join public.work_items w on w.id=v.work_item_id join public.jobs j on j.id=w.job_id
 where j.lifecycle='open' and v.start_date<=p_end and v.end_date>=p_start and v.state<>'cancelled' and
 ((private.has_role('pm') and (p_all or j.responsible_pm=auth.uid())) or (not private.has_role('pm') and exists(select 1 from public.visit_participants p where p.visit_id=v.id and p.user_id=auth.uid())))),'[]'::jsonb);
end; $$;
notify pgrst,'reload schema';
commit;
