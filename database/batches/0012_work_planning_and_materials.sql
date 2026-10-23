-- TEST PROJECT ONLY: apply once after applied 0011. Never rerun 0010/0011.
-- DDL and 42 checks commit together. Synthetic fixtures roll back before commit.
begin;
do $preflight$
begin
 if to_regprocedure('public.save_subcontractor(uuid,uuid,jsonb)') is null or to_regprocedure('public.save_visit_card(uuid,uuid,uuid,jsonb,uuid[])') is null then raise exception 'Planning batch requires applied 0011 and 0009.'; end if;
 if to_regprocedure('public.create_job_work_with_plan(uuid,uuid,jsonb,jsonb)') is not null or exists(select 1 from information_schema.columns where table_schema='public' and table_name='work_items' and column_name='material_status') then raise exception '0012 may already be applied. Do not rerun; verify project state.'; end if;
end; $preflight$;
-- Apply once after 0011 in the isolated test project. No user/job fixtures.
create function public.create_job_work_with_plan(p_job_id uuid,p_request_id uuid,p_values jsonb,p_plan jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare vals jsonb; payload jsonb; prior private.command_requests%rowtype; result jsonb; planned jsonb; k text;
begin
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_job_id is null or p_request_id is null then raise exception using errcode='22023',message='Invalid work details'; end if;
 vals:=private.work_patch(p_values);
 if not(vals ?& array['description','responsible_lead']) then raise exception using errcode='22023',message='Incomplete work details'; end if;
 if p_plan is not null then
  if jsonb_typeof(p_plan)<>'object' or not(p_plan ?& array['start_date','end_date','slot','coordinator_id']) then raise exception using errcode='22023',message='Invalid visit'; end if;
  for k in select jsonb_object_keys(p_plan) loop
   if k not in ('start_date','end_date','slot','start_time','end_time','coordinator_id','required_helpers','certainty') then raise exception using errcode='22023',message='Invalid visit field'; end if;
  end loop;
  if vals->>'responsible_lead' is null or p_plan->>'coordinator_id' is distinct from vals->>'responsible_lead' then raise exception using errcode='22023',message='Active lead required'; end if;
 end if;
 payload:=jsonb_build_object('job',p_job_id,'values',vals,'plan',p_plan);
 -- Same schedule -> actor -> job ordering used by existing visit/card commands.
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 perform id from public.jobs where id=p_job_id and lifecycle='open' for update;
 if not found then raise exception using errcode='P0002',message='Open job required'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='create_job_work_with_plan' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 result:=public.create_job_work(p_job_id,p_request_id,vals);
 if p_plan is not null then planned:=public.save_visit((result->>'id')::uuid,null,p_request_id,p_plan); end if;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id)
 values(auth.uid(),'create_job_work_with_plan',p_request_id,payload,(result->>'id')::uuid);
 return result;
end; $$;

alter table public.work_items
 add column material_name text not null default '' check(length(material_name)<=300 and material_name !~ '[[:cntrl:]]'),
 add column material_status text not null default 'not_set' check(material_status in ('not_set','not_needed','need_to_order','ordered','in_stock')),
 add column material_expected_on date check(material_expected_on is null or material_expected_on between date '2000-01-01' and date '2099-12-31');
create table private.work_material_events (
 id uuid primary key default gen_random_uuid(),work_id uuid not null references public.work_items(id),
 actor_id uuid not null references public.app_users(id),request_id uuid not null,
 before_state jsonb not null,after_state jsonb not null,created_at timestamptz not null default now()
);
alter table private.work_material_events enable row level security;
revoke all on private.work_material_events from public,anon,authenticated;

