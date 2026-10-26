-- Apply ONCE after 0017 in the fictional-data project. Synthetic fixtures roll back.
begin;
do $preflight$ begin
 if to_regprocedure('public.save_work_details(uuid,uuid,jsonb)') is null then raise exception 'Unified work editor requires applied 0017.'; end if;
 if to_regprocedure('public.save_work_setup(uuid,uuid,jsonb,jsonb,jsonb,jsonb)') is not null then raise exception '0018 may already be applied. Do not rerun; verify state.'; end if;
end; $preflight$;
-- Apply once after 0017. Atomic updates for the unified work editor.
create function public.save_work_setup(p_work_id uuid,p_request_id uuid,p_patch jsonb,p_materials jsonb,p_plan jsonb,p_visits jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items%rowtype; j public.jobs%rowtype; payload jsonb; prior private.command_requests%rowtype; k text; entry jsonb; visit_id uuid; seen uuid[]:=array[]::uuid[]; roster uuid[];
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not(private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Work planner required'; end if;
 if p_request_id is null or p_patch is null or jsonb_typeof(p_patch)<>'object' then raise exception using errcode='22023',message='Invalid work details'; end if;
 p_materials:=nullif(p_materials,'null'::jsonb);p_plan:=nullif(p_plan,'null'::jsonb);
 if p_visits is null or jsonb_typeof(p_visits)<>'array' or jsonb_array_length(p_visits)>100 then raise exception using errcode='22023',message='Invalid work dates'; end if;
 select x.* into j from public.jobs x join public.work_items y on y.job_id=x.id where y.id=p_work_id for update of x;
 select * into w from public.work_items where id=p_work_id for update;
 if w.id is null or j.lifecycle<>'open' or w.completion<>'open' then raise exception using errcode='P0002',message='Open work required'; end if;
 if not private.can_read_job(j.id) then raise exception using errcode='42501',message='Job access required'; end if;
 if (p_patch<>'{}'::jsonb or p_materials is not null) and not private.has_role('pm') and w.responsible_lead is distinct from auth.uid() then raise exception using errcode='42501',message='Responsible lead required'; end if;
 payload:=jsonb_build_object('work',p_work_id,'patch',p_patch,'materials',p_materials,'plan',p_plan,'visits',p_visits);
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='save_work_setup' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',w.id,'job_id',j.id);
 end if;
 if exists(select 1 from private.command_requests where actor_id=auth.uid() and request_id=p_request_id and operation in ('save_work_details','save_work_materials','save_visit')) then raise exception using errcode='23505',message='Request payload changed'; end if;
 if p_patch<>'{}'::jsonb then perform public.save_work_details(w.id,p_request_id,p_patch); end if;
 if p_materials is not null then perform public.save_work_materials(w.id,p_request_id,p_materials); end if;
 if p_plan is not null then
  if exists(select 1 from public.visits where work_item_id=w.id and state='planned' and start_date=(p_plan->>'start_date')::date and end_date=(p_plan->>'end_date')::date and coordinator_id=(p_plan->>'coordinator_id')::uuid and slot=p_plan->>'slot' and start_time is not distinct from (p_plan->>'start_time')::time and end_time is not distinct from (p_plan->>'end_time')::time) then raise exception using errcode='22023',message='Edit existing work dates'; end if;
  perform public.save_visit(w.id,null,p_request_id,p_plan);
 end if;
 for entry in select value from jsonb_array_elements(p_visits) loop
  if jsonb_typeof(entry)<>'object' or not(entry ?& array['id','patch','helpers','cancel']) or (select count(*) from jsonb_object_keys(entry))<>4 then raise exception using errcode='22023',message='Invalid work dates'; end if;
  visit_id:=(entry->>'id')::uuid;
  if visit_id is null or visit_id=any(seen) then raise exception using errcode='22023',message='Invalid work dates'; end if;
  seen:=array_append(seen,visit_id);
  perform id from public.visits where id=visit_id and work_item_id=w.id and state='planned' for update;
  if not found then raise exception using errcode='P0002',message='Visit unavailable'; end if;
  if jsonb_typeof(entry->'cancel')<>'boolean' then raise exception using errcode='22023',message='Invalid work dates'; end if;
  if (entry->>'cancel')::boolean then
   perform public.save_visit(w.id,visit_id,gen_random_uuid(),'{"state":"cancelled"}'::jsonb);
  else
   roster:=null;
   if entry->'helpers'<>'null'::jsonb then
    if jsonb_typeof(entry->'helpers')<>'array' then raise exception using errcode='22023',message='Invalid staffing'; end if;
    select coalesce(array_agg(x::uuid),'{}'::uuid[]) into roster from jsonb_array_elements_text(entry->'helpers') x;
   end if;
   perform public.save_visit_card(w.id,visit_id,gen_random_uuid(),entry->'patch',roster);
  end if;
 end loop;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'save_work_setup',p_request_id,payload,w.id);
 return jsonb_build_object('id',w.id,'job_id',j.id);
end; $$;
revoke all on function public.save_work_setup(uuid,uuid,jsonb,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.save_work_setup(uuid,uuid,jsonb,jsonb,jsonb,jsonb) to authenticated;
notify pgrst,'reload schema';

savepoint setup_fixture_checks;
-- Isolated test project only. Synthetic fixtures and every change roll back.
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

rollback to savepoint setup_fixture_checks;
release savepoint setup_fixture_checks;
commit;
select 27::integer as checks,0::integer as failed,'0018 applied; synthetic fixtures removed'::text as result;
