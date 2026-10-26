-- Apply ONCE after applied 0018. All fictional fixtures roll back before commit.
begin;
do $preflight$ begin
 if to_regprocedure('public.save_work_setup(uuid,uuid,jsonb,jsonb,jsonb,jsonb)') is null then raise exception 'First-save helpers require applied 0018.'; end if;
 if to_regprocedure('public.planning_staff(uuid)') is not null then raise exception '0019 may already be applied. Do not rerun; verify state.'; end if;
end; $preflight$;
-- Apply once after 0018. Select named help before the first dated save.
create function public.planning_staff(p_job_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not(private.has_role('pm') or (p_job_id is not null and private.has_role('lead') and private.can_read_job(p_job_id))) then raise exception using errcode='42501',message='Work planner required'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.display_name,'busy',false) order by u.display_name,u.id) from public.app_users u where u.active and u.roles && array['lead','helper']::text[]),'[]'::jsonb);
end; $$;
create function private.planning_helpers(p_helpers jsonb) returns uuid[] language plpgsql immutable set search_path='' as $$
declare result uuid[];
begin
 if p_helpers is null or p_helpers='null'::jsonb then return null; end if;
 if jsonb_typeof(p_helpers)<>'array' or jsonb_array_length(p_helpers)>20 then raise exception using errcode='22023',message='Invalid staffing'; end if;
 if exists(select 1 from jsonb_array_elements(p_helpers) x where jsonb_typeof(x)<>'string' or (x#>>'{}')!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then raise exception using errcode='22023',message='Invalid staffing'; end if;
 select coalesce(array_agg(x::uuid order by x::uuid),'{}'::uuid[]) into result from jsonb_array_elements_text(p_helpers) x;
 if cardinality(result)<>(select count(distinct x) from unnest(result) x) then raise exception using errcode='22023',message='Invalid staffing'; end if;
 return result;
end; $$;
revoke all on function private.planning_helpers(jsonb) from public,anon,authenticated;
create function public.save_work_setup_with_help(p_work_id uuid,p_request_id uuid,p_patch jsonb,p_materials jsonb,p_plan jsonb,p_visits jsonb,p_new_helpers jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare roster uuid[]; payload jsonb; prior private.command_requests%rowtype; result jsonb; new_visit uuid; job_id uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not(private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Work planner required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 select w.job_id into job_id from public.work_items w where w.id=p_work_id;
 if job_id is null or not private.can_read_job(job_id) then raise exception using errcode='42501',message='Job access required'; end if;
 p_plan:=nullif(p_plan,'null'::jsonb);p_materials:=nullif(p_materials,'null'::jsonb);roster:=private.planning_helpers(p_new_helpers);
 if cardinality(roster)>0 and p_plan is null then raise exception using errcode='22023',message='Choose a date to assign named help'; end if;
 payload:=jsonb_build_object('work',p_work_id,'patch',p_patch,'materials',p_materials,'plan',p_plan,'visits',p_visits,'helpers',to_jsonb(roster));
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='save_work_setup_with_help' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',p_work_id,'job_id',job_id);
 end if;
 if exists(select 1 from private.command_requests where actor_id=auth.uid() and operation='save_work_setup' and request_id=p_request_id) then raise exception using errcode='23505',message='Request payload changed'; end if;
 result:=public.save_work_setup(p_work_id,p_request_id,p_patch,p_materials,p_plan,p_visits);
 if p_plan is not null and roster is not null then
  select result_id into new_visit from private.command_requests where actor_id=auth.uid() and operation='save_visit' and request_id=p_request_id;
  if new_visit is null then raise exception using errcode='P0002',message='Visit unavailable'; end if;
  perform public.staff_visit(new_visit,gen_random_uuid(),roster);
 end if;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'save_work_setup_with_help',p_request_id,payload,p_work_id);
 return result;
end; $$;
create function public.create_staffed_work(p_job_id uuid,p_request_id uuid,p_values jsonb,p_plan jsonb,p_helpers integer,p_materials jsonb,p_days jsonb,p_named_helpers jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare roster uuid[]; payload jsonb; prior private.command_requests%rowtype; result jsonb; new_visit uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 p_plan:=nullif(p_plan,'null'::jsonb);p_materials:=nullif(p_materials,'null'::jsonb);roster:=private.planning_helpers(p_named_helpers);
 if cardinality(roster)>0 and p_plan is null then raise exception using errcode='22023',message='Choose a date to assign named help'; end if;
 payload:=jsonb_build_object('job',p_job_id,'values',p_values,'plan',p_plan,'helpers',p_helpers,'materials',p_materials,'days',p_days,'named',to_jsonb(roster));
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='create_staffed_work' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 if exists(select 1 from private.command_requests where actor_id=auth.uid() and operation='create_planning_work' and request_id=p_request_id) then raise exception using errcode='23505',message='Request payload changed'; end if;
 result:=public.create_planning_work(p_job_id,p_request_id,p_values,p_plan,p_helpers,p_materials,p_days);
 if p_plan is not null and roster is not null then
  select result_id into new_visit from private.command_requests where actor_id=auth.uid() and operation='save_visit' and request_id=p_request_id;
  if new_visit is null then raise exception using errcode='P0002',message='Visit unavailable'; end if;
  perform public.staff_visit(new_visit,gen_random_uuid(),roster);
 end if;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'create_staffed_work',p_request_id,payload,(result->>'id')::uuid);
 return result;
end; $$;
revoke all on function public.planning_staff(uuid),public.save_work_setup_with_help(uuid,uuid,jsonb,jsonb,jsonb,jsonb,jsonb),public.create_staffed_work(uuid,uuid,jsonb,jsonb,integer,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.planning_staff(uuid),public.save_work_setup_with_help(uuid,uuid,jsonb,jsonb,jsonb,jsonb,jsonb),public.create_staffed_work(uuid,uuid,jsonb,jsonb,integer,jsonb,jsonb,jsonb) to authenticated;
notify pgrst,'reload schema';

savepoint first_helpers_checks;
-- Isolated test project only. Synthetic fixtures and every change roll back.
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

rollback to savepoint first_helpers_checks;
release savepoint first_helpers_checks;
commit;
select 25::integer as checks,0::integer as failed,'0019 applied; synthetic fixtures removed'::text as result;
