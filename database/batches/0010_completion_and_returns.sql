-- SINGLE TEST-PROJECT UPDATE: apply 0010 and run 60 checks atomically.
-- Requires applied 0001-0009. Run this file ONCE, not the separate migration.
-- Failure aborts the outer transaction. Success removes all synthetic fixtures.
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

savepoint eigsti_completion_acceptance;
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

rollback to savepoint eigsti_completion_acceptance;
release savepoint eigsti_completion_acceptance;
commit;
select 60::integer as checks,0::integer as failed,'0010 applied; synthetic fixtures removed'::text as result;
