begin;
do $preflight$ begin if to_regprocedure('public.planning_staff(uuid)') is null then raise exception 'Requires 0019'; end if; if to_regprocedure('public.employee_onboarding_ready(uuid)') is not null then raise exception '0020 already present; do not rerun'; end if; end; $preflight$;
-- Apply once after 0019. Server-only account enrollment; no password storage.
create function public.employee_onboarding_ready(p_actor uuid) returns boolean language plpgsql security definer set search_path='' as $fn$
begin
 if not exists(select 1 from public.app_users where id=p_actor and active and 'admin'=any(roles)) then raise exception using errcode='42501',message='Administrator account required'; end if;
 return true;
end; $fn$;
create function public.enroll_employee_account(p_actor uuid,p_id uuid,p_request uuid,p_values jsonb) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare prior private.command_requests%rowtype;payload jsonb;v_roles text[];v_name text;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=p_actor for update;
 if not exists(select 1 from public.app_users where id=p_actor and active and 'admin'=any(roles)) then raise exception using errcode='42501',message='Administrator account required'; end if;
 if p_id is null or p_request is null or p_values is null or jsonb_typeof(p_values)<>'object' or not(p_values ?& array['display_name','roles','active']) or (select count(*) from jsonb_object_keys(p_values))<>3 or jsonb_typeof(p_values->'display_name')<>'string' or jsonb_typeof(p_values->'roles')<>'array' or p_values->'active'<>'true'::jsonb then raise exception using errcode='22023',message='Invalid employee'; end if;
 v_name:=btrim(p_values->>'display_name');
 if length(v_name) not between 1 and 100 or v_name ~ '[[:cntrl:]]' or jsonb_array_length(p_values->'roles') not between 1 and 4 or exists(select 1 from jsonb_array_elements(p_values->'roles') r where jsonb_typeof(r)<>'string' or (r#>>'{}') not in ('admin','pm','lead','helper')) then raise exception using errcode='22023',message='Invalid employee'; end if;
 select array_agg(r order by r) into v_roles from jsonb_array_elements_text(p_values->'roles') r;
 if cardinality(v_roles)<>(select count(distinct r) from unnest(v_roles) r) then raise exception using errcode='22023',message='Invalid employee'; end if;
 p_values:=jsonb_build_object('display_name',v_name,'roles',v_roles,'active',true);
 payload:=jsonb_build_object('id',p_id,'values',p_values);
 select * into prior from private.command_requests where actor_id=p_actor and operation='enroll_employee_account' and request_id=p_request;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request changed'; end if;
  return private.employee_result(p_id);
 end if;
 if not exists(select 1 from auth.users where id=p_id and raw_app_meta_data->>'eigsti_actor'=p_actor::text and raw_app_meta_data->>'eigsti_request'=p_request::text and length(raw_app_meta_data->>'eigsti_onboarding')=64) then raise exception using errcode='42501',message='Account setup identity mismatch'; end if;
 if exists(select 1 from public.app_users where id=p_id) then raise exception using errcode='23505',message='Employee already exists'; end if;
 insert into public.app_users(id,display_name,roles,active) values(p_id,v_name,v_roles,true);
 insert into private.employee_events(employee_id,actor_id,request_id,before_state,after_state) values(p_id,p_actor,p_request,'{}',p_values);
 insert into private.command_requests(actor_id,request_id,operation,payload,result_id) values(p_actor,p_request,'enroll_employee_account',payload,p_id);
 return private.employee_result(p_id);
end; $fn$;
revoke all on function public.employee_onboarding_ready(uuid),public.enroll_employee_account(uuid,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.employee_onboarding_ready(uuid),public.enroll_employee_account(uuid,uuid,uuid,jsonb) to service_role;
notify pgrst,'reload schema';

savepoint account_checks;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_account_results(result text not null) on commit drop;
insert into auth.users(id,email,raw_app_meta_data) values
('77777777-7777-4777-8777-777777777777','account-admin@example.invalid','{}'),
('55555555-5555-4555-8555-555555555555','account-new@example.invalid','{"eigsti_actor":"77777777-7777-4777-8777-777777777777","eigsti_request":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","eigsti_onboarding":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}'),
('33333333-3333-4333-8333-333333333333','account-lead@example.invalid','{}');
insert into public.app_users(id,display_name,roles) values('77777777-7777-4777-8777-777777777777','SYNTHETIC Admin',array['admin']),('33333333-3333-4333-8333-333333333333','SYNTHETIC Lead',array['lead']);
insert into pg_temp.eigsti_account_results values(ok(not has_function_privilege('authenticated','public.enroll_employee_account(uuid,uuid,uuid,jsonb)','execute'),'Ordinary clients cannot enroll accounts'));
insert into pg_temp.eigsti_account_results values(ok(not has_function_privilege('anon','public.employee_onboarding_ready(uuid)','execute'),'Anonymous cannot probe account setup'));
insert into pg_temp.eigsti_account_results values(ok(has_function_privilege('service_role','public.enroll_employee_account(uuid,uuid,uuid,jsonb)','execute'),'Server role can enroll'));
insert into pg_temp.eigsti_account_results values(throws_ok($q$select public.employee_onboarding_ready('33333333-3333-4333-8333-333333333333')$q$,'42501','Administrator account required','Lead cannot act as account administrator'));
insert into pg_temp.eigsti_account_results values(is(public.employee_onboarding_ready('77777777-7777-4777-8777-777777777777'),true,'Active administrator readiness'));
insert into pg_temp.eigsti_account_results values(lives_ok($q$select public.enroll_employee_account('77777777-7777-4777-8777-777777777777','55555555-5555-4555-8555-555555555555','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','{"display_name":"SYNTHETIC New helper","roles":["helper"],"active":true}')$q$,'Create helper profile'));
insert into pg_temp.eigsti_account_results values(lives_ok($q$select public.enroll_employee_account('77777777-7777-4777-8777-777777777777','55555555-5555-4555-8555-555555555555','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','{"display_name":"SYNTHETIC New helper","roles":["helper"],"active":true}')$q$,'Retry same setup'));
insert into pg_temp.eigsti_account_results values(is((select count(*) from private.employee_events where employee_id='55555555-5555-4555-8555-555555555555'),1::bigint,'Retry does not duplicate audit'));
insert into pg_temp.eigsti_account_results values(throws_ok($q$select public.enroll_employee_account('77777777-7777-4777-8777-777777777777','55555555-5555-4555-8555-555555555555','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','{"display_name":"SYNTHETIC New helper","roles":["admin"],"active":true}')$q$,'23505','Request changed','Changed retry cannot promote employee'));
insert into pg_temp.eigsti_account_results values(throws_ok($q$select public.enroll_employee_account('77777777-7777-4777-8777-777777777777','33333333-3333-4333-8333-333333333333','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','{"display_name":"SYNTHETIC Hijack","roles":["admin"],"active":true}')$q$,'42501','Account setup identity mismatch','Existing account cannot be claimed'));
insert into pg_temp.eigsti_account_results values(throws_ok($q$select public.enroll_employee_account('77777777-7777-4777-8777-777777777777','55555555-5555-4555-8555-555555555555','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','{"display_name":"SYNTHETIC Bad roles","roles":["helper","helper"],"active":true}')$q$,'22023','Invalid employee','Duplicate roles rejected'));
update public.app_users set active=false where id='77777777-7777-4777-8777-777777777777';
insert into pg_temp.eigsti_account_results values(throws_ok($q$select public.enroll_employee_account('77777777-7777-4777-8777-777777777777','55555555-5555-4555-8555-555555555555','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','{"display_name":"SYNTHETIC New helper","roles":["helper"],"active":true}')$q$,'42501','Administrator account required','Revoked administrator cannot retry'));
select result from pg_temp.eigsti_account_results;
do $check$ begin if exists(select 1 from pg_temp.eigsti_account_results where result like 'not ok%') then raise exception 'Employee account checks failed'; end if; end; $check$;
select * from finish();

rollback to savepoint account_checks;
release savepoint account_checks;
commit;
select 12::integer as checks,0::integer as failed,'0020 applied; synthetic fixtures removed'::text as result;
