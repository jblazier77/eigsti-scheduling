-- COMBINED TEST-PROJECT UPDATE. Requires applied 0001-0009 and UNAPPLIED 0010/0011.
-- Run ONCE. All DDL and 111 checks commit together; synthetic fixtures are removed.
begin;
do $preflight$
begin
 if to_regclass('public.work_follow_ups') is not null or to_regclass('public.subcontractors') is not null then
  raise exception 'Combined update stopped: 0010 or 0011 may already be applied. Do not rerun; verify project state.';
 end if;
 if to_regprocedure('public.save_visit_card(uuid,uuid,uuid,jsonb,uuid[])') is null then
  raise exception 'Combined update requires the applied 0009 visit-card checkpoint.';
 end if;
end; $preflight$;

-- Migration 0010_completion_and_returns
-- One completion/return-work batch after applied 0001-0009. No fixtures.
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

-- Migration 0011_job_tags_and_trades
-- After 0010. Additive metadata only; no staffing or readiness changes.
create function private.valid_trade_ids(p_ids text[]) returns boolean language sql immutable set search_path='' as $$
 select p_ids is not null and cardinality(p_ids)<=15 and array_position(p_ids,null) is null
 and p_ids <@ array['roofing','siding','windows_doors','framing','electrical','plumbing','hvac','drywall','painting','flooring','cabinetry','tile','concrete','landscaping','general']::text[]
 and cardinality(p_ids)=(select count(distinct x) from unnest(p_ids) x);
$$;
alter table public.jobs add column rain_day boolean not null default false,
 add column filler boolean not null default false, add column whole_house boolean not null default false,
 add column trades text[] not null default '{}' check(private.valid_trade_ids(trades));
create index jobs_rain_day on public.jobs(responsible_pm,created_at desc,id desc) where rain_day and lifecycle='open';
create index jobs_filler on public.jobs(responsible_pm,created_at desc,id desc) where filler and lifecycle='open';

create function private.classification_patch(p_values jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare k text; ids text[]; result jsonb:='{}';
begin
 if p_values is null or jsonb_typeof(p_values)<>'object' then raise exception using errcode='22023',message='Invalid job tags'; end if;
 for k in select jsonb_object_keys(p_values) loop
  if k='trades' then
   if jsonb_typeof(p_values->k)<>'array' or exists(select 1 from jsonb_array_elements(p_values->k) v where jsonb_typeof(v)<>'string') then raise exception using errcode='22023',message='Invalid trades'; end if;
   select coalesce(array_agg(v order by v),'{}'::text[]) into ids from jsonb_array_elements_text(p_values->k) v;
   if not private.valid_trade_ids(ids) then raise exception using errcode='22023',message='Invalid trades'; end if;
   result:=result||jsonb_build_object(k,ids);
  elsif k in ('rain_day','filler','whole_house') and jsonb_typeof(p_values->k)='boolean' then result:=result||jsonb_build_object(k,p_values->k);
  else raise exception using errcode='22023',message='Invalid job tags'; end if;
 end loop;
 return result;
end; $$;
create table private.classification_events(
 id uuid primary key default gen_random_uuid(),job_id uuid not null references public.jobs(id),
 actor_id uuid not null references public.app_users(id),request_id uuid not null,
 before_state jsonb not null,after_state jsonb not null,created_at timestamptz not null default now()
);
alter table private.classification_events enable row level security;
revoke all on private.classification_events from public,anon,authenticated;

create function public.save_job_classification(p_job_id uuid,p_request_id uuid,p_patch jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); patch jsonb; payload jsonb; previous private.command_requests%rowtype; j public.jobs%rowtype; before_data jsonb;
begin
 perform 1 from public.app_users where id=actor and active and 'pm'=any(roles) for share;
 if not found then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 patch:=private.classification_patch(p_patch);
 if patch='{}' then raise exception using errcode='22023',message='Invalid job tags'; end if;
 payload:=jsonb_build_object('job_id',p_job_id,'patch',patch);
 perform pg_advisory_xact_lock(hashtextextended(actor::text||':save_job_classification:'||p_request_id::text,0));
 select * into previous from private.command_requests where actor_id=actor and operation='save_job_classification' and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',previous.result_id);
 end if;
 select * into j from public.jobs where id=p_job_id and lifecycle<>'archived' for update;
 if not found then raise exception using errcode='P0002',message='Job unavailable'; end if;
 before_data:=jsonb_build_object('rain_day',j.rain_day,'filler',j.filler,'whole_house',j.whole_house,'trades',j.trades);
 update public.jobs set rain_day=case when patch?'rain_day' then (patch->>'rain_day')::boolean else rain_day end,
 filler=case when patch?'filler' then (patch->>'filler')::boolean else filler end,
 whole_house=case when patch?'whole_house' then (patch->>'whole_house')::boolean else whole_house end,
 trades=case when patch?'trades' then array(select jsonb_array_elements_text(patch->'trades')) else trades end,
 updated_by=actor,updated_at=clock_timestamp() where id=p_job_id returning * into j;
 insert into private.classification_events(job_id,actor_id,request_id,before_state,after_state) values(j.id,actor,p_request_id,before_data,jsonb_build_object('rain_day',j.rain_day,'filler',j.filler,'whole_house',j.whole_house,'trades',j.trades));
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id) values(j.id,actor,'save_job_classification',array(select jsonb_object_keys(patch)),p_request_id);
 insert into private.command_requests(actor_id,request_id,operation,payload,result_id) values(actor,p_request_id,'save_job_classification',payload,j.id);
 return jsonb_build_object('id',j.id);
