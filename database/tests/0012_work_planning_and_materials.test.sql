-- Isolated test project only. Synthetic fixtures and every change roll back.
begin;
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
rollback;



