-- Isolated test project only. Synthetic fixtures and every change roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_unassigned_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_unassigned_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_unassigned_results,pg_temp.eigsti_unassigned_ids to authenticated,anon;
grant usage on sequence pg_temp.eigsti_unassigned_results_ordinal_seq to authenticated,anon;
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
create function pg_temp.unassigned_job(r uuid) returns jsonb language sql as $helper$
 select public.create_job_workspace(r,'SYNTHETIC Unassigned crew','3095550101','Fictional Unassigned Lane','{}','{}','null',jsonb_build_array(jsonb_build_object('values',jsonb_build_object('description','SYNTHETIC Install window','responsible_lead',null),'helpers',2,'plan',jsonb_build_object('start_date','2099-01-05','end_date','2099-01-05','slot','day','coordinator_id',null,'required_helpers',2,'certainty','tentative'),'materials',null,'days',0.5,'named_helpers',jsonb_build_array('55555555-5555-4555-8555-555555555555','44444444-4444-4444-8444-444444444444'))),'[]');
$helper$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_unassigned_results(result) values(lives_ok($q$select pg_temp.unassigned_job('abcdefab-cdef-4abc-8abc-000000000001')$q$,'Create full new job with date helpers and no lead'));
insert into pg_temp.eigsti_unassigned_ids values('job',(pg_temp.unassigned_job('abcdefab-cdef-4abc-8abc-000000000001')->>'id')::uuid);
reset role;
insert into pg_temp.eigsti_unassigned_ids select 'work',id from public.work_items where job_id=(select id from pg_temp.eigsti_unassigned_ids where label='job');
insert into pg_temp.eigsti_unassigned_ids select 'visit',id from public.visits where work_item_id=(select id from pg_temp.eigsti_unassigned_ids where label='work');
insert into pg_temp.eigsti_unassigned_results(result) values(ok((select coordinator_id is null and start_date='2099-01-05' and required_helpers=2 from public.visits where id=(select id from pg_temp.eigsti_unassigned_ids where label='visit')),'Date and spaces preserved with no lead'));
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from public.visit_participants where visit_id=(select id from pg_temp.eigsti_unassigned_ids where label='visit') and duty='helping'),2::bigint,'Both helpers remain assigned'));
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from public.visit_participants where visit_id=(select id from pg_temp.eigsti_unassigned_ids where label='visit') and duty='leading'),0::bigint,'No fake lead participant'));
insert into pg_temp.eigsti_unassigned_results(result) values(ok((select responsible_lead is null and estimated_days=0.5 from public.work_items where id=(select id from pg_temp.eigsti_unassigned_ids where label='work')),'Task ownership stays unassigned'));
set local role authenticated;
insert into pg_temp.eigsti_unassigned_results(result) values(lives_ok($q$select pg_temp.unassigned_job('abcdefab-cdef-4abc-8abc-000000000001')$q$,'Same creation retry safe'));
insert into pg_temp.eigsti_unassigned_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.list_schedule('2099-01-05','2099-01-05',false)) x where x->>'id'=(select id from pg_temp.eigsti_unassigned_ids where label='visit')::text and x->'coordinator_id'='null'::jsonb),'PM sees unassigned scheduled work'));
insert into pg_temp.eigsti_unassigned_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.visit_staff_options((select id from pg_temp.eigsti_unassigned_ids where label='visit'))) x where x->>'id'='33333333-3333-4333-8333-333333333333'),'PM can select lead as helper when coordinator is empty'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_unassigned_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.list_schedule('2099-01-05','2099-01-05',false)) x where x->>'id'=(select id from pg_temp.eigsti_unassigned_ids where label='visit')::text),'Assigned helper sees scheduled work'));
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.staff_visit((select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000002',array[]::uuid[])$q$,'42501','Visit planning required','Helper cannot change staffing'));
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.work_progress_command((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),null,'abcdefab-cdef-4abc-8abc-000000000021','finish_visit','{}')$q$,'42501','Visit coordinator required','Legacy command cannot bypass unassigned lead permissions'));
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.save_visit((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000003','{"required_helpers":3}')$q$,'42501','Visit coordinator required','Helping lead cannot edit unassigned dates'));
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.staff_visit((select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000004',array[]::uuid[])$q$,'42501','Visit coordinator required','Null coordinator never grants staffing authority'));
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.save_visit_card((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000005','{}',array[]::uuid[])$q$,'42501','Visit coordinator required','Null coordinator never grants card authority'));
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.visit_staff_options((select id from pg_temp.eigsti_unassigned_ids where label='visit'))$q$,'42501','Visit coordinator required','Null coordinator never grants directory authority'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_unassigned_results(result) values(lives_ok($q$select public.save_visit((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000006','{"slot":"morning"}')$q$,'Unassigned timed crew reservation supported'));
reset role;
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select id from pg_temp.eigsti_unassigned_ids where label='visit')),2::bigint,'Only real named helpers are reserved'));
set local role authenticated;
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.create_staffed_work((select id from pg_temp.eigsti_unassigned_ids where label='job'),'abcdefab-cdef-4abc-8abc-000000000020','{"description":"SYNTHETIC Conflict","responsible_lead":null}','{"start_date":"2099-01-05","end_date":"2099-01-05","slot":"morning","coordinator_id":null,"required_helpers":1,"certainty":"tentative"}',1,null,null,'["55555555-5555-4555-8555-555555555555"]')$q$,'23P01','Staff scheduling conflict','Unassigned lead does not bypass helper time conflicts'));
reset role;
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from public.work_items where job_id=(select id from pg_temp.eigsti_unassigned_ids where label='job')),1::bigint,'Conflict rolls back new work'));
set local role authenticated;
insert into pg_temp.eigsti_unassigned_results(result) values(lives_ok($q$select public.save_work_setup_with_help((select id from pg_temp.eigsti_unassigned_ids where label='work'),'abcdefab-cdef-4abc-8abc-000000000007','{"responsible_lead":"33333333-3333-4333-8333-333333333333"}',null,null,jsonb_build_array(jsonb_build_object('id',(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'cancel',false,'patch',jsonb_build_object('coordinator_id','33333333-3333-4333-8333-333333333333'),'helpers',null)),null)$q$,'Assign lead later with same work and date'));
reset role;
insert into pg_temp.eigsti_unassigned_results(result) values(ok((select coordinator_id='33333333-3333-4333-8333-333333333333' from public.visits where id=(select id from pg_temp.eigsti_unassigned_ids where label='visit')),'Date now has chosen lead'));
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from public.visit_participants where visit_id=(select id from pg_temp.eigsti_unassigned_ids where label='visit') and duty='helping'),2::bigint,'Assigning lead keeps helpers'));
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select id from pg_temp.eigsti_unassigned_ids where label='visit')),3::bigint,'Lead added to explicit reservation'));
set local role authenticated;
insert into pg_temp.eigsti_unassigned_results(result) values(lives_ok($q$select public.save_visit((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000008','{"coordinator_id":null}')$q$,'PM can clear lead without losing planned work'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.save_visit((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000009','{"coordinator_id":"33333333-3333-4333-8333-333333333333"}')$q$,'42501','Visit coordinator required','Responsible lead cannot claim an unassigned scheduled entry'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_unassigned_results(result) values(lives_ok($q$select public.save_visit((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000010','{"state":"cancelled"}')$q$,'PM can remove unassigned scheduled date'));
reset role;
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select id from pg_temp.eigsti_unassigned_ids where label='visit')),0::bigint,'Cancellation clears actual reservations'));
insert into pg_temp.eigsti_unassigned_results(result) values(ok(not has_table_privilege('authenticated','public.visits','INSERT'),'No direct schedule writes added'));
do $validation$ begin if exists(select 1 from pg_temp.eigsti_unassigned_results where result not like 'ok %') then raise exception 'Unassigned work checks failed'; end if; end; $validation$;
select result from pg_temp.eigsti_unassigned_results order by ordinal;
select * from finish();
rollback;
