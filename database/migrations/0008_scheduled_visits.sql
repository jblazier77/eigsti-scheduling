-- Apply once after 0001-0007 in the isolated test project. No fixtures.
begin;
create table public.visits (
 id uuid primary key default gen_random_uuid(),
 work_item_id uuid not null references public.work_items(id),
 coordinator_id uuid not null references public.app_users(id),
 start_date date not null, end_date date not null,
 slot text not null check(slot in ('day','all_day','morning','afternoon','timed')),
 start_time time, end_time time,
 required_helpers integer not null default 0 check(required_helpers between 0 and 20),
 certainty text not null default 'tentative' check(certainty in ('tentative','confirmed')),
 state text not null default 'planned' check(state in ('planned','completed','cancelled')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references public.app_users(id), updated_by uuid not null references public.app_users(id),
 check(end_date>=start_date and end_date-start_date<=30),
 check((slot='timed' and start_date=end_date and start_time is not null and end_time is not null and start_time>=time '07:00' and end_time<=time '15:30' and start_time<end_time)
   or (slot<>'timed' and start_time is null and end_time is null)),
 check(extract(isodow from start_date)<6 and extract(isodow from end_date)<6)
);
create table public.visit_participants (
 visit_id uuid not null references public.visits(id), user_id uuid not null references public.app_users(id),
 duty text not null check(duty in ('leading','helping')), primary key(visit_id,user_id)
);
create unique index visit_one_coordinator on public.visit_participants(visit_id) where duty='leading';
create index visits_work_dates on public.visits(work_item_id,start_date,end_date);
create index participants_user on public.visit_participants(user_id,visit_id);
create table private.visit_bookings (
 visit_id uuid not null references public.visits(id), user_id uuid not null references public.app_users(id),
 starts_at timestamptz not null, ends_at timestamptz not null, check(starts_at<ends_at),
 primary key(visit_id,user_id,starts_at)
);
create index booking_overlap on private.visit_bookings(user_id,starts_at,ends_at);
create table private.visit_events (
 id uuid primary key default gen_random_uuid(), visit_id uuid not null references public.visits(id),
 actor_id uuid not null references public.app_users(id), request_id uuid not null,
 operation text not null, snapshot jsonb not null, created_at timestamptz not null default now()
);
alter table private.visit_events enable row level security;
revoke all on private.visit_events from public,anon,authenticated;
alter table public.visits enable row level security;
alter table public.visit_participants enable row level security;
alter table private.visit_bookings enable row level security;
revoke all on public.visits,public.visit_participants,private.visit_bookings from public,anon,authenticated;

create function private.can_read_visit(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.has_role('pm') or exists(select 1 from public.visits v join public.work_items w on w.id=v.work_item_id
 where v.id=p_id and ((private.has_role('lead') and private.can_read_job(w.job_id)) or
 ((private.has_role('lead') or private.has_role('helper')) and exists(select 1 from public.visit_participants p where p.visit_id=v.id and p.user_id=auth.uid()))));
$$;
create function private.visit_result(p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_result jsonb;
begin
 if not private.can_read_visit(p_id) then raise exception using errcode='42501',message='Visit access required'; end if;
 select to_jsonb(v)||jsonb_build_object('job_id',j.id,'job_title',j.title,'description',w.description,
 'day_conflicts',(select count(*) from public.visits other where v.state='planned' and other.state='planned' and other.id<>v.id
 and (v.slot='day' or other.slot='day') and other.start_date<=v.end_date and other.end_date>=v.start_date
 and exists(select 1 from public.visit_participants p join public.visit_participants q on q.user_id=p.user_id where p.visit_id=v.id and q.visit_id=other.id)),
 'participants',coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.display_name,'duty',p.duty) order by p.duty desc,u.display_name,u.id)
 from public.visit_participants p join public.app_users u on u.id=p.user_id where p.visit_id=v.id),'[]'::jsonb)) into v_result
 from public.visits v join public.work_items w on w.id=v.work_item_id join public.jobs j on j.id=w.job_id where v.id=p_id;
 return v_result;
