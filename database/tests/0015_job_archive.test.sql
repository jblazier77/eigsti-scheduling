-- Isolated test project only. Every synthetic fixture rolls back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_archive_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_archive_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_archive_results,pg_temp.eigsti_archive_ids to authenticated;
grant usage on sequence pg_temp.eigsti_archive_results_ordinal_seq to authenticated;
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
insert into public.job_files(id,job_id,filename,mime_type,byte_size,status,created_by,updated_by) values('fafafafa-fafa-4afa-8afa-fafafafafafa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC history.pdf','application/pdf',1,'ready','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into public.visits(id,work_item_id,coordinator_id,start_date,end_date,slot,created_by,updated_by)
select 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa',id,'33333333-3333-4333-8333-333333333333',(date_trunc('week',now() at time zone 'America/Chicago')::date-7),(date_trunc('week',now() at time zone 'America/Chicago')::date-7),'day','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111' from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
insert into public.visits(id,work_item_id,coordinator_id,start_date,end_date,slot,created_by,updated_by)
select 'aaaaaaaa-2222-4222-8222-aaaaaaaaaaaa',id,'33333333-3333-4333-8333-333333333333',(date_trunc('week',now() at time zone 'America/Chicago')::date+7),(date_trunc('week',now() at time zone 'America/Chicago')::date+7),'day','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111' from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
insert into public.visit_participants(visit_id,user_id,duty) values('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa','33333333-3333-4333-8333-333333333333','leading'),('aaaaaaaa-2222-4222-8222-aaaaaaaaaaaa','33333333-3333-4333-8333-333333333333','leading');
create function pg_temp.archive(r uuid,a text default 'archive',e text default 'open') returns jsonb language sql as $$select public.set_job_archive('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',r,a,e);$$;
create function pg_temp.past_calendar() returns jsonb language sql as $$select public.list_schedule(date_trunc('week',now() at time zone 'America/Chicago')::date-7,date_trunc('week',now() at time zone 'America/Chicago')::date-7,false);$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_archive_results(result) values(throws_ok($t$select pg_temp.archive(gen_random_uuid())$t$,'22023','Resolve today or future crew dates before archiving this job.','Future crew plan blocks archive without finishing work'));
insert into pg_temp.eigsti_archive_results(result) values(is((select lifecycle from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'open','Blocked archive leaves job active'));
reset role;
update public.visits set state='cancelled' where id='aaaaaaaa-2222-4222-8222-aaaaaaaaaaaa';
insert into public.contact_commitments(job_id,contact_id,commitment_date,note,created_by,updated_by) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc',(now() at time zone 'America/Chicago')::date,'SYNTHETIC Today promise','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
set local role authenticated;
insert into pg_temp.eigsti_archive_results(result) values(throws_ok($t$select pg_temp.archive(gen_random_uuid())$t$,'22023','Resolve today or future subcontractor commitments before archiving this job.','Today subcontractor promise blocks archive'));
reset role;
update public.contact_commitments set commitment_date=null where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
set local role authenticated;
insert into pg_temp.eigsti_archive_results(result) values(is(jsonb_array_length(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items'),1,'Open work begins in lead queue'));
insert into pg_temp.eigsti_archive_results(result) values(lives_ok($t$select pg_temp.archive('abcdefab-cdef-4abc-8abc-000000000001')$t$,'Past plans and unfinished work do not require daily check-offs'));
insert into pg_temp.eigsti_archive_results(result) values(is((select lifecycle from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'archived','Job archived'));
insert into pg_temp.eigsti_archive_results(result) values(is(jsonb_array_length(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items'),0,'Archived work leaves active queue'));
insert into pg_temp.eigsti_archive_results(result) values(is(jsonb_array_length(pg_temp.past_calendar()),0,'Archived history leaves operational calendar'));
insert into pg_temp.eigsti_archive_results(result) values(is(jsonb_array_length(public.list_job_visits('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')),2,'Past and cancelled entries remain on same job'));
insert into pg_temp.eigsti_archive_results(result) values(is((select count(*) from public.job_contacts where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),2::bigint,'Contacts retained'));
insert into pg_temp.eigsti_archive_results(result) values(is((select count(*) from public.job_files where id='fafafafa-fafa-4afa-8afa-fafafafafafa' and status='ready'),1::bigint,'File metadata and object path retained'));
insert into pg_temp.eigsti_archive_results(result) values(is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and completion='open'),1::bigint,'Work state and ownership are not marked complete'));
insert into pg_temp.eigsti_archive_results(result) values(lives_ok($t$select pg_temp.archive('abcdefab-cdef-4abc-8abc-000000000001')$t$,'Archive retry acknowledges original save'));
insert into pg_temp.eigsti_archive_results(result) values(throws_ok($t$select pg_temp.archive('abcdefab-cdef-4abc-8abc-000000000001','restore','archived')$t$,'23505','Request payload changed','Changed retry rejected'));
insert into pg_temp.eigsti_archive_results(result) values(throws_ok($t$select public.create_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'{"description":"SYNTHETIC Not yet","responsible_lead":null}')$t$,'P0002',null,'Restore required before new work'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_archive_results(result) values(throws_ok($t$select pg_temp.archive(gen_random_uuid(),'restore','archived')$t$,'42501','PM account required','Lead cannot restore or archive'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_archive_results(result) values(throws_ok($t$select pg_temp.archive(gen_random_uuid(),'restore','archived')$t$,'42501','PM account required','Helper cannot restore'));
insert into pg_temp.eigsti_archive_results(result) values(is((select count(*) from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),0::bigint,'Historical helper assignment does not expose archived job'));
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_archive_results(result) values(throws_ok($t$select pg_temp.archive(gen_random_uuid(),'restore','archived')$t$,'42501','PM account required','Admin-only cannot restore'));
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_archive_results(result) values(lives_ok($t$select pg_temp.archive('abcdefab-cdef-4abc-8abc-000000000002','restore','archived')$t$,'Another PM may restore same job'));
insert into pg_temp.eigsti_archive_results(result) values(is((select lifecycle from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'open','Restore reopens same job identity'));
insert into pg_temp.eigsti_archive_results(result) values(is(jsonb_array_length(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items'),1,'Existing open work returns to its queue'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_archive_results(result) values(lives_ok($t$select pg_temp.archive('abcdefab-cdef-4abc-8abc-000000000001')$t$,'Old archive retry after restore is acknowledgement only'));
insert into pg_temp.eigsti_archive_results(result) values(is((select lifecycle from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'open','Old retry cannot archive restored job again'));
insert into pg_temp.eigsti_archive_results(result) values(throws_ok($t$select pg_temp.archive(gen_random_uuid(),'archive','archived')$t$,'22023','Job status changed. Refresh the job before trying again.','Stale expected status rejected'));
insert into pg_temp.eigsti_archive_results(result) values(lives_ok($t$select public.create_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'{"description":"SYNTHETIC Punch list","responsible_lead":"33333333-3333-4333-8333-333333333333"}')$t$,'New punch-list work uses ordinary Add work after restore'));
insert into pg_temp.eigsti_archive_results(result) values(is((select count(*) from public.work_items where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),2::bigint,'Additional work shares original job'));
insert into pg_temp.eigsti_archive_results(result) values(is(jsonb_array_length(pg_temp.past_calendar()),1,'Historical planned date remains available when job is restored'));
insert into pg_temp.eigsti_archive_results(result) values(lives_ok($t$select pg_temp.archive(gen_random_uuid())$t$,'Job can be archived again with undated punch list'));
reset role;
insert into pg_temp.eigsti_archive_results(result) values(is((select count(*) from private.job_archive_events where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),3::bigint,'Only real state transitions have private history'));
insert into pg_temp.eigsti_archive_results(result) values(is((select count(*) from public.audit_events where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' and operation='set_job_archive'),3::bigint,'Retries do not duplicate audit effects'));
insert into pg_temp.eigsti_archive_results(result) values(ok(not has_table_privilege('authenticated','public.jobs','UPDATE'),'Direct lifecycle writes remain denied'));
insert into pg_temp.eigsti_archive_results(result) values(ok(not has_table_privilege('authenticated','private.job_archive_events','SELECT'),'Private lifecycle snapshots stay private'));
insert into pg_temp.eigsti_archive_results(result) values(ok(not has_function_privilege('anon','public.set_job_archive(uuid,uuid,text,text)','EXECUTE'),'Anonymous lifecycle command denied'));
update public.app_users set active=false where id='11111111-1111-4111-8111-111111111111';
set local role authenticated;
insert into pg_temp.eigsti_archive_results(result) values(throws_ok($t$select pg_temp.archive(gen_random_uuid(),'restore','archived')$t$,'42501','PM account required','Inactive PM cannot restore'));
reset role;
do $validation$
declare failures text;
begin
 select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_archive_results where result not like 'ok %';
 if failures is not null then raise exception 'Archive checks failed: %',failures; end if;
end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_archive_results;
rollback;