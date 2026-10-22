-- One completion/return-work batch after applied 0001-0009. No fixtures.
begin;
create table public.work_follow_ups (
 id uuid primary key default gen_random_uuid(), job_id uuid not null references public.jobs(id),
 work_item_id uuid not null references public.work_items(id), source_visit_id uuid references public.visits(id),
 owner_id uuid not null references public.app_users(id), note text not null check(length(btrim(note)) between 1 and 2000),
 due_date date, state text not null default 'open' check(state in ('open','done')),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 created_by uuid not null references public.app_users(id),updated_by uuid not null references public.app_users(id)
);
alter table public.visits add column follow_up_id uuid references public.work_follow_ups(id);
create index return_work_state on public.work_follow_ups(work_item_id,state,created_at,id);
create index return_job_state on public.work_follow_ups(job_id,state);
create index visits_return on public.visits(follow_up_id) where follow_up_id is not null;
alter table public.work_follow_ups enable row level security;
revoke all on public.work_follow_ups from public,anon,authenticated;
create table private.work_progress_events (
 id uuid primary key default gen_random_uuid(),work_item_id uuid not null references public.work_items(id),
 actor_id uuid not null references public.app_users(id),request_id uuid not null,operation text not null,
 before_state jsonb not null,after_state jsonb not null,created_at timestamptz not null default now()
);
alter table private.work_progress_events enable row level security;
revoke all on private.work_progress_events from public,anon,authenticated;

create function private.work_progress_snapshot(p_work_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('work',to_jsonb(w),'returns',coalesce((select jsonb_agg(to_jsonb(f) order by f.created_at,f.id) from public.work_follow_ups f where f.work_item_id=w.id),'[]'::jsonb)) from public.work_items w where w.id=p_work_id;
$$;
create function public.list_job_progress(p_job_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not private.can_read_job(p_job_id) then raise exception using errcode='42501',message='Job access required'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',w.id,'job_id',w.job_id,'description',w.description,'completion',w.completion,
 'responsible_lead',w.responsible_lead,'lead_name',u.display_name,'remaining_note',w.remaining_note,
 'planned_count',(select count(*) from public.visits v where v.work_item_id=w.id and v.state='planned'),
 'returns',coalesce((select jsonb_agg(to_jsonb(f)||jsonb_build_object('owner_name',owner.display_name,
 'planned_count',(select count(*) from public.visits rv where rv.follow_up_id=f.id and rv.state='planned')) order by f.created_at,f.id)
 from public.work_follow_ups f join public.app_users owner on owner.id=f.owner_id where f.work_item_id=w.id),'[]'::jsonb)) order by w.created_at,w.id)
 from public.work_items w left join public.app_users u on u.id=w.responsible_lead where w.job_id=p_job_id),'[]'::jsonb);
end; $$;

