-- Isolated Supabase test ONLY. Apply migrations 0001 and 0002 first.
-- Every fixture and command is rolled back. No existing employee data is changed.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();
create temporary table eigsti_contact_results (ordinal integer primary key, result text not null) on commit drop;
grant insert,select on pg_temp.eigsti_contact_results to authenticated,anon;
insert into auth.users(id,email) values
 ('11111111-1111-4111-8111-111111111111','contact-test-1@example.invalid'),
 ('22222222-2222-4222-8222-222222222222','contact-test-2@example.invalid'),
 ('33333333-3333-4333-8333-333333333333','contact-test-3@example.invalid'),
 ('44444444-4444-4444-8444-444444444444','contact-test-4@example.invalid'),
 ('55555555-5555-4555-8555-555555555555','contact-test-5@example.invalid'),
 ('66666666-6666-4666-8666-666666666666','contact-test-6@example.invalid'),
 ('77777777-7777-4777-8777-777777777777','contact-test-7@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
 ('11111111-1111-4111-8111-111111111111','SYNTHETIC Contact Tester 1',array['pm'],true),
 ('22222222-2222-4222-8222-222222222222','SYNTHETIC Contact Tester 2',array['pm'],true),
 ('33333333-3333-4333-8333-333333333333','SYNTHETIC Contact Tester 3',array['lead'],true),
 ('44444444-4444-4444-8444-444444444444','SYNTHETIC Contact Tester 4',array['helper'],true),
 ('55555555-5555-4555-8555-555555555555','SYNTHETIC Contact Tester 5',array['admin'],true),
 ('66666666-6666-4666-8666-666666666666','SYNTHETIC Contact Tester 6',array['pm'],false);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,responsible_pm,created_by,updated_by) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC A','3095550101','+13095550101','Fictional A','Demo A','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC B','3095550102','+13095550102','Fictional B','Demo B','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222');