create function public.save_work_materials(p_work_id uuid,p_request_id uuid,p_values jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items%rowtype; j public.jobs%rowtype; prior private.command_requests%rowtype;
 name_value text; status_value text; expected date; payload jsonb; before_data jsonb; k text;
begin
 if not(private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Work planner required'; end if;
 if p_work_id is null or p_request_id is null or p_values is null or jsonb_typeof(p_values)<>'object' or not(p_values ?& array['material_name','material_status','material_expected_on']) then raise exception using errcode='22023',message='Invalid material details'; end if;
 for k in select jsonb_object_keys(p_values) loop
  if k not in ('material_name','material_status','material_expected_on') then raise exception using errcode='22023',message='Invalid material details'; end if;
 end loop;
 if jsonb_typeof(p_values->'material_name')<>'string' or jsonb_typeof(p_values->'material_status')<>'string' then raise exception using errcode='22023',message='Invalid material details'; end if;
 name_value:=btrim(p_values->>'material_name');status_value:=p_values->>'material_status';
 if length(name_value)>300 or name_value ~ '[[:cntrl:]]' or status_value not in ('not_set','not_needed','need_to_order','ordered','in_stock') or (status_value in ('need_to_order','ordered','in_stock') and name_value='') then raise exception using errcode='22023',message='Invalid material details'; end if;
 if p_values->'material_expected_on'<>'null'::jsonb then
  if jsonb_typeof(p_values->'material_expected_on')<>'string' or (p_values->>'material_expected_on')!~'^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' then raise exception using errcode='22023',message='Invalid material date'; end if;
  expected:=(p_values->>'material_expected_on')::date;
 end if;
 if status_value in ('not_set','not_needed','in_stock') and expected is not null then raise exception using errcode='22023',message='Invalid material date'; end if;
 payload:=jsonb_build_object('work',p_work_id,'values',jsonb_build_object('material_name',name_value,'material_status',status_value,'material_expected_on',expected));
 perform id from public.app_users where id=auth.uid() for share;
 if not(private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Work planner required'; end if;
 select x.* into j from public.jobs x join public.work_items y on y.job_id=x.id where y.id=p_work_id for update of x;
 select * into w from public.work_items where id=p_work_id for update;
 if w.id is null then raise exception using errcode='P0002',message='Work unavailable'; end if;
 if not private.has_role('pm') and w.responsible_lead is distinct from auth.uid() then raise exception using errcode='42501',message='Responsible lead required'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='save_work_materials' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',w.id,'job_id',j.id);
 end if;
 if j.lifecycle<>'open' or w.completion<>'open' then raise exception using errcode='22023',message='Open work required'; end if;
 before_data:=to_jsonb(w);
 update public.work_items set material_name=name_value,material_status=status_value,material_expected_on=expected,
 readiness=case when status_value in ('in_stock','not_needed') then 'ready' when expected is not null then 'waiting_date' else 'waiting_unknown' end,
 waiting_until=expected,updated_at=clock_timestamp(),updated_by=auth.uid() where id=w.id;
 insert into private.work_material_events(work_id,actor_id,request_id,before_state,after_state)
 select w.id,auth.uid(),p_request_id,before_data,to_jsonb(updated) from public.work_items updated where id=w.id;
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
 values(j.id,auth.uid(),'save_work_materials',array['materials','readiness'],p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'save_work_materials',p_request_id,payload,w.id);
 return jsonb_build_object('id',w.id,'job_id',j.id);
end; $$;
revoke all on function public.create_job_work_with_plan(uuid,uuid,jsonb,jsonb),public.save_work_materials(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.create_job_work_with_plan(uuid,uuid,jsonb,jsonb),public.save_work_materials(uuid,uuid,jsonb) to authenticated;
notify pgrst,'reload schema';

savepoint planning_fixture_checks;
-- Isolated test project only. Synthetic fixtures and every change roll back.
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_planning_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_planning_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_planning_results,pg_temp.eigsti_planning_ids to authenticated,anon;
grant usage on sequence pg_temp.eigsti_planning_results_ordinal_seq to authenticated,anon;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','planning-pm@example.invalid'),
('33333333-3333-4333-8333-333333333333','planning-lead@example.invalid'),
('44444444-4444-4444-8444-444444444444','planning-other@example.invalid'),
('55555555-5555-4555-8555-555555555555','planning-helper@example.invalid'),
('77777777-7777-4777-8777-777777777777','planning-admin@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC PM',array['pm'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Lead',array['lead'],true),
('44444444-4444-4444-8444-444444444444','SYNTHETIC Other lead',array['lead'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Helper',array['helper'],true),
('77777777-7777-4777-8777-777777777777','SYNTHETIC Admin',array['admin'],true);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,scope,access_notes,responsible_pm,created_by,updated_by) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Planning','3095550101','+13095550101','Fictional Lane','SYNTHETIC Planning','Keep scope','Keep access','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
create function pg_temp.plan(r uuid,p jsonb default null,n text default 'SYNTHETIC Dated') returns jsonb language sql as $$
 select public.create_job_work_with_plan('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',r,jsonb_build_object('description',n,'responsible_lead','33333333-3333-4333-8333-333333333333'),p);
$$;
create function pg_temp.material(s text,d text default null,r uuid default gen_random_uuid()) returns jsonb language sql as $$
 select public.save_work_materials((select id from pg_temp.eigsti_planning_ids where label='dated'),r,jsonb_build_object('material_name','Cabinets','material_status',s,'material_expected_on',d));
$$;
-- Exercise the same scoped read command as the app, without direct table grants.
create function pg_temp.planning_visits()
returns table(id uuid,work_item_id uuid,required_helpers integer,slot text,start_time text,end_time text)
language sql as $$
 select * from jsonb_to_recordset(public.list_job_visits('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'))
 as v(id uuid,work_item_id uuid,required_helpers integer,slot text,start_time text,end_time text);
$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_planning_results(result) values(lives_ok($t$select pg_temp.plan('abcdefab-cdef-4abc-8abc-000000000001',null,'SYNTHETIC Undated')$t$,'Work can be saved without dates'));
insert into pg_temp.eigsti_planning_results(result) values(is((select count(*) from pg_temp.planning_visits() v join public.work_items w on w.id=v.work_item_id where w.description='SYNTHETIC Undated'),0::bigint,'Undated work creates no calendar entry'));
insert into pg_temp.eigsti_planning_results(result) values(lives_ok($t$select pg_temp.plan('abcdefab-cdef-4abc-8abc-000000000002','{"start_date":"2026-10-23","end_date":"2026-10-23","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":2}')$t$,'Work and optional date save together'));
insert into pg_temp.eigsti_planning_ids select 'dated',id from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC Dated';
insert into pg_temp.eigsti_planning_results(result) values(is((select count(*) from pg_temp.planning_visits() where work_item_id=(select id from pg_temp.eigsti_planning_ids where label='dated')),1::bigint,'One scheduled entry created'));
insert into pg_temp.eigsti_planning_results(result) values(ok((select required_helpers=2 and slot='day' and start_time is null and end_time is null from pg_temp.planning_visits() where work_item_id=(select id from pg_temp.eigsti_planning_ids where label='dated')),'Help can be requested without named people or a time block'));
insert into pg_temp.eigsti_planning_results(result) values(lives_ok($t$select pg_temp.plan('abcdefab-cdef-4abc-8abc-000000000002','{"start_date":"2026-10-23","end_date":"2026-10-23","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":2}')$t$,'Identical retry is acknowledged'));
insert into pg_temp.eigsti_planning_results(result) values(is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC Dated'),1::bigint,'Retry does not duplicate work'));
insert into pg_temp.eigsti_planning_results(result) values(is((select count(*) from pg_temp.planning_visits() where work_item_id=(select id from pg_temp.eigsti_planning_ids where label='dated')),1::bigint,'Retry does not duplicate schedule'));
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select pg_temp.plan('abcdefab-cdef-4abc-8abc-000000000002',null)$t$,'23505','Request payload changed','Changing a retry payload is rejected'));
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select pg_temp.plan('abcdefab-cdef-4abc-8abc-000000000003','{"start_date":"2026-10-24","end_date":"2026-10-24","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333"}','SYNTHETIC Failed date')$t$,null,null,'Weekend scheduling fails'));
insert into pg_temp.eigsti_planning_results(result) values(is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC Failed date'),0::bigint,'Failed schedule rolls back the work creation'));
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select public.create_job_work_with_plan('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'{"description":"SYNTHETIC Missing lead","responsible_lead":null}','{"start_date":"2026-10-23","end_date":"2026-10-23","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333"}')$t$,'22023','Active lead required','Dated work needs its responsible lead'));
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select pg_temp.plan(gen_random_uuid(),'{"start_date":"2026-10-23","end_date":"2026-10-23","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","state":"cancelled"}')$t$,'22023','Invalid visit field','Schedule creation cannot inject cancellation'));
insert into pg_temp.eigsti_planning_results(result) values(lives_ok($t$select pg_temp.material('need_to_order')$t$,'PM records material needing an order'));
insert into pg_temp.eigsti_planning_results(result) values(ok((select material_status='need_to_order' and readiness='waiting_unknown' and waiting_until is null from public.work_items where id=(select id from pg_temp.eigsti_planning_ids where label='dated')),'Need to order is waiting with no invented date'));
insert into pg_temp.eigsti_planning_results(result) values(lives_ok($t$select pg_temp.material('ordered','2020-01-01','abcdefab-cdef-4abc-8abc-000000000010')$t$,'Expected arrival date can be recorded'));
insert into pg_temp.eigsti_planning_results(result) values(ok((select material_status='ordered' and readiness='waiting_date' and waiting_until=date '2020-01-01' from public.work_items where id=(select id from pg_temp.eigsti_planning_ids where label='dated')),'Elapsed expected date does not mark material in stock'));
insert into pg_temp.eigsti_planning_results(result) values(lives_ok($t$select pg_temp.material('in_stock')$t$,'PM explicitly records material arrival'));
insert into pg_temp.eigsti_planning_results(result) values(ok((select readiness='ready' and material_status='in_stock' and waiting_until is null and material_expected_on is null from public.work_items where id=(select id from pg_temp.eigsti_planning_ids where label='dated')),'In stock clears the expected date and material hold'));
insert into pg_temp.eigsti_planning_results(result) values(lives_ok($t$select pg_temp.material('ordered','2020-01-01','abcdefab-cdef-4abc-8abc-000000000010')$t$,'Old material retry is acknowledged'));
insert into pg_temp.eigsti_planning_results(result) values(is((select material_status from public.work_items where id=(select id from pg_temp.eigsti_planning_ids where label='dated')),'in_stock','Old retry never overwrites newer stock status'));
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select pg_temp.material('ordered','2020-01-02','abcdefab-cdef-4abc-8abc-000000000010')$t$,'23505','Request payload changed','Changed material retry is rejected'));
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select pg_temp.material('invented')$t$,'22023','Invalid material details','Unknown material state rejected'));
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select pg_temp.material('in_stock','2026-10-23')$t$,'22023','Invalid material date','In-stock cannot retain an expected arrival'));
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select public.save_work_materials((select id from pg_temp.eigsti_planning_ids where label='dated'),gen_random_uuid(),'{"material_name":"Cabinets","material_status":"ordered","material_expected_on":null,"responsible_lead":null}')$t$,'22023','Invalid material details','Material edits cannot change ownership'));
insert into pg_temp.eigsti_planning_results(result) values(is((select scope||'/'||access_notes from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Keep scope/Keep access','Planning/material edits preserve job details'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_planning_results(result) values(lives_ok($t$select pg_temp.material('ordered')$t$,'Responsible lead can update materials'));
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select pg_temp.plan(gen_random_uuid())$t$,'42501','PM account required','Lead cannot create work by forging the command'));
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select pg_temp.material('in_stock')$t$,'42501','Responsible lead required','Unrelated lead cannot update materials'));
insert into pg_temp.eigsti_planning_results(result) values(is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),0::bigint,'Unrelated lead cannot read material fields through the table'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_planning_results(result) values(lives_ok($t$select public.staff_visit((select id from pg_temp.planning_visits() where work_item_id=(select id from pg_temp.eigsti_planning_ids where label='dated')),gen_random_uuid(),array['55555555-5555-4555-8555-555555555555']::uuid[])$t$,'PM assigns named help without a separate plan status'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_planning_results(result) values(is((select material_status from public.work_items where id=(select id from pg_temp.eigsti_planning_ids where label='dated')),'ordered','Assigned helper can read material availability'));
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select pg_temp.material('in_stock')$t$,'42501','Work planner required','Helper cannot update material status'));
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select pg_temp.plan(gen_random_uuid())$t$,'42501','PM account required','Helper cannot create work'));
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select pg_temp.material('in_stock')$t$,'42501','Work planner required','Admin-only is not a work planner'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_planning_results(result) values(lives_ok($t$select pg_temp.plan('abcdefab-cdef-4abc-8abc-000000000021','{"start_date":"2026-10-23","end_date":"2026-10-23","slot":"timed","start_time":"08:00","end_time":"09:00","coordinator_id":"33333333-3333-4333-8333-333333333333"}','SYNTHETIC Reserved')$t$,'Optional timed reservation uses existing staffing rules'));
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select pg_temp.plan('abcdefab-cdef-4abc-8abc-000000000022','{"start_date":"2026-10-23","end_date":"2026-10-23","slot":"timed","start_time":"08:30","end_time":"09:30","coordinator_id":"33333333-3333-4333-8333-333333333333"}','SYNTHETIC Conflict')$t$,'23P01',null,'Conflicting reservation rejects the entire save'));
insert into pg_temp.eigsti_planning_results(result) values(is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC Conflict'),0::bigint,'Conflict leaves no orphan work item'));
reset role;
update public.app_users set active=false where id='33333333-3333-4333-8333-333333333333';
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_planning_results(result) values(throws_ok($t$select pg_temp.material('in_stock')$t$,'42501','Work planner required','Deactivated lead loses material mutation access'));
reset role;
insert into pg_temp.eigsti_planning_results(result) values(ok((select count(*)>=4 from private.work_material_events where work_id=(select id from pg_temp.eigsti_planning_ids where label='dated')),'Material updates preserve append-only snapshots'));
insert into pg_temp.eigsti_planning_results(result) values(ok(not has_table_privilege('authenticated','private.work_material_events','UPDATE') and not has_table_privilege('authenticated','private.work_material_events','DELETE'),'Employees cannot rewrite material history'));
insert into pg_temp.eigsti_planning_results(result) values(ok(not has_function_privilege('anon','public.save_work_materials(uuid,uuid,jsonb)','EXECUTE') and not has_function_privilege('anon','public.create_job_work_with_plan(uuid,uuid,jsonb,jsonb)','EXECUTE'),'Anonymous callers have no new command access'));
do $validation$
declare failures text;
begin
 if (select count(*) from pg_temp.eigsti_planning_results)<>42 then raise exception 'Incomplete planning checks: expected 42'; end if;
 select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_planning_results where result not like 'ok %';
 if failures is not null then raise exception 'Planning checks failed: %',failures; end if;
end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_planning_results;

rollback to savepoint planning_fixture_checks;
release savepoint planning_fixture_checks;
commit;
select 42::integer as checks,0::integer as failed,'0012 applied; synthetic fixtures removed'::text as result;