end; $$;

-- Wrapper creates the normal job/default work and its optional tags in ONE transaction.
create function public.create_classified_job(p_request_id uuid,p_customer text,p_phone text,p_address text,p_classification jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); patch jsonb; payload jsonb; previous private.command_requests%rowtype; result jsonb;
begin
 perform 1 from public.app_users where id=actor and active and 'pm'=any(roles) for share;
 if not found then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 patch:=private.classification_patch(p_classification);
 payload:=jsonb_build_object('customer',p_customer,'phone',p_phone,'address',p_address,'classification',patch);
 perform pg_advisory_xact_lock(hashtextextended(actor::text||':create_classified_job:'||p_request_id::text,0));
 select * into previous from private.command_requests where actor_id=actor and operation='create_classified_job' and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',previous.result_id);
 end if;
 -- Do not upgrade a UUID previously used through the legacy create endpoint.
 if exists(select 1 from private.command_requests where actor_id=actor and operation='create_job' and request_id=p_request_id) then raise exception using errcode='23505',message='Request payload changed'; end if;
 result:=public.create_job(p_request_id,p_customer,p_phone,p_address);
 if patch<>'{}' then perform public.save_job_classification((result->>'id')::uuid,p_request_id,patch); end if;
 insert into private.command_requests(actor_id,request_id,operation,payload,result_id) values(actor,p_request_id,'create_classified_job',payload,(result->>'id')::uuid);
 return jsonb_build_object('id',result->>'id');
end; $$;

create table public.subcontractors(
 id uuid primary key default gen_random_uuid(),name text not null check(length(btrim(name)) between 1 and 100),
 phone text not null default '' check(length(phone)<=40),phone_action text check(phone_action ~ '^\+1[0-9]{10}$'),
 email text not null default '' check(length(email)<=254),trades text[] not null default '{}' check(private.valid_trade_ids(trades)),
 archived_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 created_by uuid not null references public.app_users(id),updated_by uuid not null references public.app_users(id),
 check((phone='')=(phone_action is null))
);
create index subcontractor_active_name on public.subcontractors(name,id) where archived_at is null;
alter table public.subcontractors enable row level security;
revoke all on public.subcontractors from public,anon,authenticated;
grant select on public.subcontractors to authenticated;
create policy subcontractor_directory_read on public.subcontractors for select to authenticated using(archived_at is null and (private.has_role('pm') or private.has_role('admin') or private.has_role('lead')));
create table private.subcontractor_events(
 id uuid primary key default gen_random_uuid(),subcontractor_id uuid not null references public.subcontractors(id),actor_id uuid not null references public.app_users(id),
 request_id uuid not null,before_state jsonb not null,after_state jsonb not null,created_at timestamptz not null default now()
);
alter table private.subcontractor_events enable row level security;
revoke all on private.subcontractor_events from public,anon,authenticated;

