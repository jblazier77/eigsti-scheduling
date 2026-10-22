-- Isolated test only, apply 0001-0005 first. All fixtures roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_lead_contact_results(ordinal integer primary key,result text not null) on commit drop;
grant insert,select on pg_temp.eigsti_lead_contact_results to authenticated,anon;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','lead-contact-test-1@example.invalid'),
('22222222-2222-4222-8222-222222222222','lead-contact-test-2@example.invalid'),
('33333333-3333-4333-8333-333333333333','lead-contact-test-3@example.invalid'),
('44444444-4444-4444-8444-444444444444','lead-contact-test-4@example.invalid'),
('55555555-5555-4555-8555-555555555555','lead-contact-test-5@example.invalid'),
('66666666-6666-4666-8666-666666666666','lead-contact-test-6@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC Lead Contact 1',array['pm'],true),
('22222222-2222-4222-8222-222222222222','SYNTHETIC Lead Contact 2',array['lead'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Lead Contact 3',array['helper'],true),
('44444444-4444-4444-8444-444444444444','SYNTHETIC Lead Contact 4',array['admin'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Lead Contact 5',array['lead'],true),
('66666666-6666-4666-8666-666666666666','SYNTHETIC Lead Contact 6',array['lead'],false);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,responsible_pm,created_by,updated_by) select j,'SYNTHETIC Customer','3095550101','+13095550101','Fictional Lane','SYNTHETIC Job','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111' from unnest(array['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid]) j;
insert into public.work_items(job_id,description,responsible_lead,created_by,updated_by) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Whole job','22222222-2222-4222-8222-222222222222','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into public.job_contacts(id,job_id,name,created_by,updated_by) values('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Seed','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into private.job_access(job_id,user_id,reason,created_by) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','33333333-3333-4333-8333-333333333333','helping_assignment','11111111-1111-4111-8111-111111111111');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_lead_contact_results values(1,lives_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'Assigned lead adds contact'));
insert into pg_temp.eigsti_lead_contact_results values(2,is((select count(*) from public.job_contacts where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),2::bigint,'New contact is readable'));
insert into pg_temp.eigsti_lead_contact_results values(3,is((select count(*) from public.job_contacts where name='SYNTHETIC Lead Added' and created_by='22222222-2222-4222-8222-222222222222' and updated_by='22222222-2222-4222-8222-222222222222'),1::bigint,'Real lead actor is attributed'));
insert into pg_temp.eigsti_lead_contact_results values(4,lives_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'Identical lead request replays'));
insert into pg_temp.eigsti_lead_contact_results values(5,is((select count(*) from public.job_contacts where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),2::bigint,'Retry does not duplicate contact'));
insert into pg_temp.eigsti_lead_contact_results values(6,is((select count(*) from public.audit_events where actor_id='22222222-2222-4222-8222-222222222222' and operation='create_job_contact'),1::bigint,'Retry has one audit effect'));
insert into pg_temp.eigsti_lead_contact_results values(7,throws_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"name":"Changed","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'23505','Request payload changed','Changed retry payload denied'));
insert into pg_temp.eigsti_lead_contact_results values(8,throws_ok($test$select public.create_job_contact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'42501','PM or assigned lead required','Lead cannot add on unrelated job'));
insert into pg_temp.eigsti_lead_contact_results values(9,throws_ok($test$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',(select id from public.job_contacts where name='SYNTHETIC Lead Added' and job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'{"notes":"Rewrite"}')$test$,'42501','PM account required','Lead cannot edit own added contact'));
insert into pg_temp.eigsti_lead_contact_results values(10,throws_ok($test$select public.archive_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',(select id from public.job_contacts where name='SYNTHETIC Lead Added' and job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'))$test$,'42501','PM account required','Lead cannot remove own added contact'));
insert into pg_temp.eigsti_lead_contact_results values(11,throws_ok($test$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"name":"Rewrite"}')$test$,'42501','PM account required','Lead cannot edit another contact'));
insert into pg_temp.eigsti_lead_contact_results values(12,throws_ok($test$insert into public.job_contacts(job_id,name,created_by,updated_by) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Forged','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222')$test$,'42501',null,'Raw insert denied'));
insert into pg_temp.eigsti_lead_contact_results values(13,throws_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only","created_by":"11111111-1111-4111-8111-111111111111"}')$test$,'22023','Invalid contact field','Forged actor field denied'));
insert into pg_temp.eigsti_lead_contact_results values(14,throws_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"name":"","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'22023','Contact name required','Blank contact rejected'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_lead_contact_results values(15,throws_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'42501','PM or assigned lead required','Assigned helper cannot create'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_lead_contact_results values(16,throws_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'42501','PM or assigned lead required','Admin-only cannot create'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_lead_contact_results values(17,throws_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'42501','PM or assigned lead required','Unassigned lead cannot create'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
insert into pg_temp.eigsti_lead_contact_results values(18,throws_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'42501','PM or assigned lead required','Inactive lead cannot create'));
reset role;
set local role anon;
insert into pg_temp.eigsti_lead_contact_results values(19,throws_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'42501',null,'Anonymous RPC denied'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_lead_contact_results values(20,lives_ok($test$select public.create_job_contact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'PM may still create on any job'));
insert into pg_temp.eigsti_lead_contact_results values(21,lives_ok($test$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"notes":"PM update"}')$test$,'PM may still edit contacts'));
insert into pg_temp.eigsti_lead_contact_results values(22,lives_ok($test$select public.archive_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',(select id from public.job_contacts where name='SYNTHETIC Lead Added' and job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'))$test$,'PM may archive lead-created contact'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_lead_contact_results values(23,lives_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'Delayed lead retry confirms archived original'));
insert into pg_temp.eigsti_lead_contact_results values(24,is((select count(*) from public.job_contacts where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and name='SYNTHETIC Lead Added'),0::bigint,'Delayed retry cannot restore removed contact'));
reset role;
update public.work_items set responsible_lead=null where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_lead_contact_results values(25,throws_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'42501','PM or assigned lead required','Revoked ownership also blocks old request replay'));
insert into pg_temp.eigsti_lead_contact_results values(26,throws_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'42501','PM or assigned lead required','Revoked lead cannot create new contact'));
reset role;
insert into private.job_access(job_id,user_id,reason,created_by) values('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','helping_assignment','11111111-1111-4111-8111-111111111111');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_lead_contact_results values(27,lives_ok($test$select public.create_job_contact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'Lead helping with authorized job may add contact'));
reset role;
update private.job_access set revoked_at=now() where user_id='22222222-2222-4222-8222-222222222222' and job_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_lead_contact_results values(28,throws_ok($test$select public.create_job_contact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'42501','PM or assigned lead required','Revoked helping access blocks creation replay'));
reset role;
update public.work_items set responsible_lead='22222222-2222-4222-8222-222222222222' where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
update public.app_users set active=false where id='22222222-2222-4222-8222-222222222222';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_lead_contact_results values(29,throws_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'42501','PM or assigned lead required','Live account deactivation blocks creation'));
reset role;
update public.app_users set active=true where id='22222222-2222-4222-8222-222222222222';
insert into public.job_contacts(job_id,name,created_by,updated_by)
select 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Limit ' || n,'11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111' from generate_series(1,100-(select count(*)::integer from public.job_contacts where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and archived_at is null)) n;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_lead_contact_results values(30,throws_ok($test$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1','{"name":"SYNTHETIC Lead Added","relationship":"Site contact","phone":"3095550103","email":"contact@example.invalid","notes":"Synthetic only"}')$test$,'22023','Contact limit reached','Lead uses shared 100-contact limit'));
insert into pg_temp.eigsti_lead_contact_results values(31,is((select count(*) from public.job_contacts where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),100::bigint,'Rejected limit create retains exact active count'));
insert into pg_temp.eigsti_lead_contact_results values(32,is((select count(*) from public.audit_events where actor_id='22222222-2222-4222-8222-222222222222' and request_id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1' and job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),0::bigint,'Rejected create has no audit effect'));
reset role;
do $validation$
declare v_failures text;
begin
 if (select count(*) from pg_temp.eigsti_lead_contact_results)<>32 then raise exception 'Incomplete lead contact tests: expected 32'; end if;
 select string_agg(result,E'\n' order by ordinal) into v_failures from pg_temp.eigsti_lead_contact_results where result not like 'ok %';
 if v_failures is not null then raise exception 'Lead contact tests failed: %',v_failures; end if;
end;
$validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_lead_contact_results;
rollback;