create function public.work_progress_command(p_work_id uuid,p_visit_id uuid,p_follow_up_id uuid,p_request_id uuid,p_command text,p_values jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items%rowtype; j public.jobs%rowtype; v public.visits%rowtype; f public.work_follow_ups%rowtype;
 v_prior private.command_requests%rowtype; payload jsonb; before_data jsonb; result_id uuid; new_visit jsonb;
 note_value text:=''; due_value date; needs_return boolean:=false; reopen_value boolean:=false; k text; owner_value uuid;
begin
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Progress planning required'; end if;
 if p_work_id is null or p_request_id is null or p_command is null or p_command not in ('finish_visit','complete_work','record_return','resolve_return','reopen_work','plan_return')
 or p_values is null or jsonb_typeof(p_values)<>'object' then raise exception using errcode='22023',message='Invalid progress command'; end if;
 if (p_command='finish_visit' and (p_visit_id is null or p_follow_up_id is not null))
 or (p_command in ('resolve_return','plan_return') and (p_follow_up_id is null or p_visit_id is not null))
 or (p_command in ('complete_work','reopen_work') and (p_visit_id is not null or p_follow_up_id is not null))
 or (p_command='record_return' and p_follow_up_id is not null) then raise exception using errcode='22023',message='Invalid progress relationship'; end if;
 for k in select jsonb_object_keys(p_values) loop
  if (p_command='finish_visit' and k not in ('note','needs_return','due_date'))
  or (p_command='record_return' and k not in ('note','due_date','reopen'))
  or (p_command in ('complete_work','reopen_work','resolve_return'))
  or (p_command='plan_return' and k not in ('start_date','end_date','slot','start_time','end_time','coordinator_id','required_helpers','certainty'))
  then raise exception using errcode='22023',message='Invalid progress field'; end if;
 end loop;
 if p_values ? 'note' then
  if jsonb_typeof(p_values->'note')<>'string' then raise exception using errcode='22023',message='Invalid remaining note'; end if;
  note_value:=btrim(p_values->>'note');
  if length(note_value)>2000 or translate(note_value,chr(10)||chr(13)||chr(9),'') ~ '[[:cntrl:]]' then raise exception using errcode='22023',message='Invalid remaining note'; end if;
 end if;
 if p_values ? 'needs_return' then
  if jsonb_typeof(p_values->'needs_return')<>'boolean' then raise exception using errcode='22023',message='Invalid return flag'; end if;
  needs_return:=(p_values->>'needs_return')::boolean;
 end if;
 if p_values ? 'reopen' then
  if jsonb_typeof(p_values->'reopen')<>'boolean' then raise exception using errcode='22023',message='Invalid return flag'; end if;
  reopen_value:=(p_values->>'reopen')::boolean;
 end if;
 if p_values ? 'due_date' and p_values->'due_date'<>'null'::jsonb then
  if jsonb_typeof(p_values->'due_date')<>'string' or (p_values->>'due_date')!~'^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' then raise exception using errcode='22023',message='Invalid return date'; end if;
  due_value:=(p_values->>'due_date')::date;
 end if;
 if (p_command='record_return' or needs_return) and note_value='' then raise exception using errcode='22023',message='Describe return work'; end if;
 if p_command='finish_visit' then p_values:=jsonb_build_object('note',note_value,'due_date',due_value,'needs_return',needs_return); end if;
 if p_command='record_return' then p_values:=jsonb_build_object('note',note_value,'due_date',due_value,'reopen',reopen_value); end if;
 payload:=jsonb_build_object('work',p_work_id,'visit',p_visit_id,'follow_up',p_follow_up_id,'values',p_values);
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Progress planning required'; end if;
 select x.* into j from public.jobs x join public.work_items y on y.job_id=x.id where y.id=p_work_id for update of x;
 select * into w from public.work_items where id=p_work_id for update;
 if w.id is null then raise exception using errcode='P0002',message='Work unavailable'; end if;
 if p_visit_id is not null then
  select * into v from public.visits where id=p_visit_id and work_item_id=w.id for update;
  if v.id is null then raise exception using errcode='P0002',message='Visit unavailable'; end if;
 end if;
 if p_follow_up_id is not null then
  select * into f from public.work_follow_ups where id=p_follow_up_id and work_item_id=w.id and job_id=j.id for update;
  if f.id is null then raise exception using errcode='P0002',message='Return unavailable'; end if;
 end if;
 if not private.has_role('pm') then
  if p_command='finish_visit' or (p_command='record_return' and p_visit_id is not null) then
   if v.coordinator_id<>auth.uid() then raise exception using errcode='42501',message='Visit coordinator required'; end if;
  elsif w.responsible_lead is distinct from auth.uid() then raise exception using errcode='42501',message='Responsible lead required'; end if;
 end if;
 select * into v_prior from private.command_requests where actor_id=auth.uid() and operation='progress:'||p_command and request_id=p_request_id;
 if found then
  if v_prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('job_id',j.id,'work_id',w.id,'result_id',v_prior.result_id,
    'visit',case when p_command in ('finish_visit','plan_return') then private.visit_result(v_prior.result_id) else null end);
 end if;
 if j.lifecycle<>'open' then raise exception using errcode='22023',message='Open job required'; end if;
 before_data:=private.work_progress_snapshot(w.id); result_id:=w.id;
 if p_command='finish_visit' then
  if v.state<>'planned' then raise exception using errcode='22023',message='Planned visit required'; end if;
  if w.completion<>'open' then raise exception using errcode='22023',message='Open work required'; end if;
  update public.visits set state='completed',updated_at=clock_timestamp(),updated_by=auth.uid() where id=v.id;
  perform private.rebuild_visit(v.id);
  if note_value<>'' then update public.work_items set remaining_note=note_value,updated_at=clock_timestamp(),updated_by=auth.uid() where id=w.id; end if;
  if needs_return then
   if (select count(*) from public.work_follow_ups where job_id=j.id and state='open')>=100 then raise exception using errcode='22023',message='Return limit reached'; end if;
   select id into owner_value from public.app_users where id=w.responsible_lead and active;
   insert into public.work_follow_ups(job_id,work_item_id,source_visit_id,owner_id,note,due_date,created_by,updated_by)
   values(j.id,w.id,v.id,coalesce(owner_value,auth.uid()),note_value,due_value,auth.uid(),auth.uid());
  end if;
  insert into private.visit_events(visit_id,actor_id,request_id,operation,snapshot) values(v.id,auth.uid(),p_request_id,'finish_visit',private.visit_result(v.id));
  result_id:=v.id;
 elsif p_command='complete_work' then
  if w.completion<>'open' then raise exception using errcode='22023',message='Open work required'; end if;
  if exists(select 1 from public.visits where work_item_id=w.id and state='planned') then raise exception using errcode='22023',message='Planned visits remain'; end if;
  if exists(select 1 from public.work_follow_ups where work_item_id=w.id and state='open') then raise exception using errcode='22023',message='Open returns remain'; end if;
  update public.work_items set completion='completed',remaining_note='',updated_at=clock_timestamp(),updated_by=auth.uid() where id=w.id;
 elsif p_command='reopen_work' then
  if w.completion<>'completed' then raise exception using errcode='22023',message='Completed work required'; end if;
  update public.work_items set completion='open',updated_at=clock_timestamp(),updated_by=auth.uid() where id=w.id;
 elsif p_command='record_return' then
  if w.completion='completed' and not reopen_value then raise exception using errcode='22023',message='Reopen portion explicitly'; end if;
  if (select count(*) from public.work_follow_ups where job_id=j.id and state='open')>=100 then raise exception using errcode='22023',message='Return limit reached'; end if;
  update public.work_items set completion='open',remaining_note=note_value,updated_at=clock_timestamp(),updated_by=auth.uid() where id=w.id;
  select id into owner_value from public.app_users where id=w.responsible_lead and active;
  insert into public.work_follow_ups(job_id,work_item_id,source_visit_id,owner_id,note,due_date,created_by,updated_by)
  values(j.id,w.id,p_visit_id,coalesce(owner_value,auth.uid()),note_value,due_value,auth.uid(),auth.uid()) returning id into result_id;
 elsif p_command='resolve_return' then
  if f.state<>'open' then raise exception using errcode='22023',message='Open return required'; end if;
  if exists(select 1 from public.visits where follow_up_id=f.id and state='planned') then raise exception using errcode='22023',message='Return visit still planned'; end if;
  update public.work_follow_ups set state='done',updated_at=clock_timestamp(),updated_by=auth.uid() where id=f.id;
  result_id:=f.id;
 elsif p_command='plan_return' then
  if f.state<>'open' or w.completion<>'open' then raise exception using errcode='22023',message='Open return required'; end if;
  if exists(select 1 from public.visits where follow_up_id=f.id and state='planned') then raise exception using errcode='22023',message='Return already scheduled'; end if;
  new_visit:=public.save_visit(w.id,null,gen_random_uuid(),p_values);
  result_id:=(new_visit->>'id')::uuid;
  update public.visits set follow_up_id=f.id where id=result_id;
  insert into private.visit_events(visit_id,actor_id,request_id,operation,snapshot) values(result_id,auth.uid(),p_request_id,'plan_return',private.visit_result(result_id));
 end if;
 insert into private.work_progress_events(work_item_id,actor_id,request_id,operation,before_state,after_state)
 values(w.id,auth.uid(),p_request_id,p_command,before_data,private.work_progress_snapshot(w.id));
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
 values(j.id,auth.uid(),p_command,array['work_progress'],p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id)
 values(auth.uid(),'progress:'||p_command,p_request_id,payload,result_id);
 return jsonb_build_object('job_id',j.id,'work_id',w.id,'result_id',result_id,
  'visit',case when p_command in ('finish_visit','plan_return') then private.visit_result(result_id) else null end);
end; $$;
revoke all on function private.work_progress_snapshot(uuid) from public,anon,authenticated;
revoke all on function public.list_job_progress(uuid),public.work_progress_command(uuid,uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.list_job_progress(uuid),public.work_progress_command(uuid,uuid,uuid,uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
