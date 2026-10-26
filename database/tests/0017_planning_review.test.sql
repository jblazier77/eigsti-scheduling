-- Isolated test project only. Synthetic fixtures and every change roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_review_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_review_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_review_results,pg_temp.eigsti_review_ids to authenticated,anon;
grant usage on sequence pg_temp.eigsti_review_results_ordinal_seq to authenticated,anon;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','quick-pm@example.invalid'),
('22222222-2222-4222-8222-222222222222','review-pm2@example.invalid'),
('33333333-3333-4333-8333-333333333333','quick-lead@example.invalid'),
('44444444-4444-4444-8444-444444444444','quick-other@example.invalid'),
('55555555-5555-4555-8555-555555555555','quick-helper@example.invalid'),
('77777777-7777-4777-8777-777777777777','quick-admin@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC PM',array['pm'],true),
('22222222-2222-4222-8222-222222222222','SYNTHETIC PM2',array['pm'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Lead',array['lead'],true),
('44444444-4444-4444-8444-444444444444','SYNTHETIC Other lead',array['lead'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Helper',array['helper'],true),
('77777777-7777-4777-8777-777777777777','SYNTHETIC Admin',array['admin'],true);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,scope,access_notes,responsible_pm,created_by,updated_by) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Planning','3095550101','+13095550101','Fictional Lane','SYNTHETIC Planning','Keep scope','Keep access','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');

create function pg_temp.review_create(r uuid default gen_random_uuid(), d jsonb default '0.5', h integer default 2, n text default 'SYNTHETIC Estimated work') returns jsonb language sql as $$ select public.create_planning_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',r,jsonb_build_object('description',n,'responsible_lead','33333333-3333-4333-8333-333333333333'),null,h,null,d); $$;
create function pg_temp.review_workspace(r uuid, tasks jsonb default '[]', contacts jsonb default '[]') returns jsonb language sql as $$select public.create_job_workspace(r,'SYNTHETIC Setup','3095550101','Fictional Setup Lane','{}','{"scope":"Keep scope","access_notes":"Gate note"}','2',tasks,contacts);$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','abcdefab-cdef-4abc-8abc-000000000101','1')$t$,'PM sets priority'));
insert into pg_temp.eigsti_review_results(result) values(is((select priority from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),1,'Priority persists'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','abcdefab-cdef-4abc-8abc-000000000101','1')$t$,'Priority retry succeeds'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','abcdefab-cdef-4abc-8abc-000000000101','2')$t$,'23505','Request payload changed','Changed priority retry blocked'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'0')$t$,'22023','Invalid planning number','Invalid priority 0 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'-1')$t$,'22023','Invalid planning number','Invalid priority -1 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'1.5')$t$,'22023','Invalid planning number','Invalid priority 1.5 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'10000')$t$,'22023','Invalid planning number','Invalid priority 10000 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'"1"')$t$,'22023','Invalid planning number','Invalid priority 1 denied'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'null')$t$,'Priority can be cleared'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select pg_temp.review_create('abcdefab-cdef-4abc-8abc-000000000102')$t$,'Half day and undated help saved together'));
insert into pg_temp.eigsti_review_ids select 'work',id from public.work_items where description='SYNTHETIC Estimated work' and job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
insert into pg_temp.eigsti_review_results(result) values(ok((select estimated_days=0.5 and default_helpers=2 from public.work_items where id=(select id from pg_temp.eigsti_review_ids where label='work')),'Estimate and helpers persisted'));
insert into pg_temp.eigsti_review_results(result) values(is(jsonb_array_length(public.pm_help_requests()),1,'Undated request appears on PM dashboard'));
insert into pg_temp.eigsti_review_results(result) values(ok((public.pm_help_requests()->0->>'missing')::integer=2,'Undated shortfall is two'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select pg_temp.review_create('abcdefab-cdef-4abc-8abc-000000000102')$t$,'Work retry acknowledged'));
insert into pg_temp.eigsti_review_results(result) values(is((select count(*) from public.work_items where description='SYNTHETIC Estimated work'),1::bigint,'No duplicate work'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_create(gen_random_uuid(),'0')$t$,'22023','Invalid planning number','Invalid estimated days 0 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_create(gen_random_uuid(),'-1')$t$,'22023','Invalid planning number','Invalid estimated days -1 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_create(gen_random_uuid(),'1000')$t$,'22023','Invalid planning number','Invalid estimated days 1000 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_create(gen_random_uuid(),'0.001')$t$,'22023','Invalid planning number','Invalid estimated days 0.001 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_create(gen_random_uuid(),'"1"')$t$,'22023','Invalid planning number','Invalid estimated days 1 denied'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.save_work_details((select id from pg_temp.eigsti_review_ids where label='work'),'abcdefab-cdef-4abc-8abc-000000000103','{"description":"SYNTHETIC Lead edited","estimated_days":1.25}')$t$,'Responsible lead edits task and days'));
insert into pg_temp.eigsti_review_results(result) values(ok((select estimated_days=1.25 and description='SYNTHETIC Lead edited' from public.work_items where id=(select id from pg_temp.eigsti_review_ids where label='work')),'Lead changes persisted'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_work_details((select id from pg_temp.eigsti_review_ids where label='work'),gen_random_uuid(),'{"responsible_lead":null}')$t$,'42501','PM account required','Lead cannot change ownership'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.pm_help_requests()$t$,'42501','PM account required','Lead cannot read PM dashboard'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'1')$t$,'42501','PM account required','Lead cannot set priority'));
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_work_details((select id from pg_temp.eigsti_review_ids where label='work'),gen_random_uuid(),'{"estimated_days":2}')$t$,'42501','Responsible lead required','Unassigned lead cannot edit'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_work_details((select id from pg_temp.eigsti_review_ids where label='work'),gen_random_uuid(),'{"estimated_days":2}')$t$,'42501','Work planner required','Helper cannot edit estimates'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select pg_temp.review_create('abcdefab-cdef-4abc-8abc-000000000102')$t$,'Original create retry after lead changes acknowledged'));
insert into pg_temp.eigsti_review_results(result) values(ok((select estimated_days=1.25 and description='SYNTHETIC Lead edited' from public.work_items where id=(select id from pg_temp.eigsti_review_ids where label='work')),'Create retry preserves subsequent edits'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select pg_temp.review_workspace('abcdefab-cdef-4abc-8abc-000000000104')$t$,'Minimal full-page job save succeeds'));
insert into pg_temp.eigsti_review_ids values('setup',(pg_temp.review_workspace('abcdefab-cdef-4abc-8abc-000000000104')->>'id')::uuid);
insert into pg_temp.eigsti_review_results(result) values(ok((select scope='Keep scope' and access_notes='Gate note' and priority=2 from public.jobs where id=(select id from pg_temp.eigsti_review_ids where label='setup')),'Scope notes and priority saved together'));
insert into pg_temp.eigsti_review_results(result) values(is((select count(*) from public.work_items where job_id=(select id from pg_temp.eigsti_review_ids where label='setup')),1::bigint,'Minimal save keeps Whole job'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select pg_temp.review_workspace('abcdefab-cdef-4abc-8abc-000000000105','[{"values":{"description":"SYNTHETIC Setup work","responsible_lead":"33333333-3333-4333-8333-333333333333"},"plan":null,"helpers":1,"materials":{"material_name":"Windows","material_status":"in_stock","material_expected_on":null},"days":0.5}]','[{"name":"SYNTHETIC Installer","relationship":"Subcontractor","phone":"3095550102","email":"","notes":"Call ahead"}]')$t$,'Work materials help and contact save with job'));
insert into pg_temp.eigsti_review_ids values('full',(pg_temp.review_workspace('abcdefab-cdef-4abc-8abc-000000000105','[{"values":{"description":"SYNTHETIC Setup work","responsible_lead":"33333333-3333-4333-8333-333333333333"},"plan":null,"helpers":1,"materials":{"material_name":"Windows","material_status":"in_stock","material_expected_on":null},"days":0.5}]','[{"name":"SYNTHETIC Installer","relationship":"Subcontractor","phone":"3095550102","email":"","notes":"Call ahead"}]')->>'id')::uuid);
insert into pg_temp.eigsti_review_results(result) values(is((select count(*) from public.work_items where job_id=(select id from pg_temp.eigsti_review_ids where label='full')),1::bigint,'Explicit task replaces newly created placeholder only'));
insert into pg_temp.eigsti_review_results(result) values(ok((select estimated_days=0.5 and default_helpers=1 and material_status='in_stock' from public.work_items where job_id=(select id from pg_temp.eigsti_review_ids where label='full')),'Nested quick-work details preserved'));
insert into pg_temp.eigsti_review_results(result) values(is((select count(*) from public.job_contacts where job_id=(select id from pg_temp.eigsti_review_ids where label='full')),1::bigint,'Contact created exactly once'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_workspace('abcdefab-cdef-4abc-8abc-000000000106','[{"values":{"description":"SYNTHETIC Setup work","responsible_lead":"33333333-3333-4333-8333-333333333333"},"plan":null,"helpers":1,"materials":{"material_name":"Windows","material_status":"in_stock","material_expected_on":null},"days":-1}]','[{"name":"SYNTHETIC Installer","relationship":"Subcontractor","phone":"3095550102","email":"","notes":"Call ahead"}]')$t$,'22023','Invalid planning number','Invalid task rolls back entire new job'));
insert into pg_temp.eigsti_review_results(result) values(is((select count(*) from public.jobs where address='Fictional Setup Lane'),2::bigint,'Failed setup leaves no partial job'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_workspace('abcdefab-cdef-4abc-8abc-000000000105')$t$,'23505','Request payload changed','Changed job setup retry rejected'));
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_review_results(result) values(is(jsonb_array_length(public.pm_help_requests()),0,'Other PM cannot see these requests'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.save_visit((select id from pg_temp.eigsti_review_ids where label='work'),null,'abcdefab-cdef-4abc-8abc-000000000111','{"start_date":"2099-01-05","end_date":"2099-01-05","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":2,"certainty":"tentative"}')$t$,'Estimated task can still be scheduled with no time'));
insert into pg_temp.eigsti_review_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.pm_help_requests()) r where r->>'work_id'=(select id::text from pg_temp.eigsti_review_ids where label='work') and r->>'start_date'='2099-01-05' and (r->>'missing')::integer=2),'Scheduled help replaces undated request'));
insert into pg_temp.eigsti_review_results(result) values(ok((select estimated_days=1.25 from public.work_items where id=(select id from pg_temp.eigsti_review_ids where label='work')),'Scheduling preserves estimate'));
insert into pg_temp.eigsti_review_ids values('visit',(select (r->>'visit_id')::uuid from jsonb_array_elements(public.pm_help_requests()) r where r->>'work_id'=(select id::text from pg_temp.eigsti_review_ids where label='work') limit 1));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.staff_visit((select id from pg_temp.eigsti_review_ids where label='visit'),gen_random_uuid(),array['55555555-5555-4555-8555-555555555555']::uuid[])$t$,'First helper assigned'));
insert into pg_temp.eigsti_review_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.pm_help_requests()) r where r->>'work_id'=(select id::text from pg_temp.eigsti_review_ids where label='work') and (r->>'assigned')::integer=1 and (r->>'missing')::integer=1),'Partially filled request remains visible'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.staff_visit((select id from pg_temp.eigsti_review_ids where label='visit'),gen_random_uuid(),array['55555555-5555-4555-8555-555555555555','44444444-4444-4444-8444-444444444444']::uuid[])$t$,'Lead may fill second helping space'));
insert into pg_temp.eigsti_review_results(result) values(ok(not exists(select 1 from jsonb_array_elements(public.pm_help_requests()) r where r->>'work_id'=(select id::text from pg_temp.eigsti_review_ids where label='work')),'Filled request clears automatically'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.create_classified_job('abcdefab-cdef-4abc-8abc-000000000112','SYNTHETIC Legacy','3095550101','Legacy Lane','{}')$t$,'Legacy creation remains available'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.create_job_workspace('abcdefab-cdef-4abc-8abc-000000000112','SYNTHETIC Legacy','3095550101','Legacy Lane','{}','{}','null','[]','[]')$t$,'23505','Request payload changed','Workspace cannot upgrade an existing job request'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.create_planning_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','abcdefab-cdef-4abc-8abc-000000000120','{"description":"SYNTHETIC JSON null options","responsible_lead":null}','null',0,'null','null')$t$,'Explicit JSON null dates materials and estimate stay optional'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.create_planning_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','abcdefab-cdef-4abc-8abc-000000000120','{"description":"SYNTHETIC JSON null options","responsible_lead":null}',null,0,null,null)$t$,'SQL NULL retry has the same canonical payload'));
insert into pg_temp.eigsti_review_results(result) values(is((select count(*) from public.work_items where description='SYNTHETIC JSON null options'),1::bigint,'Null representations do not duplicate work'));
reset role;
insert into pg_temp.eigsti_review_results(result) values(ok(not has_function_privilege('anon','public.pm_help_requests()','EXECUTE'),'Anonymous dashboard denied'));
insert into pg_temp.eigsti_review_results(result) values(ok(not has_table_privilege('authenticated','public.jobs','UPDATE'),'No direct job writes granted'));
insert into pg_temp.eigsti_review_results(result) values(ok(not has_table_privilege('authenticated','public.work_items','UPDATE'),'No direct work writes granted'));
do $validation$ declare failures text; begin select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_review_results where result not like 'ok %'; if failures is not null then raise exception 'Planning review checks failed: %',failures; end if; end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_review_results;
rollback;
