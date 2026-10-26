begin;
do $preflight$ begin if to_regprocedure('public.employee_onboarding_ready(uuid)') is null then raise exception 'Requires 0020'; end if; if position('create_staffed_work' in pg_get_functiondef('public.create_job_workspace(uuid,text,text,text,jsonb,jsonb,jsonb,jsonb,jsonb)'::regprocedure))>0 then raise exception '0021 already present; do not rerun'; end if; end; $preflight$;
-- Apply once after 0020. Preserve existing workspace receipts; add atomic crew setup.
create or replace function public.create_job_workspace(p_request_id uuid,p_customer text,p_phone text,p_address text,p_classification jsonb,p_details jsonb,p_priority jsonb,p_work jsonb,p_contacts jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare payload jsonb; prior private.command_requests%rowtype; result jsonb; v_job uuid; item jsonb; item_request uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null or jsonb_typeof(p_work) is distinct from 'array' or jsonb_typeof(p_contacts) is distinct from 'array' or jsonb_array_length(p_work)>20 or jsonb_array_length(p_contacts)>20 then raise exception using errcode='22023',message='Invalid job setup'; end if;
 payload:=jsonb_build_object('customer',p_customer,'phone',p_phone,'address',p_address,'classification',p_classification,'details',p_details,'priority',p_priority,'work',p_work,'contacts',p_contacts);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':create_job_workspace:'||p_request_id::text,0));
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='create_job_workspace' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':create_classified_job:'||p_request_id::text,0));
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':create_job:'||p_request_id::text,0));
 if exists(select 1 from private.command_requests where actor_id=auth.uid() and request_id=p_request_id and operation in ('create_job','create_classified_job')) then raise exception using errcode='23505',message='Request payload changed'; end if;
 result:=public.create_classified_job(p_request_id,p_customer,p_phone,p_address,p_classification);v_job:=(result->>'id')::uuid;
 if p_details is null or jsonb_typeof(p_details)<>'object' or exists(select 1 from jsonb_object_keys(p_details) k where k not in ('title','scope','access_notes')) then raise exception using errcode='22023',message='Invalid job setup'; end if;
 if p_details<>'{}'::jsonb then perform public.update_job(v_job,p_details); end if;
 perform public.save_job_priority(v_job,p_request_id,p_priority);
 -- create_job supplies one Whole job item; remove only this newly-created placeholder
 -- when explicit task drafts were supplied, before any dates or ownership exist.
 if jsonb_array_length(p_work)>0 then delete from public.work_items where job_id=v_job; end if;
 for item in select value from jsonb_array_elements(p_work) loop
  item_request:=gen_random_uuid();
  perform public.create_staffed_work(v_job,item_request,item->'values',item->'plan',(item->>'helpers')::integer,item->'materials',item->'days',coalesce(item->'named_helpers','[]'::jsonb));
 end loop;
 for item in select value from jsonb_array_elements(p_contacts) loop perform public.create_job_contact(v_job,gen_random_uuid(),item); end loop;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'create_job_workspace',p_request_id,payload,v_job);
 return result;
end; $$;
notify pgrst,'reload schema';

savepoint new_job_helpers_checks;
-- Isolated test project only. Synthetic fixtures and every change roll back.
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

rollback to savepoint new_job_helpers_checks;
release savepoint new_job_helpers_checks;
commit;
select 15::integer as checks,0::integer as failed,'0021 applied; synthetic fixtures removed'::text as result;