end; $$;

-- Called only inside the scheduling mutex. Lock users in UUID order before checking/writing.
create function private.rebuild_visit(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare v public.visits%rowtype; v_user uuid; v_job uuid;
begin
 select * into strict v from public.visits where id=p_id;
 select job_id into v_job from public.work_items where id=v.work_item_id;
 for v_user in select user_id from public.visit_participants where visit_id=p_id order by user_id loop
  perform pg_advisory_xact_lock(hashtextextended('eigsti:calendar:'||v_user::text,0));
 end loop;
 delete from private.visit_bookings where visit_id=p_id;
 if v.state='planned' then
  if exists(select 1 from public.visit_participants p join public.app_users u on u.id=p.user_id
   where p.visit_id=p_id and (not u.active or (p.duty='leading' and not 'lead'=any(u.roles)) or (p.duty='helping' and not u.roles && array['lead','helper']::text[])))
  then raise exception using errcode='22023',message='Active staff required'; end if;
  insert into private.visit_bookings(visit_id,user_id,starts_at,ends_at)
  select v.id,p.user_id,
   (d::date+case v.slot when 'afternoon' then time '12:00' when 'timed' then v.start_time else time '07:00' end) at time zone 'America/Chicago',
   (d::date+case v.slot when 'morning' then time '12:00' when 'timed' then v.end_time else time '15:30' end) at time zone 'America/Chicago'
  from public.visit_participants p cross join generate_series(0,v.end_date-v.start_date) n
  cross join lateral (select v.start_date+n as d) days
  where p.visit_id=v.id and v.slot<>'day' and extract(isodow from d)<6;
  if exists(select 1 from private.visit_bookings a join private.visit_bookings b on b.user_id=a.user_id and b.visit_id<>a.visit_id
   and a.starts_at<b.ends_at and b.starts_at<a.ends_at where a.visit_id=p_id)
  then raise exception using errcode='23P01',message='Staff scheduling conflict'; end if;
 end if;
 -- Named participants retain shared job information while a noncancelled visit exists.
 -- Cancellation/removal revokes only this entitlement, never work ownership.
 update private.job_access set revoked_at=clock_timestamp() where job_id=v_job and reason='helping_assignment' and revoked_at is null;
 insert into private.job_access(job_id,user_id,reason,created_by)
 select distinct v_job,p.user_id,'helping_assignment',auth.uid() from public.visit_participants p
 join public.visits x on x.id=p.visit_id join public.work_items w on w.id=x.work_item_id
 where w.job_id=v_job and x.state<>'cancelled'
 on conflict(job_id,user_id,reason) do update set revoked_at=null;
end; $$;

create function public.save_visit(p_work_id uuid,p_visit_id uuid,p_request_id uuid,p_patch jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.visits%rowtype; w public.work_items%rowtype; v_job public.jobs%rowtype;
 v_prior private.command_requests%rowtype; v_payload jsonb; k text; v_actor uuid:=auth.uid(); v_new boolean:=p_visit_id is null;
begin
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Visit planning required'; end if;
 if p_work_id is null or p_request_id is null or p_patch is null or jsonb_typeof(p_patch)<>'object' or p_patch='{}'::jsonb then raise exception using errcode='22023',message='Invalid visit'; end if;
 for k in select jsonb_object_keys(p_patch) loop
  if k not in ('start_date','end_date','slot','start_time','end_time','required_helpers','certainty','coordinator_id','state') then raise exception using errcode='22023',message='Invalid visit field'; end if;
  if k='required_helpers' then
   if jsonb_typeof(p_patch->k)<>'number' or (p_patch->>k)!~'^[0-9]{1,2}$' then raise exception using errcode='22023',message='Invalid helper count'; end if;
  elsif k in ('start_time','end_time') and p_patch->k='null'::jsonb then null;
  elsif jsonb_typeof(p_patch->k)<>'string' then raise exception using errcode='22023',message='Invalid visit value'; end if;
 end loop;
 -- Schedule commands serialize before parent locks; no command here acquires a queue lock.
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Visit planning required'; end if;
 select j.* into v_job from public.jobs j join public.work_items x on x.job_id=j.id where x.id=p_work_id for update of j;
 select * into w from public.work_items where id=p_work_id for update;
 if w.id is null then raise exception using errcode='P0002',message='Work unavailable'; end if;
 if not v_new then select * into v from public.visits where id=p_visit_id and work_item_id=p_work_id for update; end if;
 if not v_new and v.id is null then raise exception using errcode='P0002',message='Visit unavailable'; end if;
 if not private.has_role('pm') and not ((v_new and w.responsible_lead=v_actor) or (not v_new and v.coordinator_id=v_actor)) then raise exception using errcode='42501',message='Visit coordinator required'; end if;
 v_payload:=jsonb_build_object('work',p_work_id,'visit',p_visit_id,'patch',p_patch);
 select * into v_prior from private.command_requests where actor_id=v_actor and operation='save_visit' and request_id=p_request_id;
 if found then
  if v_prior.payload<>v_payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return private.visit_result(v_prior.result_id);
 end if;
 if v_job.lifecycle<>'open' or w.completion<>'open' or v.state='completed' then raise exception using errcode='22023',message='Open work required'; end if;
 if v_new then
  if not p_patch ?& array['start_date','end_date','slot','coordinator_id'] then raise exception using errcode='22023',message='Visit dates and coordinator required'; end if;
  v.id:=gen_random_uuid(); v.work_item_id:=p_work_id; v.required_helpers:=0; v.certainty:='tentative'; v.state:='planned';
 end if;
 if p_patch ? 'coordinator_id' then
  if not private.has_role('pm') and (p_patch->>'coordinator_id')::uuid is distinct from v_actor then raise exception using errcode='42501',message='PM required to change coordinator'; end if;
  v.coordinator_id:=(p_patch->>'coordinator_id')::uuid;
 end if;
 perform 1 from public.app_users where id=v.coordinator_id and active and 'lead'=any(roles) for share;
 if not found then raise exception using errcode='22023',message='Active staff required'; end if;
 if p_patch ? 'start_date' then v.start_date:=(p_patch->>'start_date')::date; end if;
 if p_patch ? 'end_date' then v.end_date:=(p_patch->>'end_date')::date; end if;
 if p_patch ? 'slot' then v.slot:=p_patch->>'slot'; end if;
 if p_patch ? 'start_time' then v.start_time:=(p_patch->>'start_time')::time; end if;
 if p_patch ? 'end_time' then v.end_time:=(p_patch->>'end_time')::time; end if;
 if v.slot<>'timed' then v.start_time:=null; v.end_time:=null; end if;
 if p_patch ? 'required_helpers' then v.required_helpers:=(p_patch->>'required_helpers')::integer; end if;
 if p_patch ? 'certainty' then v.certainty:=p_patch->>'certainty'; end if;
 if p_patch ? 'state' then
  if p_patch->>'state' not in ('planned','cancelled') then raise exception using errcode='22023',message='Invalid visit state'; end if;
  v.state:=p_patch->>'state';
 end if;
 if v.required_helpers < (select count(*) from public.visit_participants where visit_id=v.id and duty='helping') then raise exception using errcode='22023',message='Named help exceeds need'; end if;
 if exists(select 1 from public.visit_participants where visit_id=v.id and user_id=v.coordinator_id and duty='helping') then raise exception using errcode='22023',message='Coordinator already helping'; end if;
 if v_new then
  insert into public.visits(id,work_item_id,coordinator_id,start_date,end_date,slot,start_time,end_time,required_helpers,certainty,state,created_by,updated_by)
   values(v.id,w.id,v.coordinator_id,v.start_date,v.end_date,v.slot,v.start_time,v.end_time,v.required_helpers,v.certainty,v.state,v_actor,v_actor);
 else
  update public.visits set coordinator_id=v.coordinator_id,start_date=v.start_date,end_date=v.end_date,slot=v.slot,start_time=v.start_time,end_time=v.end_time,
   required_helpers=v.required_helpers,certainty=v.certainty,state=v.state,updated_by=v_actor,updated_at=clock_timestamp() where id=v.id;
 end if;
 delete from public.visit_participants where visit_id=v.id and duty='leading';
 insert into public.visit_participants values(v.id,v.coordinator_id,'leading');
 perform private.rebuild_visit(v.id);
 insert into private.visit_events(visit_id,actor_id,request_id,operation,snapshot) values(v.id,v_actor,p_request_id,'save_visit',private.visit_result(v.id));
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
 values(w.job_id,v_actor,case when v_new then 'create_visit' else 'update_visit' end,array(select jsonb_object_keys(p_patch) order by 1),p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(v_actor,'save_visit',p_request_id,v_payload,v.id);
 return private.visit_result(v.id);
end; $$;

create function public.staff_visit(p_visit_id uuid,p_request_id uuid,p_helpers uuid[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v public.visits%rowtype; w public.work_items%rowtype; j public.jobs%rowtype; v_ids uuid[]; v_prior private.command_requests%rowtype; v_payload jsonb;
begin
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Visit planning required'; end if;
 if p_request_id is null or p_helpers is null or cardinality(p_helpers)>20 or (cardinality(p_helpers)>0 and array_ndims(p_helpers)<>1) or array_position(p_helpers,null) is not null
 then raise exception using errcode='22023',message='Invalid staffing'; end if;
 select coalesce(array_agg(x order by x),'{}'::uuid[]) into v_ids from (select distinct unnest(p_helpers) x) s;
 if cardinality(v_ids)<>cardinality(p_helpers) then raise exception using errcode='22023',message='Invalid staffing'; end if;
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Visit planning required'; end if;
 select x.* into j from public.jobs x join public.work_items y on y.job_id=x.id join public.visits z on z.work_item_id=y.id where z.id=p_visit_id for update of x;
 select x.* into w from public.work_items x join public.visits y on y.work_item_id=x.id where y.id=p_visit_id for update of x;
 select * into v from public.visits where id=p_visit_id for update;
 if v.id is null then raise exception using errcode='P0002',message='Visit unavailable'; end if;
 if not private.has_role('pm') and v.coordinator_id<>auth.uid() then raise exception using errcode='42501',message='Visit coordinator required'; end if;
 v_payload:=jsonb_build_object('visit',p_visit_id,'helpers',v_ids);
 select * into v_prior from private.command_requests where actor_id=auth.uid() and operation='staff_visit' and request_id=p_request_id;
 if found then
  if v_prior.payload<>v_payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return private.visit_result(v.id);
 end if;
 if j.lifecycle<>'open' or w.completion<>'open' or v.state<>'planned' then raise exception using errcode='22023',message='Open work required'; end if;
 if cardinality(v_ids)>v.required_helpers or v.coordinator_id=any(v_ids) then raise exception using errcode='22023',message='Invalid staffing'; end if;
 if not private.has_role('pm') and exists(select 1 from public.visit_participants where visit_id=v.id and duty='helping' and not user_id=any(v_ids))
 then raise exception using errcode='42501',message='PM required to replace named help'; end if;
 perform id from public.app_users where id=any(v_ids) order by id for share;
 if (select count(*) from public.app_users where id=any(v_ids) and active and roles && array['lead','helper']::text[])<>cardinality(v_ids)
 then raise exception using errcode='22023',message='Active staff required'; end if;
 delete from public.visit_participants where visit_id=v.id and duty='helping';
 insert into public.visit_participants select v.id,unnest(v_ids),'helping';
 perform private.rebuild_visit(v.id);
 update public.visits set updated_at=clock_timestamp(),updated_by=auth.uid() where id=v.id;
 insert into private.visit_events(visit_id,actor_id,request_id,operation,snapshot) values(v.id,auth.uid(),p_request_id,'staff_visit',private.visit_result(v.id));
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id) values(w.job_id,auth.uid(),'staff_visit',array['participants'],p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'staff_visit',p_request_id,v_payload,v.id);
 return private.visit_result(v.id);
end; $$;

create function public.list_job_visits(p_job_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not private.can_read_job(p_job_id) then raise exception using errcode='42501',message='Job access required'; end if;
 return coalesce((select jsonb_agg(private.visit_result(v.id) order by v.start_date,v.start_time nulls first,v.id)
 from public.visits v join public.work_items w on w.id=v.work_item_id where w.job_id=p_job_id and private.can_read_visit(v.id)),'[]'::jsonb);
end; $$;
create function public.get_visit(p_visit_id uuid) returns jsonb language sql stable security definer set search_path='' as $$ select private.visit_result(p_visit_id); $$;
create function public.list_schedule(p_start date,p_end date,p_all boolean default false) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not (private.has_role('pm') or private.has_role('lead') or private.has_role('helper')) then raise exception using errcode='42501',message='Schedule access required'; end if;
 if p_start is null or p_end is null or p_end<p_start or p_end-p_start>30 then raise exception using errcode='22023',message='Invalid schedule range'; end if;
 if p_all and not private.has_role('pm') then raise exception using errcode='42501',message='PM required'; end if;
 if (select count(*) from public.visits v join public.work_items w on w.id=v.work_item_id join public.jobs j on j.id=w.job_id
 where v.start_date<=p_end and v.end_date>=p_start and v.state<>'cancelled' and
 ((private.has_role('pm') and (p_all or j.responsible_pm=auth.uid())) or exists(select 1 from public.visit_participants p where p.visit_id=v.id and p.user_id=auth.uid())))>500
 then raise exception using errcode='22023',message='Schedule limit exceeded'; end if;
 return coalesce((select jsonb_agg(private.visit_result(v.id) order by v.start_date,v.start_time nulls first,v.id)
 from public.visits v join public.work_items w on w.id=v.work_item_id join public.jobs j on j.id=w.job_id
 where v.start_date<=p_end and v.end_date>=p_start and v.state<>'cancelled' and
 ((private.has_role('pm') and (p_all or j.responsible_pm=auth.uid())) or exists(select 1 from public.visit_participants p where p.visit_id=v.id and p.user_id=auth.uid()))),'[]'::jsonb);
end; $$;
create function public.visit_staff_options(p_visit_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v public.visits%rowtype;
begin
 select * into v from public.visits where id=p_visit_id;
 if not (private.has_role('pm') or (private.has_role('lead') and v.coordinator_id=auth.uid())) then raise exception using errcode='42501',message='Visit coordinator required'; end if;
 if v.id is null then raise exception using errcode='P0002',message='Visit unavailable'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.display_name,'busy',exists(
 select 1 from private.visit_bookings a join private.visit_bookings b on b.user_id=u.id and b.visit_id<>v.id and a.starts_at<b.ends_at and b.starts_at<a.ends_at
 where a.visit_id=v.id)) order by u.display_name,u.id) from public.app_users u where u.active and u.roles && array['lead','helper']::text[] and u.id<>v.coordinator_id),'[]'::jsonb);
end; $$;

revoke all on function private.can_read_visit(uuid),private.visit_result(uuid),private.rebuild_visit(uuid) from public,anon,authenticated;
revoke all on function public.save_visit(uuid,uuid,uuid,jsonb),public.staff_visit(uuid,uuid,uuid[]),public.list_job_visits(uuid),public.get_visit(uuid),public.list_schedule(date,date,boolean),public.visit_staff_options(uuid) from public,anon,authenticated;
grant execute on function public.save_visit(uuid,uuid,uuid,jsonb),public.staff_visit(uuid,uuid,uuid[]),public.list_job_visits(uuid),public.get_visit(uuid),public.list_schedule(date,date,boolean),public.visit_staff_options(uuid) to authenticated;
commit;
