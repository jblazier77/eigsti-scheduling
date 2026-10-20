-- DRAFT integration suite; not executed here. Requires isolated Supabase + pgTAP.
-- Auth fixtures are synthetic. Everything rolls back, including auth rows.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

insert into auth.users(id,email) values
 ('11111111-1111-4111-8111-111111111111','pm1@example.invalid'),
 ('22222222-2222-4222-8222-222222222222','pm2@example.invalid'),
 ('33333333-3333-4333-8333-333333333333','lead1@example.invalid'),
 ('44444444-4444-4444-8444-444444444444','helper@example.invalid'),
 ('55555555-5555-4555-8555-555555555555','admin@example.invalid'),
 ('66666666-6666-4666-8666-666666666666','inactive@example.invalid'),
 ('77777777-7777-4777-8777-777777777777','uninvited@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
 ('11111111-1111-4111-8111-111111111111','Demo PM 1',array['pm'],true),
 ('22222222-2222-4222-8222-222222222222','Demo PM 2',array['pm'],true),
 ('33333333-3333-4333-8333-333333333333','Demo Lead',array['lead'],true),
 ('44444444-4444-4444-8444-444444444444','Demo Helper',array['helper'],true),
 ('55555555-5555-4555-8555-555555555555','Demo Admin',array['admin'],true),
 ('66666666-6666-4666-8666-666666666666','Demo Inactive',array['pm'],false);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,responsible_pm,created_by,updated_by) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC A','202-555-0100','+12025550100','Fictional A','Demo A','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC B','202-555-0101','+12025550101','Fictional B','Demo B','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222');
insert into public.work_items(job_id,description,responsible_lead,created_by,updated_by) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Whole job','33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into private.job_access(job_id,user_id,reason,created_by) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','44444444-4444-4444-8444-444444444444','helping_assignment','11111111-1111-4111-8111-111111111111');
insert into public.audit_events(job_id,actor_id,operation,changed_fields) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','fixture',array['scope']);

set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
select is((select count(*) from public.jobs),1::bigint,'Helper sees assigned job only');
select is((select count(*) from public.jobs where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),0::bigint,'Helper cannot fetch another job by ID');
select throws_ok($$select public.create_job('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Demo','2025550100','Fictional')$$,'42501','PM account required','Helper RPC create denied');
select throws_ok($$select public.update_job('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','{"title":"Attack"}')$$,'42501','PM account required','Helper RPC edit denied');
select throws_ok($$update public.app_users set roles=array['pm'] where id='44444444-4444-4444-8444-444444444444'$$,'42501',null,'Helper cannot promote own role');
select throws_ok($$delete from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'$$,'42501',null,'Helper direct delete denied');
select throws_ok($$select * from private.command_requests$$,'42501',null,'Helper cannot read retry payloads');
select is((select count(*) from public.audit_events),0::bigint,'Helper cannot read audit endpoint');
reset role;
update public.jobs set lifecycle='closed' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
set local role authenticated;
select is((select count(*) from public.jobs),0::bigint,'Helper full job details stop at job closure');
reset role;
update public.jobs set lifecycle='open' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
set local role authenticated;

select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select is((select count(*) from public.jobs),1::bigint,'Lead sees assigned job only');
select is((select count(*) from public.audit_events),1::bigint,'Assigned lead can see existing job history');
select throws_ok($$select public.create_job('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Demo','2025550100','Fictional')$$,'42501','PM account required','Lead cannot create a customer job');

select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
select is((select count(*) from public.jobs),0::bigint,'Admin-only has no implicit PM access');

select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
select is((select count(*) from public.jobs),0::bigint,'Auth identity without invited app profile reads no jobs');
select throws_ok($$select public.create_job('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Demo','2025550100','Fictional')$$,'42501','PM account required','Uninvited identity cannot create');

select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
select is((select count(*) from public.jobs),0::bigint,'Inactive PM reads no jobs');
select throws_ok($$select public.create_job('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Demo','2025550100','Fictional')$$,'42501','PM account required','Inactive PM cannot create');

select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select is((select count(*) from public.jobs),2::bigint,'PM sees own and other PM jobs');
select throws_ok($$insert into public.jobs(customer_name) values('Raw insert')$$,'42501',null,'PM cannot bypass atomic command with direct insert');
select lives_ok($$select public.create_job('cccccccc-cccc-4ccc-8ccc-cccccccccccc','SYNTHETIC Created','(202) 555-0102','Fictional C')$$,'PM atomic create succeeds');
select is((select count(*) from public.jobs where customer_name='SYNTHETIC Created'),1::bigint,'One job created');
select is((select count(*) from public.work_items where job_id=(select id from public.jobs where customer_name='SYNTHETIC Created')),1::bigint,'Default work item created');
select is((select count(*) from public.audit_events where request_id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'),1::bigint,'One audit event created');
select lives_ok($$select public.create_job('cccccccc-cccc-4ccc-8ccc-cccccccccccc','SYNTHETIC Created','(202) 555-0102','Fictional C')$$,'Retry returns existing job');
select is((select count(*) from public.jobs where customer_name='SYNTHETIC Created'),1::bigint,'Retry does not duplicate job');
select is((select count(*) from public.audit_events where request_id='cccccccc-cccc-4ccc-8ccc-cccccccccccc'),1::bigint,'Retry does not duplicate audit');
select throws_ok($$select public.create_job('cccccccc-cccc-4ccc-8ccc-cccccccccccc','Different','2025550100','Fictional C')$$,'23505','Request payload changed','Different payload with same request rejected');
select throws_ok($$select public.create_job('dddddddd-dddd-4ddd-8ddd-dddddddddddd','','2025550100','Fictional D')$$,'22023','Invalid job details','Database independently rejects invalid fields');
select is((select count(*) from public.jobs),3::bigint,'Invalid command leaves no partial job');
select lives_ok($$select public.update_job('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','{"scope":"Updated by another PM"}')$$,'PM may edit another PM job');
select is((select title from public.jobs where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),'Demo B','Narrow patch preserves unrelated title');
select throws_ok($$select public.update_job('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','{"lifecycle":"closed"}')$$,'22023','Invalid patch field','Job closure cannot sneak through details patch');

-- Stale identity remains the same; live profile deactivation blocks the next request.
reset role;
update public.app_users set active=false where id='11111111-1111-4111-8111-111111111111';
set local role authenticated;
select is((select count(*) from public.jobs),0::bigint,'Existing PM token loses data access after deactivation');
reset role;
set local role anon;
select throws_ok($$select * from public.jobs$$,'42501',null,'Anonymous direct reads denied');
select throws_ok($$select public.create_job('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','Demo','2025550100','Fictional')$$,'42501',null,'Anonymous RPC denied');
reset role;
select * from finish();
rollback;
