-- ISOLATED TEST PROJECT ONLY. Apply 0013 once after applied 0012.
-- 33 checks; synthetic fixtures roll back before commit. Never rerun older bundles.
begin;
do $preflight$
begin
 if to_regprocedure('public.create_job_work_with_plan(uuid,uuid,jsonb,jsonb)') is null or to_regprocedure('public.save_work_materials(uuid,uuid,jsonb)') is null then raise exception 'Quick-work batch requires applied 0012.'; end if;
 if to_regprocedure('public.create_quick_work(uuid,uuid,jsonb,jsonb,integer,jsonb)') is not null or exists(select 1 from information_schema.columns where table_schema='public' and table_name='work_items' and column_name='default_helpers') then raise exception '0013 may already be applied. Do not rerun; verify project state.'; end if;
end; $preflight$;
-- Apply once after applied 0012. Keep all quick-work details in one transaction.
alter table public.work_items add column default_helpers integer not null default 0 check(default_helpers between 0 and 20);
create function public.create_quick_work(p_job_id uuid,p_request_id uuid,p_values jsonb,p_plan jsonb,p_helpers integer,p_materials jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare vals jsonb; plan_values jsonb; payload jsonb; prior private.command_requests%rowtype; result jsonb; work_id uuid;
begin
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_job_id is null or p_request_id is null or p_helpers is null or p_helpers not between 0 and 20 then raise exception using errcode='22023',message='Invalid helper count'; end if;
 vals:=private.work_patch(p_values);
 if not(vals ?& array['description','responsible_lead']) then raise exception using errcode='22023',message='Incomplete work details'; end if;
 plan_values:=p_plan;
 if p_plan is not null then
  if jsonb_typeof(p_plan)<>'object' then raise exception using errcode='22023',message='Invalid visit'; end if;
  if p_plan ? 'required_helpers' and p_plan->'required_helpers' is distinct from to_jsonb(p_helpers) then raise exception using errcode='22023',message='Invalid helper count'; end if;
  plan_values:=p_plan||jsonb_build_object('required_helpers',p_helpers);
 end if;
 payload:=jsonb_build_object('job',p_job_id,'values',vals,'plan',plan_values,'helpers',p_helpers,'materials',p_materials);
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 perform id from public.jobs where id=p_job_id and lifecycle='open' for update;
 if not found then raise exception using errcode='P0002',message='Open job required'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='create_quick_work' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 result:=public.create_job_work_with_plan(p_job_id,p_request_id,vals,plan_values);work_id:=(result->>'id')::uuid;
 update public.work_items set default_helpers=p_helpers,updated_at=clock_timestamp(),updated_by=auth.uid() where id=work_id;
 if p_materials is not null then perform public.save_work_materials(work_id,p_request_id,p_materials); end if;
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
 values(p_job_id,auth.uid(),'create_quick_work',array['work:'||work_id::text,'default_helpers','schedule','materials'],p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id)
 values(auth.uid(),'create_quick_work',p_request_id,payload,work_id);
 return result;
end; $$;
revoke all on function public.create_quick_work(uuid,uuid,jsonb,jsonb,integer,jsonb) from public,anon,authenticated;
grant execute on function public.create_quick_work(uuid,uuid,jsonb,jsonb,integer,jsonb) to authenticated;
notify pgrst,'reload schema';

savepoint quick_work_fixture_checks;
-- Isolated test project only. Synthetic fixtures and every change roll back.
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

rollback to savepoint quick_work_fixture_checks;
release savepoint quick_work_fixture_checks;
commit;
select 33::integer as checks,0::integer as failed,'0013 applied; synthetic fixtures removed'::text as result;
