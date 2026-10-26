begin;
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
rollback;
