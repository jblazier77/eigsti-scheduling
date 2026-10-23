-- Isolated test project only. Synthetic fixtures and every change roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_quick_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_quick_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_quick_results,pg_temp.eigsti_quick_ids to authenticated,anon;
grant usage on sequence pg_temp.eigsti_quick_results_ordinal_seq to authenticated,anon;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','quick-pm@example.invalid'),
('33333333-3333-4333-8333-333333333333','quick-lead@example.invalid'),
('44444444-4444-4444-8444-444444444444','quick-other@example.invalid'),
('55555555-5555-4555-8555-555555555555','quick-helper@example.invalid'),
('77777777-7777-4777-8777-777777777777','quick-admin@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC PM',array['pm'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Lead',array['lead'],true),
('44444444-4444-4444-8444-444444444444','SYNTHETIC Other lead',array['lead'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Helper',array['helper'],true),
('77777777-7777-4777-8777-777777777777','SYNTHETIC Admin',array['admin'],true);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,scope,access_notes,responsible_pm,created_by,updated_by) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Planning','3095550101','+13095550101','Fictional Lane','SYNTHETIC Planning','Keep scope','Keep access','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');

create function pg_temp.quick(r uuid,h integer default 1,m jsonb default '{"material_name":"Windows","material_status":"in_stock","material_expected_on":null}',n text default 'SYNTHETIC Window',p jsonb default '{"start_date":"2026-10-27","end_date":"2026-10-27","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333"}') returns jsonb language sql as $$
 select public.create_quick_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',r,jsonb_build_object('description',n,'responsible_lead','33333333-3333-4333-8333-333333333333'),p,h,m);
$$;
create function pg_temp.quick_visits() returns table(id uuid,work_item_id uuid,description text,required_helpers integer,slot text)
language sql as $$select * from jsonb_to_recordset(public.list_job_visits('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')) as v(id uuid,work_item_id uuid,description text,required_helpers integer,slot text);$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_quick_results(result) values(lives_ok($t$select pg_temp.quick('abcdefab-cdef-4abc-8abc-000000000031')$t$,'Window work, Tuesday, help and in-stock material save together'));
insert into pg_temp.eigsti_quick_ids select 'window',id from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC Window';
insert into pg_temp.eigsti_quick_results(result) values(is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC Window'),1::bigint,'One ordinary work item created'));
insert into pg_temp.eigsti_quick_results(result) values(is((select count(*) from pg_temp.quick_visits() where description='SYNTHETIC Window'),1::bigint,'One calendar entry created'));
insert into pg_temp.eigsti_quick_results(result) values(ok((select required_helpers=1 and slot='day' from pg_temp.quick_visits() where description='SYNTHETIC Window'),'Helper requirement has no mandatory time block'));
insert into pg_temp.eigsti_quick_results(result) values(ok((select default_helpers=1 and material_name='Windows' and material_status='in_stock' and readiness='ready' and completion='open' from public.work_items where id=(select id from pg_temp.eigsti_quick_ids where label='window')),'Help and material readiness saved without completion reporting'));
insert into pg_temp.eigsti_quick_results(result) values(lives_ok($t$select pg_temp.quick('abcdefab-cdef-4abc-8abc-000000000031')$t$,'Retry acknowledges the same whole save'));
insert into pg_temp.eigsti_quick_results(result) values(is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC Window'),1::bigint,'Retry does not duplicate work'));
insert into pg_temp.eigsti_quick_results(result) values(is((select count(*) from pg_temp.quick_visits() where description='SYNTHETIC Window'),1::bigint,'Retry does not duplicate its schedule'));
insert into pg_temp.eigsti_quick_results(result) values(throws_ok($t$select pg_temp.quick('abcdefab-cdef-4abc-8abc-000000000031',2)$t$,'23505','Request payload changed','Changed whole-save retry rejected'));
insert into pg_temp.eigsti_quick_results(result) values(lives_ok($t$select pg_temp.quick('abcdefab-cdef-4abc-8abc-000000000032',2,'{"material_name":"Windows","material_status":"ordered","material_expected_on":"2026-10-28"}','SYNTHETIC Undated help',null)$t$,'Help and materials may be recorded before scheduling'));
insert into pg_temp.eigsti_quick_results(result) values(is((select count(*) from pg_temp.quick_visits() where description='SYNTHETIC Undated help'),0::bigint,'Undated work reserves no crew or calendar date'));
insert into pg_temp.eigsti_quick_results(result) values(ok((select default_helpers=2 and material_status='ordered' and material_expected_on=date '2026-10-28' and readiness='waiting_date' from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC Undated help'),'Undated helper need and expected arrival persist'));
insert into pg_temp.eigsti_quick_results(result) values(lives_ok($t$select public.create_quick_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'{"description":"SYNTHETIC Unassigned","responsible_lead":null}',null,1,null)$t$,'Undated work may request help before a lead is assigned'));
insert into pg_temp.eigsti_quick_results(result) values(throws_ok($t$select pg_temp.quick(gen_random_uuid(),1,'{"material_name":"Windows","material_status":"invented","material_expected_on":null}','SYNTHETIC Failed material')$t$,'22023','Invalid material details','Invalid material rejects the whole transaction'));
insert into pg_temp.eigsti_quick_results(result) values(is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC Failed material'),0::bigint,'Failed materials leave no partial work item'));
insert into pg_temp.eigsti_quick_results(result) values(is((select count(*) from pg_temp.quick_visits() where description='SYNTHETIC Failed material'),0::bigint,'Failed materials leave no partial schedule'));
insert into pg_temp.eigsti_quick_results(result) values(throws_ok($t$select pg_temp.quick(gen_random_uuid(),21)$t$,'22023','Invalid helper count','Oversized helper request rejected'));
insert into pg_temp.eigsti_quick_results(result) values(throws_ok($t$select pg_temp.quick(gen_random_uuid(),1,null,'SYNTHETIC Wrong helpers','{"start_date":"2026-10-27","end_date":"2026-10-27","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":2}')$t$,'22023','Invalid helper count','Contradictory helper counts rejected'));
insert into pg_temp.eigsti_quick_results(result) values(throws_ok($t$select pg_temp.quick(gen_random_uuid(),1,null,'SYNTHETIC Weekend','{"start_date":"2026-10-24","end_date":"2026-10-24","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333"}')$t$,null,null,'Invalid dates reject all fields'));
insert into pg_temp.eigsti_quick_results(result) values(is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC Weekend'),0::bigint,'Invalid dates leave no work item'));
insert into pg_temp.eigsti_quick_results(result) values(lives_ok($t$select public.save_work_materials((select id from pg_temp.eigsti_quick_ids where label='window'),gen_random_uuid(),'{"material_name":"Windows","material_status":"ordered","material_expected_on":null}')$t$,'Subsequent material edits remain independent'));
insert into pg_temp.eigsti_quick_results(result) values(lives_ok($t$select pg_temp.quick('abcdefab-cdef-4abc-8abc-000000000031')$t$,'Original create retry still acknowledges after later edits'));
insert into pg_temp.eigsti_quick_results(result) values(is((select material_status from public.work_items where id=(select id from pg_temp.eigsti_quick_ids where label='window')),'ordered','Create retry never overwrites later material edits'));
insert into pg_temp.eigsti_quick_results(result) values(lives_ok($t$select pg_temp.quick(gen_random_uuid(),0,null,'SYNTHETIC Reserved','{"start_date":"2026-10-27","end_date":"2026-10-27","slot":"timed","start_time":"08:00","end_time":"09:00","coordinator_id":"33333333-3333-4333-8333-333333333333"}')$t$,'Optional time reservation remains supported'));
insert into pg_temp.eigsti_quick_results(result) values(throws_ok($t$select pg_temp.quick(gen_random_uuid(),0,null,'SYNTHETIC Conflict','{"start_date":"2026-10-27","end_date":"2026-10-27","slot":"timed","start_time":"08:30","end_time":"09:30","coordinator_id":"33333333-3333-4333-8333-333333333333"}')$t$,'23P01',null,'Staff conflict rejects the entire creation'));
insert into pg_temp.eigsti_quick_results(result) values(is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='SYNTHETIC Conflict'),0::bigint,'Conflicting plan leaves no orphan work'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_quick_results(result) values(throws_ok($t$select pg_temp.quick(gen_random_uuid())$t$,'42501','PM account required','Lead cannot forge quick creation'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_quick_results(result) values(throws_ok($t$select pg_temp.quick(gen_random_uuid())$t$,'42501','PM account required','Helper cannot forge quick creation'));
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_quick_results(result) values(throws_ok($t$select pg_temp.quick(gen_random_uuid())$t$,'42501','PM account required','Admin-only cannot forge quick creation'));
reset role;
insert into pg_temp.eigsti_quick_results(result) values(ok(not has_function_privilege('anon','public.create_quick_work(uuid,uuid,jsonb,jsonb,integer,jsonb)','EXECUTE'),'Anonymous creation is denied'));
insert into pg_temp.eigsti_quick_results(result) values(ok(not has_table_privilege('authenticated','public.work_items','UPDATE'),'New helper field does not expand direct write access'));
insert into pg_temp.eigsti_quick_results(result) values(is((select count(*) from private.work_material_events where work_id=(select id from pg_temp.eigsti_quick_ids where label='window')),2::bigint,'Retries do not duplicate material snapshots'));
insert into pg_temp.eigsti_quick_results(result) values(ok(exists(select 1 from private.command_requests where operation='create_quick_work' and request_id='abcdefab-cdef-4abc-8abc-000000000031'),'Whole-save receipt preserves retry payload'));
do $validation$
declare failures text;
begin
 select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_quick_results where result not like 'ok %';
 if failures is not null then raise exception 'Quick work checks failed: %',failures; end if;
end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_quick_results;
rollback;
