-- Isolated test project only, after 0001-0010. All fictional fixtures roll back.
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
rollback;
