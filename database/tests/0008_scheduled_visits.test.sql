-- Isolated test project only, after 0001-0008. All fictional fixtures roll back.
begin;
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
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$insert into pg_temp.eigsti_test_visits values('day1',public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,'abcdefab-cdef-4abc-8abc-000000000001','{"start_date":"2026-10-26","end_date":"2026-10-26","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":2}'))$t$,'Owner lead plans dates without a time'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$insert into pg_temp.eigsti_test_visits values('day2',public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,'abcdefab-cdef-4abc-8abc-000000000002','{"start_date":"2026-10-26","end_date":"2026-10-26","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333"}'))$t$,'Several untimed visits may share a day'));
insert into pg_temp.eigsti_visit_results(result) values(is((select jsonb_array_length(public.list_schedule('2026-10-26','2026-10-26'))),2::integer,'Both date-only visits appear on own schedule'));
insert into pg_temp.eigsti_visit_results(result) values(ok((select (public.get_visit((value->>'id')::uuid)->>'day_conflicts')::integer>0 from pg_temp.eigsti_test_visits where label='day1'),'Untimed shared-day plans warn without blocking'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.list_schedule('2026-10-26','2026-10-26',true)$t$,'42501','PM required','Lead cannot enumerate all schedules'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',null,gen_random_uuid(),'{"start_date":"2026-10-27","end_date":"2026-10-27","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333"}')$t$,'42501','Visit coordinator required','Lead cannot plan unrelated work'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,gen_random_uuid(),'{"start_date":"2026-10-27","end_date":"2026-10-27","slot":"day","coordinator_id":"44444444-4444-4444-8444-444444444444"}')$t$,'42501','PM required to change coordinator','Lead cannot assign another coordinating lead'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select * from public.visits$t$,'42501',null,'Raw visit reads denied'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select * from public.visit_participants$t$,'42501',null,'Raw staffing reads denied'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select private.rebuild_visit((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='day1'))$t$,'42501',null,'Private booking writer denied'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,gen_random_uuid(),'{"start_date":"2026-10-24","end_date":"2026-10-24","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333"}')$t$,'23514',null,'Weekend boundary rejected'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,gen_random_uuid(),'{"start_date":"2026-10-26","end_date":"2026-12-01","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333"}')$t$,'23514',null,'Date range bounded'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,gen_random_uuid(),'{"start_date":"2026-10-26","end_date":"2026-10-26","slot":"timed","coordinator_id":"33333333-3333-4333-8333-333333333333","start_time":"06:30","end_time":"09:00"}')$t$,'23514',null,'Times outside working calendar rejected'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$insert into pg_temp.eigsti_test_visits values('timed1',public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,'abcdefab-cdef-4abc-8abc-000000000003','{"start_date":"2026-11-02","end_date":"2026-11-02","slot":"timed","start_time":"07:00","end_time":"10:00","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":2}'))$t$,'Timed visit created'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$insert into pg_temp.eigsti_test_visits values('adjacent',public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,'abcdefab-cdef-4abc-8abc-000000000004','{"start_date":"2026-11-02","end_date":"2026-11-02","slot":"timed","start_time":"10:00","end_time":"12:00","coordinator_id":"33333333-3333-4333-8333-333333333333"}'))$t$,'Adjoining timed intervals do not conflict'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,gen_random_uuid(),'{"start_date":"2026-11-02","end_date":"2026-11-02","slot":"morning","coordinator_id":"33333333-3333-4333-8333-333333333333"}')$t$,'23P01','Staff scheduling conflict','Morning overlaps a timed reservation'));
reset role;
insert into pg_temp.eigsti_visit_results(result) values(is((select count(*) from public.visits),4::bigint,'Failed overlap and validation leave no visits behind'));
insert into pg_temp.eigsti_visit_results(result) values(is((select min(starts_at) from private.visit_bookings where visit_id=(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1')),'2026-11-02 13:00:00+00'::timestamptz,'Winter Central time converted to UTC correctly'));
insert into pg_temp.eigsti_visit_results(result) values(is((select count(*) from private.visit_bookings where visit_id in(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label in('day1','day2'))),0::bigint,'Untimed plans have no invented hourly reservation'));
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.staff_visit((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'),'abcdefab-cdef-4abc-8abc-000000000005',array['55555555-5555-4555-8555-555555555555']::uuid[])$t$,'PM assigns named helper'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$insert into pg_temp.eigsti_test_visits values('other',public.save_visit('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',null,'abcdefab-cdef-4abc-8abc-000000000006','{"start_date":"2026-11-02","end_date":"2026-11-02","slot":"morning","coordinator_id":"44444444-4444-4444-8444-444444444444","required_helpers":1}'))$t$,'PM plans another PM job'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.staff_visit((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='other'),gen_random_uuid(),array['55555555-5555-4555-8555-555555555555']::uuid[])$t$,'23P01','Staff scheduling conflict','Booked helper cannot be taken by another visit'));
insert into pg_temp.eigsti_visit_results(result) values(ok((select jsonb_array_length(public.get_visit((value->>'id')::uuid)->'participants')=1 from pg_temp.eigsti_test_visits where label='other'),'Failed staffing preserves destination roster'));
insert into pg_temp.eigsti_visit_results(result) values(ok((select (p->>'busy')::boolean from jsonb_array_elements(public.visit_staff_options((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='other'))) p where p->>'id'='55555555-5555-4555-8555-555555555555'),'Availability exposes busy flag'));
insert into pg_temp.eigsti_visit_results(result) values(ok((select bool_and(not(p ? 'job_title') and not(p ? 'address')) from jsonb_array_elements(public.visit_staff_options((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='other'))) p),'Availability hides unrelated customer context'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.staff_visit((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'),gen_random_uuid(),array[]::uuid[])$t$,'42501','PM required to replace named help','Lead cannot remove PM assigned helper'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.staff_visit((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'),'abcdefab-cdef-4abc-8abc-000000000007',array['55555555-5555-4555-8555-555555555555','66666666-6666-4666-8666-666666666666']::uuid[])$t$,'Lead may fill a vacant help space'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.staff_visit((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'),gen_random_uuid(),array['55555555-5555-4555-8555-555555555555','66666666-6666-4666-8666-666666666666','44444444-4444-4444-8444-444444444444']::uuid[])$t$,'22023','Invalid staffing','Cannot overfill helper spaces'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'),gen_random_uuid(),'{"required_helpers":1}')$t$,'22023','Named help exceeds need','Cannot hide existing named help by reducing need'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_visit_results(result) values(is((select jsonb_array_length(public.list_schedule('2026-11-02','2026-11-02'))),1::integer,'Helper sees only personal assignments'));
insert into pg_temp.eigsti_visit_results(result) values(ok(private.can_read_job('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Named helper receives shared job access'));
insert into pg_temp.eigsti_visit_results(result) values(ok(not private.can_read_job('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),'Busy helper gains no destination job access'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.staff_visit((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'),gen_random_uuid(),array[]::uuid[])$t$,'42501','Visit planning required','Helper cannot mutate staffing'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.visit_staff_options((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'))$t$,'42501','Visit coordinator required','Helper cannot enumerate available staff'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.staff_visit((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'),'abcdefab-cdef-4abc-8abc-000000000008',array['66666666-6666-4666-8666-666666666666']::uuid[])$t$,'PM may explicitly replace/remove named staffing'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.staff_visit((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'),'abcdefab-cdef-4abc-8abc-000000000005',array['55555555-5555-4555-8555-555555555555']::uuid[])$t$,'Old identical retry acknowledged without reapplying'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_visit_results(result) values(ok(not private.can_read_job('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Removal revokes helper entitlement; old retry cannot restore it'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.staff_visit((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'),'abcdefab-cdef-4abc-8abc-000000000005',array[]::uuid[])$t$,'23505','Request payload changed','Changed retry payload rejected'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'),'abcdefab-cdef-4abc-8abc-000000000009','{"certainty":"confirmed"}')$t$,'Narrow certainty save succeeds'));
insert into pg_temp.eigsti_visit_results(result) values(is((select public.get_visit((value->>'id')::uuid)->>'start_date' from pg_temp.eigsti_test_visits where label='timed1'),'2026-11-02','Narrow save retains dates'));
insert into pg_temp.eigsti_visit_results(result) values(is((select jsonb_array_length(public.get_visit((value->>'id')::uuid)->'participants') from pg_temp.eigsti_test_visits where label='timed1'),2::integer,'Narrow save retains named staff'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'),gen_random_uuid(),'{"start_time":"10:00","end_time":"12:00"}')$t$,'23P01','Staff scheduling conflict','Conflicting reschedule rolls back entire crew move'));
insert into pg_temp.eigsti_visit_results(result) values(is((select public.get_visit((value->>'id')::uuid)->>'start_time' from pg_temp.eigsti_test_visits where label='timed1'),'07:00:00','Failed reschedule retains original time'));
insert into pg_temp.eigsti_visit_results(result) values(is((select jsonb_array_length(public.list_schedule('2026-11-02','2026-11-02',false))),2::integer,'PM defaults to own jobs'));
insert into pg_temp.eigsti_visit_results(result) values(is((select jsonb_array_length(public.list_schedule('2026-11-02','2026-11-02',true))),3::integer,'PM may switch to all jobs'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'),gen_random_uuid(),'{"certainty":"tentative"}')$t$,'P0002','Visit unavailable','Forged visit/work relationship rejected'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,gen_random_uuid(),'{"start_date":"2026-11-03","end_date":"2026-11-03","slot":"day","coordinator_id":"88888888-8888-4888-8888-888888888888"}')$t$,'22023','Active staff required','Inactive coordinator rejected'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$insert into pg_temp.eigsti_test_visits values('helping-lead',public.save_visit('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',null,'abcdefab-cdef-4abc-8abc-000000000012','{"start_date":"2026-11-03","end_date":"2026-11-03","slot":"morning","coordinator_id":"44444444-4444-4444-8444-444444444444","required_helpers":1}'))$t$,'Separate coordinating lead plans next-day visit'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.staff_visit((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='helping-lead'),'abcdefab-cdef-4abc-8abc-000000000013',array['33333333-3333-4333-8333-333333333333']::uuid[])$t$,'A lead may help on another lead visit'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_visit_results(result) values(is((select public.list_schedule('2026-11-03','2026-11-03')->0->'participants' @> '[{"id":"33333333-3333-4333-8333-333333333333","duty":"helping"}]'::jsonb),true,'Personal schedule includes Helping duty'));
insert into pg_temp.eigsti_visit_results(result) values(ok(private.has_role('lead'),'Helping does not change lead account permissions'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$insert into pg_temp.eigsti_test_visits values('multi',public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,'abcdefab-cdef-4abc-8abc-000000000010','{"start_date":"2026-11-06","end_date":"2026-11-09","slot":"all_day","coordinator_id":"33333333-3333-4333-8333-333333333333"}'))$t$,'Multi-day explicit reservation crosses weekend'));
reset role;
insert into pg_temp.eigsti_visit_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='multi')),2::bigint,'Only Friday and Monday reserved'));
insert into pg_temp.eigsti_visit_results(result) values(ok((select bool_and(snapshot ? 'participants') from private.visit_events),'History retains final visit and roster snapshots'));
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1'),'abcdefab-cdef-4abc-8abc-000000000011','{"state":"cancelled"}')$t$,'Cancel releases entire named visit atomically'));
select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
insert into pg_temp.eigsti_visit_results(result) values(ok(not private.can_read_job('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Cancel revokes final named access'));
reset role;
insert into pg_temp.eigsti_visit_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='timed1')),0::bigint,'Cancelled visit leaves no reservations'));
set local role authenticated;
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.list_schedule('2026-10-26','2026-10-26')$t$,'42501','Schedule access required','Admin-only has no operational schedule access'));
select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.list_schedule('2026-10-26','2026-10-26')$t$,'42501','Schedule access required','Inactive session denied'));
reset role;
set local role anon;
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.list_schedule('2026-10-26','2026-10-26')$t$,'42501',null,'Anonymous schedule denied'));
reset role;
do $validation$
declare failures text;
begin
 if (select count(*) from pg_temp.eigsti_visit_results)<>60 then raise exception 'Incomplete visit checks: expected 60'; end if;
 select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_visit_results where result not like 'ok %';
 if failures is not null then raise exception 'Visit checks failed: %',failures; end if;
end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_visit_results;
rollback;
