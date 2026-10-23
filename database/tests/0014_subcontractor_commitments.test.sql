-- Isolated test project only. Every synthetic fixture rolls back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_commitment_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_commitment_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_commitment_results,pg_temp.eigsti_commitment_ids to authenticated;
grant usage on sequence pg_temp.eigsti_commitment_results_ordinal_seq to authenticated;
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
create function pg_temp.promise(r uuid,d text default '2026-10-24',n text default 'Clear cabinet for plumber',i uuid default null) returns jsonb language sql as $$select public.save_contact_commitment('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc',i,r,jsonb_build_object('commitment_date',d,'note',n),false);$$;
create function pg_temp.new_contact(r uuid,c jsonb default '{"commitment_date":"2026-10-25","note":"Delivery access"}') returns jsonb language sql as $$select public.create_contact_with_commitment('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',r,'{"name":"SYNTHETIC Electrician","relationship":"Subcontractor","phone":"","email":"","notes":""}',c);$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_commitment_results(result) values(is(jsonb_array_length(public.job_contact_commitments('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')->'items'),0,'Contacts need no commitment'));
insert into pg_temp.eigsti_commitment_ids select 'promise',(pg_temp.promise('abcdefab-cdef-4abc-8abc-000000000001')->>'id')::uuid;
insert into pg_temp.eigsti_commitment_results(result) values(is(jsonb_array_length(public.list_contact_commitments('2026-10-24','2026-10-24')),1,'Weekend promise appears without a crew visit'));
insert into pg_temp.eigsti_commitment_results(result) values(lives_ok($t$select pg_temp.promise('abcdefab-cdef-4abc-8abc-000000000001')$t$,'Exact create retry succeeds'));
insert into pg_temp.eigsti_commitment_results(result) values(is(jsonb_array_length(public.job_contact_commitments('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')->'items'),1,'Create retry does not duplicate'));
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select pg_temp.promise('abcdefab-cdef-4abc-8abc-000000000001','2026-10-25')$t$,'23505','Request payload changed','Changed retry rejected'));
insert into pg_temp.eigsti_commitment_results(result) values(lives_ok($t$select pg_temp.promise(gen_random_uuid(),null,'Order still being arranged')$t$,'Note without date is allowed'));
insert into pg_temp.eigsti_commitment_results(result) values(is(jsonb_array_length(public.list_contact_commitments('2026-10-01','2026-10-31')),1,'Undated note has no calendar marker'));
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select pg_temp.promise(gen_random_uuid(),null,' ')$t$,'22023',null,'Blank commitment rejected'));
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select pg_temp.promise(gen_random_uuid(),'2026-02-30')$t$,'22008',null,'Impossible date rejected'));
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select pg_temp.promise(gen_random_uuid(),'2026-10-24',repeat('a',2001))$t$,'22023',null,'Oversized note rejected'));
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select public.save_contact_commitment('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','dddddddd-dddd-4ddd-8ddd-dddddddddddd',null,gen_random_uuid(),'{"commitment_date":"2026-10-24","note":""}')$t$,'22023',null,'Customer is not a subcontractor'));
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select public.save_contact_commitment('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',null,gen_random_uuid(),'{"commitment_date":"2026-10-24","note":""}')$t$,'P0002',null,'Cross-job contact rejected'));
insert into pg_temp.eigsti_commitment_results(result) values(lives_ok($t$select pg_temp.new_contact('abcdefab-cdef-4abc-8abc-000000000002')$t$,'New contact and first promise save together'));
insert into pg_temp.eigsti_commitment_results(result) values(lives_ok($t$select pg_temp.new_contact('abcdefab-cdef-4abc-8abc-000000000002')$t$,'Combined command retry succeeds'));
insert into pg_temp.eigsti_commitment_results(result) values(is((select count(*) from public.job_contacts where name='SYNTHETIC Electrician'),1::bigint,'Combined retry has one contact'));
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select pg_temp.new_contact(gen_random_uuid(),'{"commitment_date":null,"note":""}')$t$,'22023',null,'Bad first promise rejects whole command'));
insert into pg_temp.eigsti_commitment_results(result) values(is((select count(*) from public.job_contacts where name='SYNTHETIC Electrician'),1::bigint,'Failed first promise leaves no partial contact'));
insert into pg_temp.eigsti_commitment_results(result) values(lives_ok($t$select public.save_contact_commitment('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',null,gen_random_uuid(),'{"commitment_date":"2026-10-24","note":"Other job"}')$t$,'PM can plan another PM job'));
insert into pg_temp.eigsti_commitment_results(result) values(is(jsonb_array_length(public.list_contact_commitments('2026-10-01','2026-10-31',false)),2,'PM plus lead role still respects My jobs'));
insert into pg_temp.eigsti_commitment_results(result) values(is(jsonb_array_length(public.list_contact_commitments('2026-10-01','2026-10-31',true)),3,'All jobs includes other PM commitments'));
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select public.list_contact_commitments('2026-10-01','2026-11-01')$t$,'22023',null,'Calendar RPC stays bounded to 31 days'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_commitment_results(result) values(ok((public.job_contact_commitments('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')->>'can_manage')::boolean,'Assigned lead can manage job promises'));
insert into pg_temp.eigsti_commitment_results(result) values(lives_ok($t$select pg_temp.promise(gen_random_uuid(),'2026-10-26','Lead follow-up')$t$,'Assigned lead can add promise'));
insert into pg_temp.eigsti_commitment_results(result) values(is(jsonb_array_length(public.list_contact_commitments('2026-10-01','2026-10-31',true)),3,'Lead cannot use All to expose another job'));
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select pg_temp.promise(gen_random_uuid())$t$,'42501',null,'Unassigned lead cannot write'));
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select public.job_contact_commitments('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$t$,'42501',null,'Unassigned lead cannot read contacts promises'));
insert into pg_temp.eigsti_commitment_results(result) values(is(jsonb_array_length(public.list_contact_commitments('2026-10-01','2026-10-31')),0,'Unassigned lead calendar leaks nothing'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_commitment_results(result) values(ok(not (public.job_contact_commitments('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')->>'can_manage')::boolean,'Helper job access remains read only'));
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select pg_temp.promise(gen_random_uuid())$t$,'42501',null,'Helper cannot write'));
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select public.list_contact_commitments('2026-10-01','2026-10-31')$t$,'42501',null,'Helper calendar does not expose planner promises'));
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select pg_temp.promise(gen_random_uuid())$t$,'42501',null,'Admin-only cannot write'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_commitment_results(result) values(lives_ok($t$select pg_temp.promise(gen_random_uuid(),null,'Reschedule later',(select id from pg_temp.eigsti_commitment_ids where label='promise'))$t$,'Date can be cleared while retaining note'));
insert into pg_temp.eigsti_commitment_results(result) values(is(jsonb_array_length(public.list_contact_commitments('2026-10-24','2026-10-24')),0,'Cleared date removes My jobs marker'));
insert into pg_temp.eigsti_commitment_results(result) values(lives_ok($t$select public.save_contact_commitment('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc',(select id from pg_temp.eigsti_commitment_ids where label='promise'),'abcdefab-cdef-4abc-8abc-000000000003','{}',true)$t$,'Removal archives promise'));
insert into pg_temp.eigsti_commitment_results(result) values(lives_ok($t$select public.save_contact_commitment('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc',(select id from pg_temp.eigsti_commitment_ids where label='promise'),'abcdefab-cdef-4abc-8abc-000000000003','{}',true)$t$,'Removal retry is idempotent'));
insert into pg_temp.eigsti_commitment_results(result) values(lives_ok($t$select pg_temp.promise('abcdefab-cdef-4abc-8abc-000000000001')$t$,'Old creation retry acknowledges after removal'));
reset role;
insert into pg_temp.eigsti_commitment_results(result) values(ok((select archived_at is not null from public.contact_commitments where id=(select id from pg_temp.eigsti_commitment_ids where label='promise')),'Old retry never resurrects removed promise'));
insert into pg_temp.eigsti_commitment_results(result) values(is((select count(*) from public.visits v join public.work_items w on w.id=v.work_item_id where w.job_id in ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')),0::bigint,'Commitments create no crew visits or staffing reservations'));
update public.job_contacts set relationship='Site contact' where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
insert into pg_temp.eigsti_commitment_results(result) values(is((select count(*) from public.contact_commitments where contact_id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and archived_at is null),0::bigint,'Changing type archives its promises'));
update public.job_contacts set relationship='Subcontractor' where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
insert into pg_temp.eigsti_commitment_results(result) values(is((select count(*) from public.contact_commitments where contact_id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and archived_at is null),0::bigint,'Changing type back does not resurrect promises'));
update public.job_contacts set archived_at=now() where name='SYNTHETIC Electrician';
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_commitment_results(result) values(is(jsonb_array_length(public.list_contact_commitments('2026-10-01','2026-10-31')),0,'Archived contact removes its calendar marker'));
reset role;
update public.jobs set lifecycle='closed' where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
set local role authenticated;
insert into pg_temp.eigsti_commitment_results(result) values(is(jsonb_array_length(public.list_contact_commitments('2026-10-01','2026-10-31',true)),0,'Closed jobs have no future commitment marker'));
reset role;
update public.app_users set active=false where id='11111111-1111-4111-8111-111111111111';
set local role authenticated;
insert into pg_temp.eigsti_commitment_results(result) values(throws_ok($t$select pg_temp.promise(gen_random_uuid())$t$,'42501',null,'Deactivated planner cannot write'));
reset role;
insert into pg_temp.eigsti_commitment_results(result) values(ok(not has_table_privilege('authenticated','public.contact_commitments','SELECT'),'No direct commitment table read'));
insert into pg_temp.eigsti_commitment_results(result) values(ok(not has_table_privilege('authenticated','public.contact_commitments','UPDATE'),'No direct commitment table write'));
insert into pg_temp.eigsti_commitment_results(result) values(ok(not has_table_privilege('authenticated','private.contact_commitment_events','SELECT'),'Private history stays private'));
insert into pg_temp.eigsti_commitment_results(result) values(ok(not has_function_privilege('anon','public.list_contact_commitments(date,date,boolean)','EXECUTE'),'Anonymous calendar access denied'));
insert into pg_temp.eigsti_commitment_results(result) values(ok(exists(select 1 from private.contact_commitment_events where operation='contact_unavailable'),'Contact changes retain history'));
do $validation$
declare failures text;
begin
 select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_commitment_results where result not like 'ok %';
 if failures is not null then raise exception 'Commitment checks failed: %',failures; end if;
end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_commitment_results;
rollback;


