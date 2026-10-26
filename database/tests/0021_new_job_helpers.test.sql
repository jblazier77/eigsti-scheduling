-- Isolated test project only. Synthetic fixtures and every change roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_new_helpers_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_new_helpers_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_new_helpers_results,pg_temp.eigsti_new_helpers_ids to authenticated,anon;
grant usage on sequence pg_temp.eigsti_new_helpers_results_ordinal_seq to authenticated,anon;
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
create function pg_temp.new_helpers_job(r uuid,h jsonb default '["55555555-5555-4555-8555-555555555555","44444444-4444-4444-8444-444444444444"]',p jsonb default '{"start_date":"2099-01-05","end_date":"2099-01-05","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":2,"certainty":"tentative"}') returns jsonb language sql as $helper$
 select public.create_job_workspace(r,'SYNTHETIC Crew setup','3095550101','Fictional Crew Setup Lane','{}','{}','null',jsonb_build_array(jsonb_build_object('values',jsonb_build_object('description','SYNTHETIC Install window','responsible_lead','33333333-3333-4333-8333-333333333333'),'helpers',2,'plan',p,'materials',null,'days',0.5,'named_helpers',h)),'[]');
$helper$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_new_helpers_results(result) values(lives_ok($q$select pg_temp.new_helpers_job('abcdefab-cdef-4abc-8abc-000000000001')$q$,'Create job work date and helpers together'));
insert into pg_temp.eigsti_new_helpers_ids values('job',(public.create_job_workspace('abcdefab-cdef-4abc-8abc-000000000001','SYNTHETIC Crew setup','3095550101','Fictional Crew Setup Lane','{}','{}','null',jsonb_build_array(jsonb_build_object('values',jsonb_build_object('description','SYNTHETIC Install window','responsible_lead','33333333-3333-4333-8333-333333333333'),'helpers',2,'plan','{"start_date":"2099-01-05","end_date":"2099-01-05","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":2,"certainty":"tentative"}'::jsonb,'materials',null,'days',0.5,'named_helpers','["55555555-5555-4555-8555-555555555555","44444444-4444-4444-8444-444444444444"]'::jsonb)),'[]')->>'id')::uuid);
reset role;
insert into pg_temp.eigsti_new_helpers_results(result) values(is((select count(*) from public.visit_participants vp join public.visits v on v.id=vp.visit_id join public.work_items w on w.id=v.work_item_id where w.job_id=(select id from pg_temp.eigsti_new_helpers_ids where label='job') and vp.duty='helping'),2::bigint,'Both named helpers saved'));
insert into pg_temp.eigsti_new_helpers_results(result) values(is((select count(*) from public.work_items where job_id=(select id from pg_temp.eigsti_new_helpers_ids where label='job')),1::bigint,'Only requested task; no placeholder'));
insert into pg_temp.eigsti_new_helpers_results(result) values(ok((select estimated_days=0.5 and default_helpers=2 from public.work_items where job_id=(select id from pg_temp.eigsti_new_helpers_ids where label='job')),'Estimate and request count retained'));
set local role authenticated;
insert into pg_temp.eigsti_new_helpers_results(result) values(lives_ok($q$select pg_temp.new_helpers_job('abcdefab-cdef-4abc-8abc-000000000001')$q$,'Unchanged retry succeeds'));
insert into pg_temp.eigsti_new_helpers_results(result) values(throws_ok($q$select pg_temp.new_helpers_job('abcdefab-cdef-4abc-8abc-000000000001','[]')$q$,'23505','Request payload changed','Changed helper retry rejected'));
insert into pg_temp.eigsti_new_helpers_results(result) values(throws_ok($q$select pg_temp.new_helpers_job('abcdefab-cdef-4abc-8abc-000000000002','["55555555-5555-4555-8555-555555555555","44444444-4444-4444-8444-444444444444"]','null')$q$,null,null,'Named helpers need a date'));
insert into pg_temp.eigsti_new_helpers_results(result) values(throws_ok($q$select pg_temp.new_helpers_job('abcdefab-cdef-4abc-8abc-000000000003','["77777777-7777-4777-8777-777777777777"]')$q$,null,null,'Ineligible helper rolls entire job back'));
insert into pg_temp.eigsti_new_helpers_results(result) values(throws_ok($q$select pg_temp.new_helpers_job('abcdefab-cdef-4abc-8abc-000000000004','["33333333-3333-4333-8333-333333333333"]')$q$,null,null,'Coordinating lead cannot also help'));
insert into pg_temp.eigsti_new_helpers_results(result) values(throws_ok($q$select pg_temp.new_helpers_job('abcdefab-cdef-4abc-8abc-000000000005','["55555555-5555-4555-8555-555555555555","55555555-5555-4555-8555-555555555555"]')$q$,null,null,'Duplicate helper rejected'));
reset role;
insert into pg_temp.eigsti_new_helpers_results(result) values(is((select count(*) from public.jobs where address='Fictional Crew Setup Lane'),1::bigint,'Failed setup and retries leave no partial or duplicate jobs'));
set local role authenticated;
insert into pg_temp.eigsti_new_helpers_results(result) values(lives_ok($q$select pg_temp.new_helpers_job('abcdefab-cdef-4abc-8abc-000000000006','[]','null')$q$,'Undated count-only work remains valid'));
insert into pg_temp.eigsti_new_helpers_results(result) values(lives_ok($q$select public.create_job_workspace('abcdefab-cdef-4abc-8abc-000000000007','SYNTHETIC Basics','3095550101','Fictional Basic Lane','{}','{}','null','[]','[]')$q$,'Minimal job setup still supported'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_new_helpers_results(result) values(throws_ok($q$select pg_temp.new_helpers_job('abcdefab-cdef-4abc-8abc-000000000008')$q$,'42501','PM account required','Lead cannot create job'));
reset role;
insert into pg_temp.eigsti_new_helpers_results(result) values(ok(not has_function_privilege('anon','public.create_job_workspace(uuid,text,text,text,jsonb,jsonb,jsonb,jsonb,jsonb)','execute'),'Anonymous workspace creation stays denied'));
do $validation$ begin if exists(select 1 from pg_temp.eigsti_new_helpers_results where result not like 'ok %') then raise exception 'New-job helper checks failed'; end if; end; $validation$;
select result from pg_temp.eigsti_new_helpers_results order by ordinal;
select * from finish();
rollback;