create function public.save_subcontractor(p_id uuid,p_request_id uuid,p_patch jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); patch jsonb:='{}'; k text; v text; ids jsonb; payload jsonb; previous private.command_requests%rowtype; s public.subcontractors%rowtype; before_data jsonb:='{}';
begin
 perform 1 from public.app_users where id=actor and active and roles&&array['pm','admin']::text[] for share;
 if not found then raise exception using errcode='42501',message='Directory manager required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 if p_patch is null or jsonb_typeof(p_patch)<>'object' or p_patch='{}' then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
 for k in select jsonb_object_keys(p_patch) loop
  if k='trades' then patch:=patch||private.classification_patch(jsonb_build_object(k,p_patch->k));
  elsif k='archive' and p_patch->k='true'::jsonb then patch:=patch||jsonb_build_object(k,true);
  elsif k in ('name','phone','email') and jsonb_typeof(p_patch->k)='string' then
   v:=btrim(p_patch->>k);
   if length(p_patch->>k)>(case k when 'name' then 100 when 'phone' then 40 else 254 end) or (p_patch->>k) ~ '[[:cntrl:]]' or (k='name' and v='') then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
   if k='phone' and v<>'' then perform private.phone_action(v); end if;
   if k='email' and v<>'' and v !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
   patch:=patch||jsonb_build_object(k,v);
  else raise exception using errcode='22023',message='Invalid subcontractor'; end if;
 end loop;
 if patch?'archive' and patch<>'{"archive":true}'::jsonb then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
 payload:=jsonb_build_object('id',p_id,'patch',patch);
 perform pg_advisory_xact_lock(hashtextextended(actor::text||':save_subcontractor:'||p_request_id::text,0));
 select * into previous from private.command_requests where actor_id=actor and operation='save_subcontractor' and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',previous.result_id);
 end if;
 -- Serialize directory capacity and row edits; no scheduling/queue locks needed.
 perform pg_advisory_xact_lock(hashtextextended('eigsti:subcontractors',0));
 if p_id is null then
  if not(patch?&array['name','phone','email','trades']) or patch?'archive' then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
  if (select count(*) from public.subcontractors where archived_at is null)>=500 then raise exception using errcode='22023',message='Directory limit reached'; end if;
  insert into public.subcontractors(name,phone,phone_action,email,trades,created_by,updated_by) values(patch->>'name',patch->>'phone',case when patch->>'phone'='' then null else private.phone_action(patch->>'phone') end,patch->>'email',array(select jsonb_array_elements_text(patch->'trades')),actor,actor) returning * into s;
 else
  select * into s from public.subcontractors where id=p_id and archived_at is null for update;
  if not found then raise exception using errcode='P0002',message='Subcontractor unavailable'; end if;
  before_data:=to_jsonb(s);
  update public.subcontractors set name=coalesce(patch->>'name',name),phone=coalesce(patch->>'phone',phone),
   phone_action=case when patch?'phone' then case when patch->>'phone'='' then null else private.phone_action(patch->>'phone') end else phone_action end,
   email=coalesce(patch->>'email',email),trades=case when patch?'trades' then array(select jsonb_array_elements_text(patch->'trades')) else trades end,
   archived_at=case when patch?'archive' then clock_timestamp() else archived_at end,updated_at=clock_timestamp(),updated_by=actor where id=p_id returning * into s;
 end if;
 insert into private.subcontractor_events(subcontractor_id,actor_id,request_id,before_state,after_state) values(s.id,actor,p_request_id,before_data,to_jsonb(s));
 insert into private.command_requests(actor_id,request_id,operation,payload,result_id) values(actor,p_request_id,'save_subcontractor',payload,s.id);
 return jsonb_build_object('id',s.id);
end; $$;

