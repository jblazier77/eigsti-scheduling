-- Isolated test project only. Every synthetic fixture rolls back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_employee_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_employee_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_employee_results,pg_temp.eigsti_employee_ids to authenticated;
grant usage on sequence pg_temp.eigsti_employee_results_ordinal_seq to authenticated;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','commit-pm@example.invalid'),
('22222222-2222-4222-8222-222222222222','commit-pm2@example.invalid'),
('33333333-3333-4333-8333-333333333333','commit-lead@example.invalid'),
('44444444-4444-4444-8444-444444444444','commit-other@example.invalid'),
('55555555-5555-4555-8555-555555555555','commit-helper@example.invalid'),
('77777777-7777-4777-8777-777777777777','commit-admin@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC PM',array['pm','lead'],true),
('22222222-2222-4222-8222-222222222222','SYNTHETIC PM2',array['pm'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Lead',array['lead'],true),
('44444444-4444-4444-8444-444444444444','SYNTHETIC Other',array['lead'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Helper',array['helper'],true),
('77777777-7777-4777-8777-777777777777','SYNTHETIC Admin',array['admin'],true);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,scope,access_notes,responsible_pm,created_by,updated_by) select id,'SYNTHETIC Customer','3095550101','+13095550101','Fictional address',title,'','',pm,'11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111' from (values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,'SYNTHETIC Own','11111111-1111-4111-8111-111111111111'::uuid),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC Other','22222222-2222-4222-8222-222222222222')) j(id,title,pm);
insert into public.work_items(job_id,description,responsible_lead,created_by,updated_by) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Work','33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC Other Work','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into private.job_access(job_id,user_id,reason,created_by) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','55555555-5555-4555-8555-555555555555','helping_assignment','11111111-1111-4111-8111-111111111111');
insert into public.job_contacts(id,job_id,name,relationship,phone,email,notes,created_by,updated_by) values
('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Plumber','Subcontractor','','','','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Customer','Customer','','','','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC Other sub','Subcontractor','','','','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
update public.app_users set roles=array['admin','pm'] where id='11111111-1111-4111-8111-111111111111';
create temporary table eigsti_employee_versions(label text primary key,stamp timestamptz not null) on commit drop;
grant insert,select on pg_temp.eigsti_employee_versions to authenticated;
insert into public.visits(id,work_item_id,coordinator_id,start_date,end_date,slot,created_by,updated_by)
select 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa',id,'33333333-3333-4333-8333-333333333333',(date_trunc('week',now() at time zone 'America/Chicago')::date+7),(date_trunc('week',now() at time zone 'America/Chicago')::date+7),'day','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111' from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
insert into public.visit_participants(visit_id,user_id,duty) values('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa','33333333-3333-4333-8333-333333333333','leading'),('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa','55555555-5555-4555-8555-555555555555','helping');
create function pg_temp.edit(p uuid,r uuid,v jsonb,stamp timestamptz default null) returns jsonb language sql as $$select public.save_employee(p,r,coalesce(stamp,(select (e->>'updated_at')::timestamptz from jsonb_array_elements(public.list_employees()) e where e->>'id'=p::text)),v);$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_employee_versions select 'lead',(e->>'updated_at')::timestamptz from jsonb_array_elements(public.list_employees()) e where e->>'id'='33333333-3333-4333-8333-333333333333';
insert into pg_temp.eigsti_employee_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.list_employees()) e where e->>'id'='55555555-5555-4555-8555-555555555555'),'Admin can list employees beyond own RLS profile'));
insert into pg_temp.eigsti_employee_results(result) values(ok(not exists(select 1 from jsonb_array_elements(public.list_employees()) e where e ? 'email' or e ? 'password' or e ? 'encrypted_password'),'Directory contains no Auth email or credential fields'));
insert into pg_temp.eigsti_employee_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.list_employees()) e where e->>'id'='33333333-3333-4333-8333-333333333333' and (e->>'open_work')::integer=1 and (e->>'scheduled_work')::integer=1),'Open work and upcoming crew impact visible'));
insert into pg_temp.eigsti_employee_results(result) values(lives_ok($t$select pg_temp.edit('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001','{"display_name":"SYNTHETIC Lead edited","roles":["helper","lead"],"active":true}',(select stamp from pg_temp.eigsti_employee_versions where label='lead'))$t$,'Name and multiple roles save together'));
insert into pg_temp.eigsti_employee_results(result) values(lives_ok($t$select pg_temp.edit('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001','{"display_name":"SYNTHETIC Lead edited","roles":["lead","helper"],"active":true}',(select stamp from pg_temp.eigsti_employee_versions where label='lead'))$t$,'Reordered roles normalize on exact retry'));
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select pg_temp.edit('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001','{"display_name":"Changed retry","roles":["lead","helper"],"active":true}',(select stamp from pg_temp.eigsti_employee_versions where label='lead'))$t$,'23505','Request payload changed','Changed retry rejected'));
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select pg_temp.edit('33333333-3333-4333-8333-333333333333',gen_random_uuid(),'{"display_name":"Stale","roles":["lead"],"active":true}',(select stamp from pg_temp.eigsti_employee_versions where label='lead'))$t$,'22023','Employee changed. Refresh before saving again.','Stale edit cannot overwrite later roles/name'));
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select pg_temp.edit('11111111-1111-4111-8111-111111111111',gen_random_uuid(),'{"display_name":"SYNTHETIC PM","roles":["pm"],"active":true}')$t$,'22023','You cannot deactivate yourself or remove your own Administrator role.','Admin cannot remove own admin role even with another admin'));
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select pg_temp.edit('11111111-1111-4111-8111-111111111111',gen_random_uuid(),'{"display_name":"SYNTHETIC PM","roles":["admin","pm"],"active":false}')$t$,'22023',null,'Admin cannot deactivate own session'));
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select pg_temp.edit('33333333-3333-4333-8333-333333333333',gen_random_uuid(),'{"display_name":"SYNTHETIC Lead edited","roles":["helper"],"active":true}')$t$,'22023','Reassign open lead work and future coordination before removing the Lead role.','Lead role cannot be removed while work is owned'));
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select pg_temp.edit('55555555-5555-4555-8555-555555555555',gen_random_uuid(),'{"display_name":"SYNTHETIC Helper","roles":["pm"],"active":true}')$t$,'22023','Reassign future helping work or retain a Lead or Helper role.','Upcoming helping duty requires eligible role'));
insert into pg_temp.eigsti_employee_results(result) values(lives_ok($t$select pg_temp.edit('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000002','{"display_name":"SYNTHETIC Lead edited","roles":["lead","helper"],"active":false}')$t$,'Assigned employee may be deactivated without erasing work'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select public.list_job_visits('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$t$,'42501',null,'Deactivated old session loses job reads immediately'));
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select public.list_employees()$t$,'42501','Administrator account required','Deactivated employee cannot enumerate directory'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_employee_results(result) values(lives_ok($t$select pg_temp.edit('33333333-3333-4333-8333-333333333333',gen_random_uuid(),'{"display_name":"SYNTHETIC Lead edited","roles":["lead","helper"],"active":true}')$t$,'Admin can reactivate existing employee'));
reset role;
-- Original deactivation receipt is acknowledged without undoing reactivation.
insert into pg_temp.eigsti_employee_versions select 'deactivation',(payload->>'expected')::timestamptz from private.command_requests where actor_id='11111111-1111-4111-8111-111111111111' and operation='save_employee' and request_id='abcdefab-cdef-4abc-8abc-000000000002';
set local role authenticated;
insert into pg_temp.eigsti_employee_results(result) values(lives_ok($t$select pg_temp.edit('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000002','{"display_name":"SYNTHETIC Lead edited","roles":["lead","helper"],"active":false}',(select stamp from pg_temp.eigsti_employee_versions where label='deactivation'))$t$,'Original deactivation retry acknowledges after reactivation'));
insert into pg_temp.eigsti_employee_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.list_employees()) e where e->>'id'='33333333-3333-4333-8333-333333333333' and (e->>'active')::boolean),'Old retry cannot deactivate employee again'));
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select pg_temp.edit('44444444-4444-4444-8444-444444444444',gen_random_uuid(),'{"display_name":"Bad","roles":[],"active":true}')$t$,'22023',null,'At least one role required'));
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select pg_temp.edit('44444444-4444-4444-8444-444444444444',gen_random_uuid(),'{"display_name":"Bad","roles":["lead","lead"],"active":true}')$t$,'22023',null,'Duplicate roles rejected'));
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select pg_temp.edit('44444444-4444-4444-8444-444444444444',gen_random_uuid(),'{"display_name":"Bad","roles":["owner"],"active":true}')$t$,'22023',null,'Invented roles rejected'));
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select pg_temp.edit('44444444-4444-4444-8444-444444444444',gen_random_uuid(),'{"display_name":"Bad","roles":["lead"],"active":true,"email":"attacker@example.invalid"}')$t$,'22023',null,'Auth field injection rejected'));
insert into pg_temp.eigsti_employee_results(result) values(lives_ok($t$select pg_temp.edit('77777777-7777-4777-8777-777777777777',gen_random_uuid(),'{"display_name":"SYNTHETIC Former admin","roles":["helper"],"active":true}')$t$,'Admin may remove another admin role'));
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select public.save_employee('44444444-4444-4444-8444-444444444444',gen_random_uuid(),now(),'{"display_name":"Forged","roles":["admin"],"active":true}')$t$,'42501','Administrator account required','Removed admin authority is live for next command'));
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select public.list_employees()$t$,'42501','Administrator account required','PM alone cannot enumerate employees'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select public.save_employee('44444444-4444-4444-8444-444444444444',gen_random_uuid(),now(),'{"display_name":"Forged","roles":["admin"],"active":true}')$t$,'42501','Administrator account required','Lead cannot promote self or others'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_employee_results(result) values(throws_ok($t$select public.save_employee('55555555-5555-4555-8555-555555555555',gen_random_uuid(),now(),'{"display_name":"Forged","roles":["admin"],"active":true}')$t$,'42501','Administrator account required','Helper cannot promote self'));
reset role;
insert into pg_temp.eigsti_employee_results(result) values(is((select count(*) from private.employee_events where request_id='abcdefab-cdef-4abc-8abc-000000000001'),1::bigint,'Retry does not duplicate history'));
insert into pg_temp.eigsti_employee_results(result) values(is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),1::bigint,'Work identity and ownership retained'));
insert into pg_temp.eigsti_employee_results(result) values(is((select count(*) from public.visit_participants where visit_id='aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa'),2::bigint,'Deactivation preserves staffing history without silent reassignment'));
insert into pg_temp.eigsti_employee_results(result) values(ok(not has_table_privilege('authenticated','public.app_users','UPDATE'),'Direct profile mutations remain denied'));
insert into pg_temp.eigsti_employee_results(result) values(ok(not has_table_privilege('authenticated','private.employee_events','SELECT'),'Private before/after snapshots stay private'));
insert into pg_temp.eigsti_employee_results(result) values(ok(not has_function_privilege('anon','public.list_employees()','EXECUTE'),'Anonymous employee reads denied'));
insert into pg_temp.eigsti_employee_results(result) values(ok(not has_function_privilege('anon','public.save_employee(uuid,uuid,timestamptz,jsonb)','EXECUTE'),'Anonymous profile mutation denied'));
do $validation$
declare failures text;
begin
 select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_employee_results where result not like 'ok %';
 if failures is not null then raise exception 'Employee checks failed: %',failures; end if;
end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_employee_results;
rollback;