insert into public.work_items(job_id,description,responsible_lead,created_by,updated_by) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Whole job','33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into private.job_access(job_id,user_id,reason,created_by) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','44444444-4444-4444-8444-444444444444','helping_assignment','11111111-1111-4111-8111-111111111111');
insert into public.job_contacts(id,job_id,name,phone,phone_action,created_by,updated_by) values
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Contact A','3095550103','+13095550103','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC Contact B','3095550104','+13095550104','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222');
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_contact_results values (1,is((select count(*) from public.job_contacts),1::bigint,'Assigned helper reads job contacts'));
insert into pg_temp.eigsti_contact_results values (2,is((select count(*) from public.job_contacts where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'),0::bigint,'Unrelated contact ID is hidden'));
insert into pg_temp.eigsti_contact_results values (3,throws_ok($$insert into public.job_contacts(job_id,name,created_by,updated_by) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Attack','44444444-4444-4444-8444-444444444444','44444444-4444-4444-8444-444444444444')$$,'42501',null,'Helper raw insert denied'));
insert into pg_temp.eigsti_contact_results values (4,throws_ok($$update public.job_contacts set name='Attack' where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'$$,'42501',null,'Helper raw update denied'));
insert into pg_temp.eigsti_contact_results values (5,throws_ok($$delete from public.job_contacts where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'$$,'42501',null,'Helper raw delete denied'));
insert into pg_temp.eigsti_contact_results values (6,throws_ok($$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"name":"SYNTHETIC New","relationship":"Spouse","phone":"(309) 555-0103","email":"test@example.invalid","notes":"First note"}')$$,'42501',null,'Helper create RPC denied'));
insert into pg_temp.eigsti_contact_results values (7,throws_ok($$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"notes":"Attack"}')$$,'42501','PM account required','Helper edit RPC denied'));
insert into pg_temp.eigsti_contact_results values (8,throws_ok($$select public.archive_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc')$$,'42501','PM account required','Helper archive RPC denied'));
reset role;
update public.jobs set lifecycle='closed' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_contact_results values (9,is((select count(*) from public.job_contacts),0::bigint,'Job closure removes helper contact access'));
reset role;
update public.jobs set lifecycle='open' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
update private.job_access set revoked_at=now() where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_contact_results values (10,is((select count(*) from public.job_contacts),0::bigint,'Assignment revocation removes helper contact access'));
reset role;
update private.job_access set revoked_at=null where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_contact_results values (11,is((select count(*) from public.job_contacts),1::bigint,'Assigned lead reads job contacts'));
insert into pg_temp.eigsti_contact_results values (12,throws_ok($$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"notes":"Attack"}')$$,'42501','PM account required','Lead cannot edit job contacts'));
set local role authenticated;
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_contact_results values (13,is((select count(*) from public.job_contacts),0::bigint,'Admin-only has no implicit operational reads'));
insert into pg_temp.eigsti_contact_results values (14,throws_ok($$select public.archive_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc')$$,'42501','PM account required','Admin-only cannot archive'));
set local role authenticated;
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_contact_results values (15,is((select count(*) from public.job_contacts),0::bigint,'Uninvited identity reads no contacts'));
set local role authenticated;
select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
insert into pg_temp.eigsti_contact_results values (16,is((select count(*) from public.job_contacts),0::bigint,'Inactive PM reads no contacts'));
insert into pg_temp.eigsti_contact_results values (17,throws_ok($$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"name":"SYNTHETIC New","relationship":"Spouse","phone":"(309) 555-0103","email":"test@example.invalid","notes":"First note"}')$$,'42501',null,'Inactive PM cannot create'));
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_contact_results values (18,is((select count(*) from public.job_contacts),2::bigint,'PM reads contacts on all jobs'));
insert into pg_temp.eigsti_contact_results values (19,throws_ok($$update public.job_contacts set name='Raw update' where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'$$,'42501',null,'PM cannot bypass audit with raw update'));
insert into pg_temp.eigsti_contact_results values (20,throws_ok($$select private.contact_patch('{"name":"Attack"}',true)$$,'42501',null,'Validation helper is not a public command'));
insert into pg_temp.eigsti_contact_results values (21,lives_ok($$select public.create_job_contact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"name":"SYNTHETIC New","relationship":"Spouse","phone":"(309) 555-0103","email":"test@example.invalid","notes":"First note"}')$$,'PM adds contact to another PM job'));
insert into pg_temp.eigsti_contact_results values (22,is((select count(*) from public.job_contacts where name='SYNTHETIC New'),1::bigint,'Exactly one additional contact exists'));
insert into pg_temp.eigsti_contact_results values (23,is((select phone_action from public.job_contacts where name='SYNTHETIC New'),'+13095550103','Phone normalized for call and text'));
insert into pg_temp.eigsti_contact_results values (24,is((select count(*) from public.audit_events where request_id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee' and operation='create_job_contact'),1::bigint,'Creation audited once'));
insert into pg_temp.eigsti_contact_results values (25,lives_ok($$select public.create_job_contact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"name":"SYNTHETIC New","relationship":"Spouse","phone":"(309) 555-0103","email":"test@example.invalid","notes":"First note"}')$$,'Same request safely replays'));
insert into pg_temp.eigsti_contact_results values (26,is((select count(*) from public.job_contacts where name='SYNTHETIC New'),1::bigint,'Retry creates no duplicate'));
insert into pg_temp.eigsti_contact_results values (27,is((select count(*) from public.audit_events where request_id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee' and operation='create_job_contact'),1::bigint,'Retry creates no duplicate audit'));
insert into pg_temp.eigsti_contact_results values (28,throws_ok($$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"name":"SYNTHETIC New","relationship":"Spouse","phone":"(309) 555-0103","email":"test@example.invalid","notes":"First note"}')$$,'23505','Request payload changed','Retry cannot change job'));
insert into pg_temp.eigsti_contact_results values (29,throws_ok($$select public.create_job_contact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"name":"SYNTHETIC New","relationship":"Spouse","phone":"(309) 555-0103","email":"test@example.invalid","notes":"Changed note"}')$$,'23505','Request payload changed','Retry cannot change fields'));
insert into pg_temp.eigsti_contact_results values (30,throws_ok($$select public.create_job_contact('ffffffff-ffff-4fff-8fff-ffffffffffff','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee1','{"name":"SYNTHETIC New","relationship":"Spouse","phone":"(309) 555-0103","email":"test@example.invalid","notes":"First note"}')$$,'P0002','Job unavailable','Missing parent job rejected'));
insert into pg_temp.eigsti_contact_results values (31,throws_ok($$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',null,'{"name":"SYNTHETIC New","relationship":"Spouse","phone":"(309) 555-0103","email":"test@example.invalid","notes":"First note"}')$$,'22023','Request identifier required','Null retry ID rejected'));
insert into pg_temp.eigsti_contact_results values (32,throws_ok($$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"name":""}')$$,'22023','Contact name required','Empty name rejected by database'));
insert into pg_temp.eigsti_contact_results values (33,throws_ok($$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"phone":"555"}')$$,'22023','Invalid phone','Invalid phone rejected by database'));
insert into pg_temp.eigsti_contact_results values (34,throws_ok($$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"email":"invalid"}')$$,'22023','Invalid contact email','Invalid email rejected by database'));
insert into pg_temp.eigsti_contact_results values (35,throws_ok($$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"job_id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"}')$$,'22023','Invalid contact field','Contact cannot be moved to a forged job'));
insert into pg_temp.eigsti_contact_results values (36,throws_ok($$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"created_by":"22222222-2222-4222-8222-222222222222"}')$$,'22023','Invalid contact field','Audit actor cannot be forged'));
insert into pg_temp.eigsti_contact_results values (37,throws_ok($$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"notes":null}')$$,'22023','Invalid contact field','Null values rejected'));
insert into pg_temp.eigsti_contact_results values (38,throws_ok($$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{}')$$,'22023','Invalid contact details','Empty patch rejected'));
insert into pg_temp.eigsti_contact_results values (39,throws_ok($$select public.update_job_contact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"notes":"Attack"}')$$,'P0002','Contact unavailable','Mismatched job and contact edit rejected'));
insert into pg_temp.eigsti_contact_results values (40,throws_ok($$select public.archive_job_contact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','cccccccc-cccc-4ccc-8ccc-cccccccccccc')$$,'P0002','Contact unavailable','Mismatched job and contact archive rejected'));
insert into pg_temp.eigsti_contact_results values (41,lives_ok($$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"notes":"Changed note"}')$$,'Narrow contact update succeeds'));
insert into pg_temp.eigsti_contact_results values (42,is((select phone from public.job_contacts where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'),'3095550103','Note update preserves unrelated phone'));
insert into pg_temp.eigsti_contact_results values (43,lives_ok($$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"phone":"","email":"","relationship":"","notes":""}')$$,'Optional fields can be cleared'));
insert into pg_temp.eigsti_contact_results values (44,is((select count(*) from public.job_contacts where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and phone='' and phone_action is null and email='' and notes=''),1::bigint,'Cleared phone removes call and text action'));
insert into pg_temp.eigsti_contact_results values (45,lives_ok($$select public.archive_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc')$$,'PM removal archives contact'));
insert into pg_temp.eigsti_contact_results values (46,is((select count(*) from public.job_contacts where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'),0::bigint,'Archived contact disappears from employee reads'));
insert into pg_temp.eigsti_contact_results values (47,lives_ok($$select public.archive_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc')$$,'Archive retry is safe'));
insert into pg_temp.eigsti_contact_results values (48,is((select count(*) from public.audit_events where operation='archive_job_contact' and job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),1::bigint,'Archive retry produces one history event'));
insert into pg_temp.eigsti_contact_results values (49,throws_ok($$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"notes":"Restore"}')$$,'P0002','Contact unavailable','Editing cannot restore archived contact'));
reset role;
insert into pg_temp.eigsti_contact_results values (50,is((select count(*) from public.job_contacts where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and archived_at is not null),1::bigint,'Archived row and identity retained'));
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_contact_results values (51,lives_ok($$select public.archive_job_contact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',(select id from public.job_contacts where name='SYNTHETIC New'))$$,'New contact can be archived'));
insert into pg_temp.eigsti_contact_results values (52,lives_ok($$select public.create_job_contact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"name":"SYNTHETIC New","relationship":"Spouse","phone":"(309) 555-0103","email":"test@example.invalid","notes":"First note"}')$$,'Delayed create replay confirms original command'));
insert into pg_temp.eigsti_contact_results values (53,is((select count(*) from public.job_contacts where name='SYNTHETIC New'),0::bigint,'Delayed replay does not resurrect removed contact'));
reset role;
update public.app_users set active=false where id='11111111-1111-4111-8111-111111111111';
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_contact_results values (54,is((select count(*) from public.job_contacts),0::bigint,'Live PM deactivation removes contact reads'));
insert into pg_temp.eigsti_contact_results values (55,throws_ok($$select public.update_job_contact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"notes":"Stale token"}')$$,'42501','PM account required','Live PM deactivation removes command access'));
reset role;
set local role anon;
insert into pg_temp.eigsti_contact_results values (56,throws_ok($$select * from public.job_contacts$$,'42501',null,'Anonymous contact reads denied'));
insert into pg_temp.eigsti_contact_results values (57,throws_ok($$select public.archive_job_contact('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','dddddddd-dddd-4ddd-8ddd-dddddddddddd')$$,'42501',null,'Anonymous RPC denied'));
reset role;
update public.app_users set active=true where id='11111111-1111-4111-8111-111111111111';
insert into public.job_contacts(job_id,name,created_by,updated_by)
  select 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Limit ' || n,'11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111' from generate_series(1,100) n;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_contact_results values (58,throws_ok($$select public.create_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2','{"name":"Overflow","relationship":"","phone":"","email":"","notes":""}')$$,'22023','Contact limit reached','Limit enforced in database'));
insert into pg_temp.eigsti_contact_results values (59,is((select count(*) from public.job_contacts where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),100::bigint,'All active contacts fit the list response'));
insert into pg_temp.eigsti_contact_results values (60,is((select count(*) from public.audit_events where request_id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee2'),0::bigint,'Rejected create leaves no audit event'));
reset role;
do $validation$
declare v_failures text;
begin
  if (select count(*) from pg_temp.eigsti_contact_results) <> 60 then raise exception 'Incomplete contact test run: expected 60 checks'; end if;
  select string_agg(result,E'\n' order by ordinal) into v_failures from pg_temp.eigsti_contact_results where result not like 'ok %';
  if v_failures is not null then raise exception 'Contact tests failed: %',v_failures; end if;
end;
$validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_contact_results;
rollback;
