-- Isolated test project only. Synthetic fixtures and every change roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_first_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_first_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_first_results,pg_temp.eigsti_first_ids to authenticated,anon;
grant usage on sequence pg_temp.eigsti_first_results_ordinal_seq to authenticated,anon;
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

create function pg_temp.first_work(r uuid,n text default 'SYNTHETIC First-save help',p jsonb default '{"start_date":"2099-01-05","end_date":"2099-01-05","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":2,"certainty":"tentative"}',h jsonb default '["55555555-5555-4555-8555-555555555555","44444444-4444-4444-8444-444444444444"]') returns jsonb language sql as $helper$select public.create_staffed_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',r,jsonb_build_object('description',n,'responsible_lead','33333333-3333-4333-8333-333333333333'),p,2,null,'0.5',h);$helper$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_first_results(result) values(is((select count(*) from jsonb_array_elements(public.planning_staff('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')) x where x->>'id' in ('33333333-3333-4333-8333-333333333333','44444444-4444-4444-8444-444444444444','55555555-5555-4555-8555-555555555555')),3::bigint,'PM directory includes active helpers and leads'));
insert into pg_temp.eigsti_first_results(result) values(is((select count(*) from jsonb_array_elements(public.planning_staff(null)) x where x->>'id' in ('33333333-3333-4333-8333-333333333333','44444444-4444-4444-8444-444444444444','55555555-5555-4555-8555-555555555555')),3::bigint,'PM may choose helping staff during job setup'));
insert into pg_temp.eigsti_first_results(result) values(lives_ok($t$select pg_temp.first_work('abcdefab-cdef-4abc-8abc-000000000301')$t$,'Task date and multiple helpers save together first time'));
insert into pg_temp.eigsti_first_ids select 'work',id from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC First-save help';
insert into pg_temp.eigsti_first_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.list_job_visits('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')) v where v->>'work_item_id'=(select id::text from pg_temp.eigsti_first_ids where label='work') and jsonb_array_length(v->'participants')=3),'Coordinator plus two named helpers are stored'));
insert into pg_temp.eigsti_first_results(result) values(lives_ok($t$select pg_temp.first_work('abcdefab-cdef-4abc-8abc-000000000301')$t$,'Whole first-save retry acknowledged'));
insert into pg_temp.eigsti_first_results(result) values(is((select count(*) from public.work_items where description='SYNTHETIC First-save help'),1::bigint,'Retry does not create another task'));
insert into pg_temp.eigsti_first_results(result) values(throws_ok($t$select pg_temp.first_work('abcdefab-cdef-4abc-8abc-000000000301','Different')$t$,'23505','Request payload changed','Changed retry rejected'));
insert into pg_temp.eigsti_first_results(result) values(throws_ok($t$select pg_temp.first_work(gen_random_uuid(),'SYNTHETIC Missing date',null)$t$,'22023','Choose a date to assign named help','Named reservations require a date'));
insert into pg_temp.eigsti_first_results(result) values(is((select count(*) from public.work_items where description='SYNTHETIC Missing date'),0::bigint,'Missing date creates no partial task'));
insert into pg_temp.eigsti_first_results(result) values(lives_ok($t$select pg_temp.first_work(gen_random_uuid(),'SYNTHETIC Undated need',null,'[]')$t$,'Undated helper requests remain supported'));
insert into pg_temp.eigsti_first_results(result) values(throws_ok($t$select pg_temp.first_work(gen_random_uuid(),'SYNTHETIC Duplicate helpers',null,'["55555555-5555-4555-8555-555555555555","55555555-5555-4555-8555-555555555555"]')$t$,'22023','Invalid staffing','Duplicate helpers rejected'));
insert into pg_temp.eigsti_first_results(result) values(throws_ok($t$select pg_temp.first_work(gen_random_uuid(),'SYNTHETIC Ineligible helper','{"start_date":"2099-01-05","end_date":"2099-01-05","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":2,"certainty":"tentative"}','["77777777-7777-4777-8777-777777777777"]')$t$,null,null,'Admin-only cannot be helping crew'));
insert into pg_temp.eigsti_first_results(result) values(is((select count(*) from public.work_items where description='SYNTHETIC Ineligible helper'),0::bigint,'Staffing failure rolls task creation back'));
insert into pg_temp.eigsti_first_ids select 'undated',id from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC Undated need';
insert into pg_temp.eigsti_first_results(result) values(lives_ok($t$select public.save_work_setup_with_help((select id from pg_temp.eigsti_first_ids where label='undated'),'abcdefab-cdef-4abc-8abc-000000000302','{"estimated_days":1}','null','{"start_date":"2099-01-05","end_date":"2099-01-05","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":2,"certainty":"tentative"}','[]','["55555555-5555-4555-8555-555555555555"]')$t$,'Existing undated work receives date and helper in one save'));
insert into pg_temp.eigsti_first_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.list_job_visits('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')) v where v->>'work_item_id'=(select id::text from pg_temp.eigsti_first_ids where label='undated') and jsonb_array_length(v->'participants')=2),'Existing work has coordinator plus named helper'));
insert into pg_temp.eigsti_first_results(result) values(lives_ok($t$select public.save_work_setup_with_help((select id from pg_temp.eigsti_first_ids where label='undated'),'abcdefab-cdef-4abc-8abc-000000000302','{"estimated_days":1}','null','{"start_date":"2099-01-05","end_date":"2099-01-05","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":2,"certainty":"tentative"}','[]','["55555555-5555-4555-8555-555555555555"]')$t$,'Existing-work whole save is retry safe'));
insert into pg_temp.eigsti_first_results(result) values(throws_ok($t$select public.save_work_setup_with_help((select id from pg_temp.eigsti_first_ids where label='undated'),gen_random_uuid(),'{"estimated_days":5}',null,null,'[]','["55555555-5555-4555-8555-555555555555"]')$t$,'22023','Choose a date to assign named help','Missing new date cannot partially change work'));
insert into pg_temp.eigsti_first_results(result) values(ok((select estimated_days=1 from public.work_items where id=(select id from pg_temp.eigsti_first_ids where label='undated')),'Failed new help preserves original estimate'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_first_results(result) values(lives_ok($t$select public.planning_staff('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$t$,'Assigned lead can see scoped helping directory'));
insert into pg_temp.eigsti_first_results(result) values(throws_ok($t$select public.planning_staff(null)$t$,'42501','Work planner required','Lead cannot enumerate unscoped directory'));
insert into pg_temp.eigsti_first_results(result) values(throws_ok($t$select pg_temp.first_work(gen_random_uuid())$t$,'42501','PM account required','Lead cannot forge PM task creation'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_first_results(result) values(throws_ok($t$select public.planning_staff('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$t$,'42501','Work planner required','Helper cannot enumerate staff directory'));
insert into pg_temp.eigsti_first_results(result) values(throws_ok($t$select public.save_work_setup_with_help((select id from pg_temp.eigsti_first_ids where label='undated'),gen_random_uuid(),'{}',null,null,'[]','[]')$t$,'42501','Work planner required','Helper cannot forge card staffing'));
reset role;
insert into pg_temp.eigsti_first_results(result) values(ok(not has_function_privilege('anon','public.planning_staff(uuid)','EXECUTE'),'Anonymous directory denied'));
insert into pg_temp.eigsti_first_results(result) values(ok(not has_table_privilege('authenticated','public.visit_participants','INSERT'),'No direct staffing writes granted'));
do $validation$ declare failures text;begin select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_first_results where result not like 'ok %';if failures is not null then raise exception 'First-save helper checks failed: %',failures;end if;end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_first_results;
rollback;
