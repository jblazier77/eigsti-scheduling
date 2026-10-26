-- Isolated test project only. Synthetic fixtures and every change roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_setup_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_setup_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_setup_results,pg_temp.eigsti_setup_ids to authenticated,anon;
grant usage on sequence pg_temp.eigsti_setup_results_ordinal_seq to authenticated,anon;
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

create function pg_temp.setup(r uuid,p jsonb default '{"description":"SYNTHETIC Install window","estimated_days":1.25}',m jsonb default '{"material_name":"Window units","material_status":"in_stock","material_expected_on":null}',d jsonb default null,v jsonb default '[]') returns jsonb language sql as $helper$select public.save_work_setup((select id from pg_temp.eigsti_setup_ids where label='work'),r,p,m,d,v);$helper$;
create function pg_temp.setup_dates(helpers jsonb default '["55555555-5555-4555-8555-555555555555"]',p jsonb default '{"start_date":"2099-01-06","end_date":"2099-01-06"}',remove boolean default false) returns jsonb language sql as $helper$select jsonb_build_array(jsonb_build_object('id',(select id from pg_temp.eigsti_setup_ids where label='visit'),'patch',p,'helpers',helpers,'cancel',remove));$helper$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.create_planning_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','abcdefab-cdef-4abc-8abc-000000000201','{"description":"SYNTHETIC Work card","responsible_lead":"33333333-3333-4333-8333-333333333333"}',null,1,null,'0.5');
insert into pg_temp.eigsti_setup_ids select 'work',id from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC Work card';
insert into pg_temp.eigsti_setup_results(result) values(lives_ok($t$select pg_temp.setup('abcdefab-cdef-4abc-8abc-000000000202')$t$,'Name estimate and materials save in one transaction'));
insert into pg_temp.eigsti_setup_results(result) values(ok((select description='SYNTHETIC Install window' and estimated_days=1.25 and material_name='Window units' and material_status='in_stock' from public.work_items where id=(select id from pg_temp.eigsti_setup_ids where label='work')),'All work values persisted'));
insert into pg_temp.eigsti_setup_results(result) values(lives_ok($t$select pg_temp.setup('abcdefab-cdef-4abc-8abc-000000000202')$t$,'Whole-card retry acknowledged'));
insert into pg_temp.eigsti_setup_results(result) values(throws_ok($t$select pg_temp.setup('abcdefab-cdef-4abc-8abc-000000000202','{"description":"Different"}')$t$,'23505','Request payload changed','Changed retry rejected'));
insert into pg_temp.eigsti_setup_results(result) values(throws_ok($t$select pg_temp.setup(gen_random_uuid(),'{"estimated_days":2}','{"material_name":"Bad","material_status":"invented","material_expected_on":null}')$t$,'22023','Invalid material details','Invalid material rejects entire card'));
insert into pg_temp.eigsti_setup_results(result) values(ok((select estimated_days=1.25 and material_status='in_stock' from public.work_items where id=(select id from pg_temp.eigsti_setup_ids where label='work')),'Failed material rolls back estimate'));
insert into pg_temp.eigsti_setup_results(result) values(lives_ok($t$select pg_temp.setup('abcdefab-cdef-4abc-8abc-000000000203','{}','null','{"start_date":"2099-01-05","end_date":"2099-01-05","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":1,"certainty":"tentative"}')$t$,'Optional initial date saves in the same card'));
insert into pg_temp.eigsti_setup_ids select 'visit',(value->>'id')::uuid from jsonb_array_elements(public.list_job_visits('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')) where value->>'work_item_id'=(select id::text from pg_temp.eigsti_setup_ids where label='work');
insert into pg_temp.eigsti_setup_results(result) values(throws_ok($t$select pg_temp.setup(gen_random_uuid(),'{"estimated_days":3}','null','{"start_date":"2099-01-05","end_date":"2099-01-05","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":1,"certainty":"tentative"}')$t$,'22023','Edit existing work dates','Existing date cannot accidentally duplicate'));
insert into pg_temp.eigsti_setup_results(result) values(ok((select estimated_days=1.25 from public.work_items where id=(select id from pg_temp.eigsti_setup_ids where label='work')),'Duplicate-date rejection rolls back other fields'));
insert into pg_temp.eigsti_setup_results(result) values(lives_ok($t$select pg_temp.setup('abcdefab-cdef-4abc-8abc-000000000204','{"estimated_days":2}','null',null,pg_temp.setup_dates())$t$,'Estimate dates and named help save together'));
insert into pg_temp.eigsti_setup_results(result) values(ok((select estimated_days=2 from public.work_items where id=(select id from pg_temp.eigsti_setup_ids where label='work')),'Estimate updated with dates'));
insert into pg_temp.eigsti_setup_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.list_job_visits('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')) r where r->>'start_date'='2099-01-06' and jsonb_array_length(r->'participants')=2),'Date and helper were saved'));
insert into pg_temp.eigsti_setup_results(result) values(lives_ok($t$select pg_temp.setup('abcdefab-cdef-4abc-8abc-000000000204','{"estimated_days":2}','null',null,pg_temp.setup_dates())$t$,'Date/crew whole-save retry acknowledged'));
insert into pg_temp.eigsti_setup_results(result) values(throws_ok($t$select pg_temp.setup(gen_random_uuid(),'{"estimated_days":3}','null',null,pg_temp.setup_dates('["55555555-5555-4555-8555-555555555555","55555555-5555-4555-8555-555555555555"]'))$t$,'22023','Invalid staffing','Duplicate named help rejects whole card'));
insert into pg_temp.eigsti_setup_results(result) values(ok((select estimated_days=2 from public.work_items where id=(select id from pg_temp.eigsti_setup_ids where label='work')),'Invalid roster rolls back work changes'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_setup_results(result) values(lives_ok($t$select pg_temp.setup(gen_random_uuid(),'{"estimated_days":0.75}')$t$,'Responsible lead edits estimate and materials together'));
insert into pg_temp.eigsti_setup_results(result) values(throws_ok($t$select pg_temp.setup(gen_random_uuid(),'{"responsible_lead":null}','null')$t$,'42501','PM account required','Lead cannot reassign ownership'));
insert into pg_temp.eigsti_setup_results(result) values(throws_ok($t$select pg_temp.setup(gen_random_uuid(),'{}','null',null,pg_temp.setup_dates('[]','{}'))$t$,'42501','PM required to replace named help','Lead cannot remove assigned helpers'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_setup_results(result) values(throws_ok($t$select pg_temp.setup(gen_random_uuid())$t$,'42501','Work planner required','Helper cannot forge card save'));
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_setup_results(result) values(throws_ok($t$select pg_temp.setup(gen_random_uuid())$t$,'42501',null,'Unassigned lead cannot edit card'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_setup_results(result) values(lives_ok($t$select pg_temp.setup(gen_random_uuid(),'{}','null',null,pg_temp.setup_dates('null','{}',true))$t$,'PM removes a date using the same card save'));
insert into pg_temp.eigsti_setup_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.list_job_visits('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')) r where r->>'state'='cancelled'),'Removed date remains in history'));
insert into pg_temp.eigsti_setup_results(result) values(ok((select completion='open' and description='SYNTHETIC Install window' from public.work_items where id=(select id from pg_temp.eigsti_setup_ids where label='work')),'Removing date preserves the ordinary work task'));
insert into pg_temp.eigsti_setup_results(result) values(lives_ok($t$select pg_temp.setup('abcdefab-cdef-4abc-8abc-000000000202')$t$,'Original retry after later changes still acknowledges'));
insert into pg_temp.eigsti_setup_results(result) values(ok((select estimated_days=0.75 from public.work_items where id=(select id from pg_temp.eigsti_setup_ids where label='work')),'Original retry never overwrites later edits'));
reset role;
insert into pg_temp.eigsti_setup_results(result) values(ok(not has_function_privilege('anon','public.save_work_setup(uuid,uuid,jsonb,jsonb,jsonb,jsonb)','EXECUTE'),'Anonymous card save denied'));
insert into pg_temp.eigsti_setup_results(result) values(ok(not has_table_privilege('authenticated','public.work_items','UPDATE'),'Direct work writes remain denied'));
do $validation$ declare failures text;begin select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_setup_results where result not like 'ok %';if failures is not null then raise exception 'Unified work checks failed: %',failures;end if;end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_setup_results;
rollback;
