-- Isolated test project only, after 0001-0009. All fictional fixtures roll back.
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
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_test_visits values('a',public.save_visit('dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,'abcdefab-cdef-4abc-8abc-000000000001','{"start_date":"2026-10-26","end_date":"2026-10-26","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333"}'));
insert into pg_temp.eigsti_test_visits values('b',public.save_visit('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',null,'abcdefab-cdef-4abc-8abc-000000000002','{"start_date":"2026-11-03","end_date":"2026-11-03","slot":"timed","start_time":"07:00","end_time":"10:00","coordinator_id":"44444444-4444-4444-8444-444444444444","required_helpers":1}'));
select public.staff_visit((select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='b'),'abcdefab-cdef-4abc-8abc-000000000003',array['55555555-5555-4555-8555-555555555555']::uuid[]);
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),'abcdefab-cdef-4abc-8abc-000000000004','{"start_date":"2026-11-02","end_date":"2026-11-02","slot":"timed","start_time":"07:00","end_time":"10:00","required_helpers":1}',array['55555555-5555-4555-8555-555555555555']::uuid[])$t$,'One card save changes dates, need and roster'));
insert into pg_temp.eigsti_visit_results(result) values(is((select public.get_visit((value->>'id')::uuid)->>'start_date' from pg_temp.eigsti_test_visits where label='a'),'2026-11-02','Combined dates saved'));
insert into pg_temp.eigsti_visit_results(result) values(is((select (public.get_visit((value->>'id')::uuid)->>'required_helpers')::integer from pg_temp.eigsti_test_visits where label='a'),1::integer,'Helper need saved'));
insert into pg_temp.eigsti_visit_results(result) values(ok((select public.get_visit((value->>'id')::uuid)->'participants' @> '[{"id":"55555555-5555-4555-8555-555555555555","duty":"helping"}]'::jsonb from pg_temp.eigsti_test_visits where label='a'),'Named helper saved'));
reset role;
create temporary table card_snapshot as select (select count(*) from private.visit_events) as events,(select count(*) from private.command_requests) as receipts,(select count(*) from private.visit_bookings) as bookings;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),'abcdefab-cdef-4abc-8abc-000000000005','{"start_date":"2026-11-03","end_date":"2026-11-03","required_helpers":2}',array['55555555-5555-4555-8555-555555555555','66666666-6666-4666-8666-666666666666']::uuid[])$t$,'23P01','Staff scheduling conflict','Late helper conflict rolls back complete card'));
insert into pg_temp.eigsti_visit_results(result) values(is((select public.get_visit((value->>'id')::uuid)->>'start_date' from pg_temp.eigsti_test_visits where label='a'),'2026-11-02','Conflict retained old date'));
insert into pg_temp.eigsti_visit_results(result) values(is((select (public.get_visit((value->>'id')::uuid)->>'required_helpers')::integer from pg_temp.eigsti_test_visits where label='a'),1::integer,'Conflict retained old need'));
insert into pg_temp.eigsti_visit_results(result) values(is((select jsonb_array_length(public.get_visit((value->>'id')::uuid)->'participants') from pg_temp.eigsti_test_visits where label='a'),2::integer,'Conflict retained old roster'));
reset role;
insert into pg_temp.eigsti_visit_results(result) values(is((select count(*) from private.visit_events),(select events from pg_temp.card_snapshot),'Failed card leaves history unchanged'));
insert into pg_temp.eigsti_visit_results(result) values(is((select count(*) from private.command_requests),(select receipts from pg_temp.card_snapshot),'Failed card leaves receipts unchanged'));
insert into pg_temp.eigsti_visit_results(result) values(is((select count(*) from private.visit_bookings),(select bookings from pg_temp.card_snapshot),'Failed card leaves reservations unchanged'));
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),'abcdefab-cdef-4abc-8abc-000000000006','{"start_date":"2026-11-03","end_date":"2026-11-03"}',array['66666666-6666-4666-8666-666666666666']::uuid[])$t$,'PM moves visit with replacement helper; removed helper busy time does not block'));
insert into pg_temp.eigsti_visit_results(result) values(is((select public.get_visit((value->>'id')::uuid)->>'start_date' from pg_temp.eigsti_test_visits where label='a'),'2026-11-03','Replacement crew moved together'));
insert into pg_temp.eigsti_visit_results(result) values(ok((select public.get_visit((value->>'id')::uuid)->'participants' @> '[{"id":"66666666-6666-4666-8666-666666666666","duty":"helping"}]'::jsonb from pg_temp.eigsti_test_visits where label='a'),'Replacement roster saved'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),gen_random_uuid(),'{"required_helpers":0}',array[]::uuid[])$t$,'42501','PM required to replace named help','Lead cannot bypass roster protection with combined need change'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),'abcdefab-cdef-4abc-8abc-000000000007','{"slot":"day","required_helpers":2}',array['55555555-5555-4555-8555-555555555555','66666666-6666-4666-8666-666666666666']::uuid[])$t$,'Lead can fill new helper need in same save; date-only plan permits shared day'));
insert into pg_temp.eigsti_visit_results(result) values(is((select jsonb_array_length(public.get_visit((value->>'id')::uuid)->'participants') from pg_temp.eigsti_test_visits where label='a'),3::integer,'Both named helpers retained'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),'abcdefab-cdef-4abc-8abc-000000000008','{"required_helpers":1}',array['55555555-5555-4555-8555-555555555555']::uuid[])$t$,'PM reduces need and removes one name in same save'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),'abcdefab-cdef-4abc-8abc-000000000007','{"slot":"day","required_helpers":2}',array['66666666-6666-4666-8666-666666666666','55555555-5555-4555-8555-555555555555']::uuid[])$t$,'Canonical old request retry acknowledged'));
insert into pg_temp.eigsti_visit_results(result) values(is((select (public.get_visit((value->>'id')::uuid)->>'required_helpers')::integer from pg_temp.eigsti_test_visits where label='a'),1::integer,'Old retry never restores old need'));
insert into pg_temp.eigsti_visit_results(result) values(is((select jsonb_array_length(public.get_visit((value->>'id')::uuid)->'participants') from pg_temp.eigsti_test_visits where label='a'),2::integer,'Old retry never restores removed helper'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),'abcdefab-cdef-4abc-8abc-000000000007','{"slot":"day","required_helpers":3}',array['55555555-5555-4555-8555-555555555555','66666666-6666-4666-8666-666666666666']::uuid[])$t$,'23505','Request payload changed','Changed old payload rejected'));
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),'abcdefab-cdef-4abc-8abc-000000000009','{"certainty":"confirmed"}',null)$t$,'Fields-only save omits roster'));
insert into pg_temp.eigsti_visit_results(result) values(is((select jsonb_array_length(public.get_visit((value->>'id')::uuid)->'participants') from pg_temp.eigsti_test_visits where label='a'),2::integer,'Omitted roster preserves latest names'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_visit_results(result) values(lives_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),'abcdefab-cdef-4abc-8abc-000000000010','{}',array[]::uuid[])$t$,'Staffing-only save omits fields'));
insert into pg_temp.eigsti_visit_results(result) values(is((select public.get_visit((value->>'id')::uuid)->>'certainty' from pg_temp.eigsti_test_visits where label='a'),'confirmed','Roster-only save preserves independent plan edit'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit_card('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),gen_random_uuid(),'{"certainty":"tentative"}',null)$t$,'P0002','Visit unavailable','Forged work/visit relationship denied'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),gen_random_uuid(),'{"state":"cancelled"}',null)$t$,'22023','Invalid visit field','Card cannot smuggle a lifecycle command'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),gen_random_uuid(),'{}',array['55555555-5555-4555-8555-555555555555','55555555-5555-4555-8555-555555555555']::uuid[])$t$,'22023','Invalid staffing','Duplicate staffing rejected'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_visit_results(result) values(ok(not private.can_read_job('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Roster removal revokes that job access'));
insert into pg_temp.eigsti_visit_results(result) values(ok(private.can_read_job('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),'Independent job assignment remains accessible'));
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),gen_random_uuid(),'{"certainty":"tentative"}',null)$t$,'42501','Visit planning required','Helpers cannot save visit cards'));
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),gen_random_uuid(),'{"certainty":"tentative"}',null)$t$,'42501','Visit coordinator required','Unrelated lead cannot save card'));
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),gen_random_uuid(),'{"certainty":"tentative"}',null)$t$,'42501','Visit planning required','Admin-only cannot save card'));
select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd',(select (value->>'id')::uuid from pg_temp.eigsti_test_visits where label='a'),gen_random_uuid(),'{"certainty":"tentative"}',null)$t$,'42501','Visit planning required','Inactive lead cannot save card'));
reset role;
insert into pg_temp.eigsti_visit_results(result) values(ok((select snapshot->'participants' @> '[{"id":"33333333-3333-4333-8333-333333333333","duty":"leading"}]'::jsonb from private.visit_events where operation='save_visit_card' and request_id='abcdefab-cdef-4abc-8abc-000000000010'),'Card audit records final roster'));
insert into pg_temp.eigsti_visit_results(result) values(is((select count(*) from private.command_requests where operation='save_visit_card' and request_id='abcdefab-cdef-4abc-8abc-000000000007'),1::bigint,'Canonical retries create only one outer receipt'));
set local role anon;
insert into pg_temp.eigsti_visit_results(result) values(throws_ok($t$select public.save_visit_card('dddddddd-dddd-4ddd-8ddd-dddddddddddd','ffffffff-ffff-4fff-8fff-ffffffffffff',gen_random_uuid(),'{"certainty":"tentative"}',null)$t$,'42501',null,'Anonymous card save denied'));
reset role;
do $validation$
declare failures text;
begin
 if (select count(*) from pg_temp.eigsti_visit_results)<>38 then raise exception 'Incomplete visit card checks: expected 38'; end if;
 select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_visit_results where result not like 'ok %';
 if failures is not null then raise exception 'Visit card checks failed: %',failures; end if;
end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_visit_results;
rollback;