revoke all on function private.valid_trade_ids(text[]),private.classification_patch(jsonb) from public,anon,authenticated;
revoke all on function public.save_job_classification(uuid,uuid,jsonb),public.create_classified_job(uuid,text,text,text,jsonb),public.save_subcontractor(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.save_job_classification(uuid,uuid,jsonb),public.create_classified_job(uuid,text,text,text,jsonb),public.save_subcontractor(uuid,uuid,jsonb) to authenticated;
notify pgrst,'reload schema';

savepoint eigsti_combined_checks_0;
-- Isolated test project only, after 0001-0010. All fictional fixtures roll back.
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_visit_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_test_visits(label text primary key,value jsonb) on commit drop;
grant insert,select on pg_temp.eigsti_visit_results,pg_temp.eigsti_test_visits to authenticated,anon;
grant usage on sequence pg_temp.eigsti_visit_results_ordinal_seq to authenticated,anon;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','visits-pm1@example.invalid'),
('22222222-2222-4222-8222-222222222222','visits-pm2@example.invalid'),
('33333333-3333-4333-8333-333333333333','visits-lead1@example.invalid'),
('44444444-4444-4444-8444-444444444444','visits-lead2@example.invalid'),
('55555555-5555-4555-8555-555555555555','visits-help1@example.invalid'),
('66666666-6666-4666-8666-666666666666','visits-help2@example.invalid'),
('77777777-7777-4777-8777-777777777777','visits-admin@example.invalid'),
('88888888-8888-4888-8888-888888888888','visits-inactive@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC PM1',array['pm'],true),
('22222222-2222-4222-8222-222222222222','SYNTHETIC PM2',array['pm'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Lead1',array['lead'],true),
('44444444-4444-4444-8444-444444444444','SYNTHETIC Lead2',array['lead'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Helper1',array['helper'],true),
('66666666-6666-4666-8666-666666666666','SYNTHETIC Helper2',array['helper'],true),
('77777777-7777-4777-8777-777777777777','SYNTHETIC Admin',array['admin'],true),
('88888888-8888-4888-8888-888888888888','SYNTHETIC Inactive',array['lead'],false);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,responsible_pm,created_by,updated_by) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Customer1','3095550101','+13095550101','Fictional Lane','SYNTHETIC Visit Job1','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC Customer2','3095550102','+13095550102','Fictional Lane','SYNTHETIC Visit Job2','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222');
insert into public.work_items(id,job_id,description,responsible_lead,created_by,updated_by) values
('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Cabinets','33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC Windows','44444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222');
insert into public.work_items(id,job_id,description,responsible_lead,created_by,updated_by) values('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Other portion','44444444-4444-4444-8444-444444444444','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_test_visits values('first',public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,gen_random_uuid(),'{"start_date":"2026-11-02","end_date":"2026-11-02","slot":"morning","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":1}'));
insert into pg_temp.eigsti_test_visits values('future',public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,gen_random_uuid(),'{"start_date":"2026-11-03","end_date":"2026-11-03","slot":"morning","coordinator_id":"33333333-3333-4333-8333-333333333333"}'));
insert into pg_temp.eigsti_test_visits values('other',public.save_visit('ffffffff-ffff-4fff-8fff-ffffffffffff',null,gen_random_uuid(),'{"start_date":"2026-11-05","end_date":"2026-11-05","slot":"morning","coordinator_id":"44444444-4444-4444-8444-444444444444"}'));
select public.staff_visit((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='first'),gen_random_uuid(),array['55555555-5555-4555-8555-555555555555']::uuid[]);
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='first'),null,gen_random_uuid(),'finish_visit','{"needs_return":true}')$t$,'22023','Describe return work','Return flag requires a short note'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='first'),null,'abcdefab-cdef-4abc-8abc-000000000001','finish_visit','{"needs_return":true,"note":"Missing trim; return when delivered","due_date":null}')$t$,'Coordinator finishes crew entry and records undated return atomically'));
insert into pg_temp.eigsti_visit_results(result) values(is((select public.get_visit((value->>'id')::uuid)->>'state' from pg_temp.eigsti_test_visits where label='first'),'completed','Scheduled entry finished'));
insert into pg_temp.eigsti_visit_results(result) values(is((select completion from public.work_items where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'),'open','Finishing visit leaves portion open'));
insert into pg_temp.eigsti_visit_results(result) values(is((select lifecycle from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'open','Finishing visit leaves whole job open'));
insert into pg_temp.eigsti_visit_results(result) values(is((select completion from public.work_items where id='ffffffff-ffff-4fff-8fff-ffffffffffff'),'open','Other lead portion stays open'));
insert into pg_temp.eigsti_visit_results(result) values(is((select public.get_visit((value->>'id')::uuid)->>'state' from pg_temp.eigsti_test_visits where label='future'),'planned','Future entry is not silently finished'));
insert into pg_temp.eigsti_visit_results(result) values(ok((public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') @> '[{"id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd"}]'::jsonb,'Remaining work stays queued'));
insert into pg_temp.eigsti_visit_results(result) values(ok((public.list_job_progress('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')->0->'returns'->0->>'due_date') is null,'Return does not require fake due date'));
insert into pg_temp.eigsti_visit_results(result) values(is((public.list_job_progress('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')->0->'returns'->0->>'note'),'Missing trim; return when delivered','Return note retained'));
reset role;
insert into pg_temp.eigsti_test_visits select 'followup',jsonb_build_object('id',id) from public.work_follow_ups where work_item_id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
insert into pg_temp.eigsti_visit_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='first')),0::bigint,'Finished entry releases whole crew reservations'));
insert into pg_temp.eigsti_visit_results(result) values(ok((select source_visit_id=(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='first') and owner_id='33333333-3333-4333-8333-333333333333' from public.work_follow_ups where id=(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='followup')),'Return linked to source and responsible owner'));
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='first'),null,'abcdefab-cdef-4abc-8abc-000000000001','finish_visit','{"needs_return":true,"note":"Missing trim; return when delivered","due_date":null}')$t$,'Identical finish retry acknowledged'));
insert into pg_temp.eigsti_visit_results(result) values(is(jsonb_array_length(public.list_job_progress('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')->0->'returns'),1::integer,'Retry never duplicates return work'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='first'),null,'abcdefab-cdef-4abc-8abc-000000000001','finish_visit','{"needs_return":false}')$t$,'23505','Request payload changed','Changed finish retry rejected'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='first'),null,gen_random_uuid(),'finish_visit','{}')$t$,'22023','Planned visit required','New command cannot finish a finished entry twice'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,gen_random_uuid(),'complete_work','{}')$t$,'22023','Planned visits remain','Portion completion cannot silently finish future visits'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='followup'),gen_random_uuid(),'plan_return','{"start_date":"2026-11-03","end_date":"2026-11-03","slot":"morning","coordinator_id":"33333333-3333-4333-8333-333333333333"}')$t$,'23P01','Staff scheduling conflict','Return planning enforces existing coordinator reservations'));
reset role;
insert into pg_temp.eigsti_visit_results(result) values(is((select count(*) from public.visits where follow_up_id=(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='followup')),0::bigint,'Failed return plan leaves no linked visit'));
set local role authenticated;
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_visit_results(result) values(ok(private.can_read_job('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Completed helper entry retains shared active-job access'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,gen_random_uuid(),'complete_work','{}')$t$,'42501','Progress planning required','Helper cannot complete work'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select * from public.work_follow_ups$t$,'42501',null,'Raw return table denied'));
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,gen_random_uuid(),'complete_work','{}')$t$,'42501','Responsible lead required','Lead cannot complete another portion on shared job'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='future'),null,gen_random_uuid(),'finish_visit','{}')$t$,'42501','Visit coordinator required','Other lead cannot finish coordinated entry'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='future'),gen_random_uuid(),'{"state":"cancelled"}');
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,gen_random_uuid(),'complete_work','{}')$t$,'22023','Open returns remain','Return must be handled before completing portion'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$insert into pg_temp.eigsti_test_visits select 'return-plan',public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='followup'),'abcdefab-cdef-4abc-8abc-000000000002','plan_return','{"start_date":"2026-11-03","end_date":"2026-11-03","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333"}')$t$,'PM plans linked date-only return'));
insert into pg_temp.eigsti_visit_results(result) values(is((select jsonb_array_length(value->'visit'->'participants') from pg_temp.eigsti_test_visits where label='return-plan'),1::integer,'Return does not silently clone old helpers'));
insert into pg_temp.eigsti_visit_results(result) values(is((select value->'visit'->>'follow_up_id' from pg_temp.eigsti_test_visits where label='return-plan'),(select value->>'id' from pg_temp.eigsti_test_visits where label='followup'),'Calendar entry linked to follow-up'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='followup'),'abcdefab-cdef-4abc-8abc-000000000002','plan_return','{"start_date":"2026-11-03","end_date":"2026-11-03","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333"}')$t$,'Return planning retries preserve identity'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='followup'),gen_random_uuid(),'plan_return','{"start_date":"2026-11-04","end_date":"2026-11-04","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333"}')$t$,'22023','Return already scheduled','Cannot accidentally schedule return twice'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='followup'),gen_random_uuid(),'resolve_return','{}')$t$,'22023','Return visit still planned','Resolving does not leave live return appointments'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'result_id')::uuid from pg_temp.eigsti_test_visits where label='return-plan'),null,'abcdefab-cdef-4abc-8abc-000000000003','finish_visit','{}')$t$,'Finish return appointment separately'));
insert into pg_temp.eigsti_visit_results(result) values(is((public.list_job_progress('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')->0->'returns'->0->>'state'),'open','Finished return appointment does not implicitly resolve note'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='followup'),'abcdefab-cdef-4abc-8abc-000000000004','resolve_return','{}')$t$,'Explicitly mark return handled'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,'abcdefab-cdef-4abc-8abc-000000000005','complete_work','{}')$t$,'Complete portion after planned work and returns handled'));
insert into pg_temp.eigsti_visit_results(result) values(is((select completion from public.work_items where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'),'completed','Portion completed'));
insert into pg_temp.eigsti_visit_results(result) values(is((select lifecycle from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'open','Portion completion never closes whole job'));
insert into pg_temp.eigsti_visit_results(result) values(is((select public.get_visit((value->>'id')::uuid)->>'state' from pg_temp.eigsti_test_visits where label='other'),'planned','Other portion calendar unchanged'));
insert into pg_temp.eigsti_visit_results(result) values(ok(not (public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') @> '[{"id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd"}]'::jsonb,'Completed portion leaves its queue'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,'abcdefab-cdef-4abc-8abc-000000000006','reopen_work','{}')$t$,'PM can reopen a completed portion'));
insert into pg_temp.eigsti_visit_results(result) values(ok((public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') @> '[{"id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd"}]'::jsonb,'Reopened portion rejoins queue'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,'abcdefab-cdef-4abc-8abc-000000000005','complete_work','{}')$t$,'Old completion retry acknowledged'));
insert into pg_temp.eigsti_visit_results(result) values(is((select completion from public.work_items where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'),'open','Old completion retry never undoes reopen'));
select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,gen_random_uuid(),'complete_work','{}');
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,gen_random_uuid(),'record_return','{"note":"Replace final trim"}')$t$,'22023','Reopen portion explicitly','Return on completed portion requires explicit reopen'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$insert into pg_temp.eigsti_test_visits select 'later-return',public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,'abcdefab-cdef-4abc-8abc-000000000007','record_return','{"note":"Replace final trim","reopen":true,"due_date":"2026-11-09"}')$t$,'Reopen and record follow-up without inventing appointment'));
insert into pg_temp.eigsti_visit_results(result) values(is((select completion from public.work_items where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'),'open','Return reopens only its portion'));
insert into pg_temp.eigsti_visit_results(result) values(is((select f->>'due_date' from jsonb_array_elements(public.list_job_progress('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')->0->'returns') f where f->>'id'=(select value->>'result_id' from pg_temp.eigsti_test_visits where label='later-return')),'2026-11-09','Optional follow-up date retained'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('ffffffff-ffff-4fff-8fff-ffffffffffff',null,(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='followup'),gen_random_uuid(),'resolve_return','{}')$t$,'P0002','Return unavailable','Forged portion/return relationship rejected'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,gen_random_uuid(),'reopen_work','{"responsible_lead":"44444444-4444-4444-8444-444444444444"}')$t$,'22023','Invalid progress field','Lifecycle command cannot change ownership'));
reset role;
insert into pg_temp.eigsti_visit_results(result) values(ok((select before_state ? 'work' and after_state ? 'returns' from private.work_progress_events where request_id='abcdefab-cdef-4abc-8abc-000000000005'),'Audit retains before/after progress snapshots'));
insert into pg_temp.eigsti_visit_results(result) values(is((select count(*) from private.command_requests where operation='progress:complete_work' and request_id='abcdefab-cdef-4abc-8abc-000000000005'),1::bigint,'Completion retries retain single receipt'));
set local role authenticated;
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,gen_random_uuid(),'complete_work','{}')$t$,'42501','Progress planning required','Admin-only lifecycle mutation denied'));
select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,gen_random_uuid(),'complete_work','{}')$t$,'42501','Progress planning required','Inactive lead mutation denied'));
reset role;
set local role anon;
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,gen_random_uuid(),'complete_work','{}')$t$,'42501',null,'Anonymous completion denied'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='future'),null,gen_random_uuid(),'finish_visit','{}')$t$,'22023','Planned visit required','Cancelled entry cannot be finished'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('ffffffff-ffff-4fff-8fff-ffffffffffff',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='first'),null,gen_random_uuid(),'finish_visit','{}')$t$,'P0002','Visit unavailable','Forged work/visit parent rejected'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select private.work_progress_snapshot('dddddddd-dddd-4ddd-8ddd-dddddddddddd')$t$,'42501',null,'Private progress snapshot cannot be enumerated'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='future'),null,gen_random_uuid(),'finish_visit','{"needs_return":"true"}')$t$,'22023','Invalid return flag','Return boolean cannot be forged as string'));
select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"responsible_lead":"44444444-4444-4444-8444-444444444444"}');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.work_progress_command('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,null,gen_random_uuid(),'complete_work','{}')$t$,'42501','Responsible lead required','Reassignment immediately removes former lead completion permission'));
insert into pg_temp.eigsti_visit_results(result) values(is((select readiness from public.work_items where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'),'ready','Completion and return commands preserve readiness'));
reset role;
do $validation$
declare failures text;
begin
 if (select count(*) from pg_temp.eigsti_visit_results)<>60 then raise exception 'Incomplete completion checks: expected 60'; end if;
 select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_visit_results where result not like 'ok %';
 if failures is not null then raise exception 'Completion/return checks failed: %',failures; end if;
end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_visit_results;

rollback to savepoint eigsti_combined_checks_0;
release savepoint eigsti_combined_checks_0;

savepoint eigsti_combined_checks_1;
-- Test project only. Fictional fixtures; every change rolls back.
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_tag_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_tag_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_tag_results,pg_temp.eigsti_tag_ids to authenticated,anon;
grant usage on sequence pg_temp.eigsti_tag_results_ordinal_seq to authenticated,anon;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','tags-pm@example.invalid'),
('33333333-3333-4333-8333-333333333333','tags-lead@example.invalid'),
('55555555-5555-4555-8555-555555555555','tags-helper@example.invalid'),
('77777777-7777-4777-8777-777777777777','tags-admin@example.invalid'),
('88888888-8888-4888-8888-888888888888','tags-inactive@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC PM',array['pm'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Lead',array['lead'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Helper',array['helper'],true),
('77777777-7777-4777-8777-777777777777','SYNTHETIC Admin',array['admin'],true),
('88888888-8888-4888-8888-888888888888','SYNTHETIC Disabled',array['pm','admin'],false);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,scope,access_notes,responsible_pm,created_by,updated_by) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Customer','3095550101','+13095550101','Fictional Lane','SYNTHETIC Tags','Keep scope','Keep access','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC Other','3095550102','+13095550102','Other Fictional Lane','SYNTHETIC Hidden','','','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into public.work_items(id,job_id,description,responsible_lead,created_by,updated_by) values
('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Work','33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
create function pg_temp.tag(p jsonb,r uuid default gen_random_uuid()) returns jsonb language sql as $$select public.save_job_classification('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',r,p);$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_tag_results(result) values(ok((select not rain_day and not filler and not whole_house and cardinality(trades)=0 from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Existing jobs start without invented tags/scopes'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select pg_temp.tag('{"rain_day":true,"filler":true,"trades":["plumbing","electrical"]}','abcdefab-cdef-4abc-8abc-000000000001')$t$,'PM saves independent tags and trades'));
insert into pg_temp.eigsti_tag_results(result) values(ok((select rain_day and filler and not whole_house and trades=array['electrical','plumbing']::text[] from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Trades canonicalized; both tags retained'));
insert into pg_temp.eigsti_tag_results(result) values(is((select scope||'/'||access_notes from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Keep scope/Keep access','Tags preserve unrelated job details'));
insert into pg_temp.eigsti_tag_results(result) values(is((select readiness||'/'||completion from public.work_items where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'),'ready/open','Tags do not confirm or finish work'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select pg_temp.tag('{"rain_day":false}')$t$,'Narrow patch clears only rain tag'));
insert into pg_temp.eigsti_tag_results(result) values(ok((select filler and not rain_day and cardinality(trades)=2 from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Filler/scopes survive independent rain edit'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select pg_temp.tag('{"trades":["electrical","plumbing"],"filler":true,"rain_day":true}','abcdefab-cdef-4abc-8abc-000000000001')$t$,'Canonical retry acknowledged'));
insert into pg_temp.eigsti_tag_results(result) values(ok((select not rain_day from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Old retry does not undo newer tag change'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"rain_day":false}','abcdefab-cdef-4abc-8abc-000000000001')$t$,'23505','Request payload changed','Changed retry rejected'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"trades":["roofing","roofing"]}')$t$,'22023','Invalid trades','Duplicate trade rejected'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"trades":["invented"]}')$t$,'22023','Invalid trades','Unknown trade rejected'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"trades":[null]}')$t$,'22023','Invalid trades','Null trade rejected'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"filler":"true"}')$t$,'22023','Invalid job tags','Boolean strings rejected'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"responsible_pm":null}')$t$,'22023','Invalid job tags','Privilege fields rejected'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select pg_temp.tag('{"whole_house":true}')$t$,'Whole house selected explicitly'));
insert into pg_temp.eigsti_tag_results(result) values(is((select cardinality(trades) from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),2::integer,'Whole house does not invent every trade'));
insert into pg_temp.eigsti_tag_ids values('filler',(public.create_classified_job('abcdefab-cdef-4abc-8abc-000000000002','SYNTHETIC Filler','3095550103','Fictional Filler Lane','{"filler":true,"rain_day":true}') ->>'id')::uuid);
insert into pg_temp.eigsti_tag_results(result) values(ok((select filler and rain_day and lifecycle='open' from public.jobs where id=(select id from pg_temp.eigsti_tag_ids where label='filler')),'Standalone filler is an ordinary open job'));
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.work_items where job_id=(select id from pg_temp.eigsti_tag_ids where label='filler')),1::bigint,'Filler creates one ordinary work portion'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select public.create_classified_job('abcdefab-cdef-4abc-8abc-000000000002','SYNTHETIC Filler','3095550103','Fictional Filler Lane','{"rain_day":true,"filler":true}')$t$,'Create retry uses original identity'));
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.jobs where customer_name='SYNTHETIC Filler'),1::bigint,'Create retry does not duplicate job'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select public.create_classified_job('abcdefab-cdef-4abc-8abc-000000000002','SYNTHETIC Filler','3095550103','Fictional Filler Lane','{"filler":false}')$t$,'23505','Request payload changed','Create cannot reuse request with different tags'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select public.create_classified_job(gen_random_uuid(),'SYNTHETIC Invalid','3095550104','Fictional Lane','{"trades":["unknown"]}')$t$,'22023','Invalid trades','Invalid classification prevents job creation'));
insert into pg_temp.eigsti_tag_ids values('sub',(public.save_subcontractor(null,'abcdefab-cdef-4abc-8abc-000000000003','{"name":"SYNTHETIC Trades","phone":"3095550105","email":"trade@example.invalid","trades":["painting","drywall"]}')->>'id')::uuid);
insert into pg_temp.eigsti_tag_results(result) values(is((select cardinality(trades) from public.subcontractors where id=(select id from pg_temp.eigsti_tag_ids where label='sub')),2::integer,'Subcontractor supports multiple trades'));
insert into pg_temp.eigsti_tag_results(result) values(is((select phone_action from public.subcontractors where id=(select id from pg_temp.eigsti_tag_ids where label='sub')),'+13095550105','Readable phone has callable value'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select public.save_subcontractor((select id from pg_temp.eigsti_tag_ids where label='sub'),gen_random_uuid(),'{"trades":["roofing"]}')$t$,'Directory trade edit is narrow'));
insert into pg_temp.eigsti_tag_results(result) values(is((select name||'/'||phone from public.subcontractors where id=(select id from pg_temp.eigsti_tag_ids where label='sub')),'SYNTHETIC Trades/3095550105','Trade edit preserves name/phone'));
insert into pg_temp.eigsti_tag_results(result) values(ok((select trades=array['electrical','plumbing']::text[] from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Directory edit does not add scopes to project'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select public.save_subcontractor(null,gen_random_uuid(),'{"name":"X","phone":"","email":"bad","trades":[]}')$t$,'22023','Invalid subcontractor','Invalid directory email rejected'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$update public.jobs set filler=false$t$,'42501',null,'Direct job metadata overwrite denied'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$update public.subcontractors set name='forged'$t$,'42501',null,'Direct directory overwrite denied'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.jobs where filler),1::bigint,'Lead sees only owned tagged job, not unassigned filler'));
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.subcontractors where id=(select id from pg_temp.eigsti_tag_ids where label='sub')),1::bigint,'Lead can read trade directory'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"rain_day":true}')$t$,'42501','PM account required','Lead cannot edit job classification'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select public.save_subcontractor(null,gen_random_uuid(),'{"name":"X","phone":"","email":"","trades":[]}')$t$,'42501','Directory manager required','Lead cannot edit global directory'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.jobs where filler),0::bigint,'Unassigned helper cannot browse filler customer data'));
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.subcontractors),0::bigint,'Helper cannot browse global directory'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"filler":true}')$t$,'42501','PM account required','Helper cannot forge tag save'));
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"filler":true}')$t$,'42501','PM account required','Admin alone is not a project manager'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select public.save_subcontractor((select id from pg_temp.eigsti_tag_ids where label='sub'),gen_random_uuid(),'{"email":""}')$t$,'Admin manages directory and clears optional field'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select public.save_subcontractor((select id from pg_temp.eigsti_tag_ids where label='sub'),'abcdefab-cdef-4abc-8abc-000000000004','{"archive":true}')$t$,'Directory archive retains identity'));
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.subcontractors where id=(select id from pg_temp.eigsti_tag_ids where label='sub')),0::bigint,'Archived contact hidden from directory'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select public.save_subcontractor((select id from pg_temp.eigsti_tag_ids where label='sub'),'abcdefab-cdef-4abc-8abc-000000000004','{"archive":true}')$t$,'Archive retry acknowledged without restoring contact'));
select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select public.save_subcontractor(null,gen_random_uuid(),'{"name":"X","phone":"","email":"","trades":[]}')$t$,'42501','Directory manager required','Disabled manager denied'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"filler":true}')$t$,'42501','PM account required','Disabled PM denied'));
set local role anon;
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select public.save_job_classification('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'{"filler":true}')$t$,'42501',null,'Anonymous RPC denied'));
reset role;
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.visits v join public.work_items w on w.id=v.work_item_id where w.job_id in ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',(select id from pg_temp.eigsti_tag_ids where label='filler'))),0::bigint,'Tags and filler creation never book a date or staff'));
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.jobs where customer_name='SYNTHETIC Invalid'),0::bigint,'Invalid creation leaves no job behind'));
insert into pg_temp.eigsti_tag_results(result) values(ok(exists(select 1 from private.classification_events where before_state->>'rain_day'='true' and after_state->>'rain_day'='false'),'Job classification before/after history retained'));
insert into pg_temp.eigsti_tag_results(result) values(ok(exists(select 1 from private.subcontractor_events where subcontractor_id=(select id from pg_temp.eigsti_tag_ids where label='sub') and after_state->>'archived_at' is not null),'Directory archive history retained'));
insert into pg_temp.eigsti_tag_results(result) values(ok(not has_table_privilege('authenticated','private.classification_events','UPDATE') and not has_table_privilege('authenticated','private.subcontractor_events','DELETE'),'Employees cannot alter metadata history'));
do $validation$
declare failures text;
begin
 if (select count(*) from pg_temp.eigsti_tag_results)<>51 then raise exception 'Incomplete tag checks: expected 51'; end if;
 select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_tag_results where result not like 'ok %';
 if failures is not null then raise exception 'Tag/trade checks failed: %',failures; end if;
end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_tag_results;

rollback to savepoint eigsti_combined_checks_1;
release savepoint eigsti_combined_checks_1;

commit;
select 111::integer as checks,0::integer as failed,'0010 and 0011 applied; synthetic fixtures removed'::text as result;
