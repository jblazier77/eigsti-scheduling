-- Isolated test only; apply 0001-0004 first. All fixtures roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_work_results(ordinal integer primary key,result text not null) on commit drop;
grant insert,select on pg_temp.eigsti_work_results to authenticated,anon;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','work-test-1@example.invalid'),
('22222222-2222-4222-8222-222222222222','work-test-2@example.invalid'),
('33333333-3333-4333-8333-333333333333','work-test-3@example.invalid'),
('44444444-4444-4444-8444-444444444444','work-test-4@example.invalid'),
('55555555-5555-4555-8555-555555555555','work-test-5@example.invalid'),
('66666666-6666-4666-8666-666666666666','work-test-6@example.invalid'),
('77777777-7777-4777-8777-777777777777','work-test-7@example.invalid'),
('88888888-8888-4888-8888-888888888888','work-test-8@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC Work Tester 1',array['pm'],true),
('22222222-2222-4222-8222-222222222222','SYNTHETIC Work Tester 2',array['pm'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Work Tester 3',array['lead'],true),
('44444444-4444-4444-8444-444444444444','SYNTHETIC Work Tester 4',array['helper'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Work Tester 5',array['admin'],true),
('66666666-6666-4666-8666-666666666666','SYNTHETIC Work Tester 6',array['lead'],false),
('77777777-7777-4777-8777-777777777777','SYNTHETIC Work Tester 7',array['lead'],true),
('88888888-8888-4888-8888-888888888888','SYNTHETIC Work Tester 8',array['pm'],false);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,responsible_pm,lifecycle,created_by,updated_by) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Job','3095550101','+13095550101','Fictional Lane','SYNTHETIC Job','11111111-1111-4111-8111-111111111111','open','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC Job','3095550101','+13095550101','Fictional Lane','SYNTHETIC Job','22222222-2222-4222-8222-222222222222','open','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222'),
('cccccccc-cccc-4ccc-8ccc-cccccccccccc','SYNTHETIC Job','3095550101','+13095550101','Fictional Lane','SYNTHETIC Job','11111111-1111-4111-8111-111111111111','closed','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into public.work_items(id,job_id,description,responsible_lead,created_by,updated_by) values
('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Whole job',null,'11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Whole job','77777777-7777-4777-8777-777777777777','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222');
insert into private.job_access(job_id,user_id,reason,created_by) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','44444444-4444-4444-8444-444444444444','helping_assignment','11111111-1111-4111-8111-111111111111');
insert into public.job_contacts(job_id,name,created_by,updated_by) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Site Contact','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into public.job_files(job_id,filename,mime_type,byte_size,status,created_by,updated_by) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','synthetic.pdf','application/pdf',100,'ready','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_work_results values (1,is((select count(*) from public.list_assignable_leads()),2::bigint,'Only active leads appear'));
insert into pg_temp.eigsti_work_results values (2,is((select count(*) from public.list_assignable_leads() where id in ('44444444-4444-4444-8444-444444444444','55555555-5555-4555-8555-555555555555','66666666-6666-4666-8666-666666666666')),0::bigint,'Helper admin-only and inactive lead are excluded'));
insert into pg_temp.eigsti_work_results values (3,is((select count(*) from public.list_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')),1::bigint,'Default whole-job work is readable'));
insert into pg_temp.eigsti_work_results values (4,throws_ok($test$insert into public.work_items(job_id,description,created_by,updated_by) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Forged','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111')$test$,'42501',null,'Direct work creation denied'));
insert into pg_temp.eigsti_work_results values (5,throws_ok($test$update public.work_items set responsible_lead='33333333-3333-4333-8333-333333333333' where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'$test$,'42501',null,'Direct work reassignment denied'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_work_results values (6,is((select count(*) from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),0::bigint,'Unassigned lead cannot read customer job'));
insert into pg_temp.eigsti_work_results values (7,throws_ok($test$select * from public.list_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$test$,'42501','Job access required','Unassigned work read denied'));
insert into pg_temp.eigsti_work_results values (8,throws_ok($test$select * from public.list_assignable_leads()$test$,'42501','PM account required','Lead cannot enumerate assignment directory'));
insert into pg_temp.eigsti_work_results values (9,throws_ok($test$select public.create_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','{"description":"Forged","responsible_lead":"33333333-3333-4333-8333-333333333333"}')$test$,'42501','PM account required','Lead cannot assign self'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_work_results values (10,is((select count(*) from public.list_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')),1::bigint,'Assigned helper can read shared job work'));
insert into pg_temp.eigsti_work_results values (11,throws_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"responsible_lead":"44444444-4444-4444-8444-444444444444"}')$test$,'42501','PM account required','Helper forged reassignment denied'));
insert into pg_temp.eigsti_work_results values (12,throws_ok($test$select * from public.list_assignable_leads()$test$,'42501','PM account required','Helper directory denied'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_work_results values (13,throws_ok($test$select public.create_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','{"description":"Forged","responsible_lead":null}')$test$,'42501','PM account required','Admin-only does not inherit PM'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);
insert into pg_temp.eigsti_work_results values (14,throws_ok($test$select * from public.list_assignable_leads()$test$,'42501','PM account required','Inactive PM denied with stale identity'));
reset role;
set local role anon;
insert into pg_temp.eigsti_work_results values (15,throws_ok($test$select * from public.list_assignable_leads()$test$,'42501',null,'Anonymous directory denied'));
insert into pg_temp.eigsti_work_results values (16,throws_ok($test$select * from public.list_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$test$,'42501',null,'Anonymous work RPC denied'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_work_results values (17,lives_ok($test$select public.create_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','{"description":"Framing","responsible_lead":"33333333-3333-4333-8333-333333333333"}')$test$,'PM creates independently owned portion'));
insert into pg_temp.eigsti_work_results values (18,is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),2::bigint,'Original whole-job identity retained'));
insert into pg_temp.eigsti_work_results values (19,lives_ok($test$select public.create_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','{"description":"Framing","responsible_lead":"33333333-3333-4333-8333-333333333333"}')$test$,'Same create request safely replays'));
insert into pg_temp.eigsti_work_results values (20,is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),2::bigint,'Create replay does not duplicate portion'));
insert into pg_temp.eigsti_work_results values (21,is((select count(*) from public.audit_events where operation='create_job_work' and request_id='ffffffff-ffff-4fff-8fff-ffffffffffff'),1::bigint,'Create retry adds one audit effect'));
insert into pg_temp.eigsti_work_results values (22,throws_ok($test$select public.create_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','{"description":"Different","responsible_lead":"33333333-3333-4333-8333-333333333333"}')$test$,'23505','Request payload changed','Changed retry payload rejected'));
insert into pg_temp.eigsti_work_results values (23,throws_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"responsible_lead":"44444444-4444-4444-8444-444444444444"}')$test$,'22023','Active lead required','Cannot assign helper'));
insert into pg_temp.eigsti_work_results values (24,throws_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"responsible_lead":"66666666-6666-4666-8666-666666666666"}')$test$,'22023','Active lead required','Cannot assign inactive lead'));
insert into pg_temp.eigsti_work_results values (25,throws_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"responsible_lead":"99999999-9999-4999-8999-999999999999"}')$test$,'22023','Active lead required','Cannot assign missing employee'));
insert into pg_temp.eigsti_work_results values (26,throws_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"description":""}')$test$,'22023','Invalid work description','Empty work description denied'));
insert into pg_temp.eigsti_work_results values (27,throws_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"completion":"completed"}')$test$,'22023','Invalid work field','Completion cannot be forged through assignment'));
insert into pg_temp.eigsti_work_results values (28,throws_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"responsible_lead":"bad"}')$test$,'22023','Invalid lead identifier','Malformed lead UUID denied'));
insert into pg_temp.eigsti_work_results values (29,throws_ok($test$select public.create_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-fffffffffff1','{"responsible_lead":null}')$test$,'22023','Incomplete work details','Create requires description'));
insert into pg_temp.eigsti_work_results values (30,throws_ok($test$select public.create_job_work('cccccccc-cccc-4ccc-8ccc-cccccccccccc','ffffffff-ffff-4fff-8fff-fffffffffff2','{"description":"Closed","responsible_lead":null}')$test$,'P0002','Open job required','Closed job creation denied'));
insert into pg_temp.eigsti_work_results values (31,throws_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','{"description":"Forged"}')$test$,'P0002','Work unavailable','Forged parent work relationship denied'));
insert into pg_temp.eigsti_work_results values (32,lives_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"responsible_lead":"33333333-3333-4333-8333-333333333333"}')$test$,'PM assigns whole-job lead'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_work_results values (33,is((select count(*) from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),1::bigint,'Assigned lead gains job access'));
insert into pg_temp.eigsti_work_results values (34,is((select count(*) from public.job_contacts where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),1::bigint,'Lead gains scoped contact access'));
insert into pg_temp.eigsti_work_results values (35,is((select count(*) from public.job_files where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),1::bigint,'Lead gains ready-file metadata access'));
insert into pg_temp.eigsti_work_results values (36,is((select count(*) from public.list_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')),2::bigint,'Assigned lead sees shared portions'));
insert into pg_temp.eigsti_work_results values (37,throws_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"description":"Unauthorized"}')$test$,'42501','PM account required','Lead cannot edit PM ownership fields'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_work_results values (38,lives_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"responsible_lead":"77777777-7777-4777-8777-777777777777"}')$test$,'Other PM may reassign whole-job lead'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_work_results values (39,is((select count(*) from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),1::bigint,'Owning another portion preserves job access'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_work_results values (40,lives_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',(select id from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and description='Framing'),'{"responsible_lead":"77777777-7777-4777-8777-777777777777"}')$test$,'PM reassigns remaining portion independently'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_work_results values (41,is((select count(*) from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),0::bigint,'Former lead loses job access after final portion reassigned'));
insert into pg_temp.eigsti_work_results values (42,is((select count(*) from public.job_contacts where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),0::bigint,'Former lead loses contact access'));
insert into pg_temp.eigsti_work_results values (43,is((select count(*) from public.job_files where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),0::bigint,'Former lead loses file metadata access'));
insert into pg_temp.eigsti_work_results values (44,throws_ok($test$select * from public.list_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$test$,'42501','Job access required','Former lead cannot use definer RPC to bypass revocation'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_work_results values (45,lives_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"description":"Finish carpentry"}')$test$,'Narrow description update succeeds'));
insert into pg_temp.eigsti_work_results values (46,is((select count(*) from public.work_items where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd' and responsible_lead='77777777-7777-4777-8777-777777777777'),1::bigint,'Description patch preserves newer lead assignment'));
insert into pg_temp.eigsti_work_results values (47,lives_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"responsible_lead":null}')$test$,'Lead ownership can be cleared'));
insert into pg_temp.eigsti_work_results values (48,is((select count(*) from public.work_items where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd' and description='Finish carpentry' and responsible_lead is null),1::bigint,'Lead clear preserves description'));
insert into pg_temp.eigsti_work_results values (49,is((select count(*) from public.audit_events where operation='update_job_work' and job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),5::bigint,'Each effective update is audited'));
insert into pg_temp.eigsti_work_results values (50,lives_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"responsible_lead":null}')$test$,'Repeated identical patch is harmless'));
insert into pg_temp.eigsti_work_results values (51,is((select count(*) from public.audit_events where operation='update_job_work' and job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),5::bigint,'No-op patch does not duplicate audit'));
reset role;
update public.app_users set active=false where id='77777777-7777-4777-8777-777777777777';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_work_results values (52,is((select count(*) from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),0::bigint,'Live deactivation blocks existing assignment reads'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_work_results values (53,is((select count(*) from public.list_assignable_leads()),1::bigint,'Deactivated lead disappears from directory'));
insert into pg_temp.eigsti_work_results values (54,throws_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"responsible_lead":"77777777-7777-4777-8777-777777777777"}')$test$,'22023','Active lead required','Deactivated account cannot receive new work'));
reset role;
update public.work_items set completion='completed' where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_work_results values (55,throws_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd','{"description":"Rewrite completed work"}')$test$,'22023','Open work required','Completed work cannot be edited through ownership command'));
reset role;
insert into public.work_items(job_id,description,created_by,updated_by)
select 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Limit ' || n,'11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111' from generate_series(1,98) n;
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_work_results values (56,throws_ok($test$select public.create_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-fffffffffff3','{"description":"Overflow","responsible_lead":null}')$test$,'22023','Work limit reached','Per-job limit enforced'));
insert into pg_temp.eigsti_work_results values (57,is((select count(*) from public.list_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')),100::bigint,'All portions fit bounded response'));
insert into pg_temp.eigsti_work_results values (58,is((select count(*) from public.audit_events where request_id='ffffffff-ffff-4fff-8fff-fffffffffff3'),0::bigint,'Rejected create leaves no audit effect'));
reset role;
do $validation$
declare v_failures text;
begin
 if (select count(*) from pg_temp.eigsti_work_results)<>58 then raise exception 'Incomplete work tests: expected 58 checks'; end if;
 select string_agg(result,E'\n' order by ordinal) into v_failures from pg_temp.eigsti_work_results where result not like 'ok %';
 if v_failures is not null then raise exception 'Work tests failed: %',v_failures; end if;
end;
$validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_work_results;
rollback;
