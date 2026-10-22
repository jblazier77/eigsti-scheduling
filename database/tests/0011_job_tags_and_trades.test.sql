-- Test project only. Fictional fixtures; every change rolls back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_tag_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_tag_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_tag_results,pg_temp.eigsti_tag_ids to authenticated,anon;
grant usage on sequence pg_temp.eigsti_tag_results_ordinal_seq to authenticated,anon;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','tags-pm@example.invalid'),
('33333333-3333-4333-8333-333333333333','tags-lead@example.invalid'),
('55555555-5555-4555-8555-555555555555','tags-helper@example.invalid'),
('77777777-7777-4777-8777-777777777777','tags-admin@example.invalid'),
('88888888-8888-4888-8888-888888888888','tags-inactive@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC PM',array['pm'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Lead',array['lead'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Helper',array['helper'],true),
('77777777-7777-4777-8777-777777777777','SYNTHETIC Admin',array['admin'],true),
('88888888-8888-4888-8888-888888888888','SYNTHETIC Disabled',array['pm','admin'],false);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,scope,access_notes,responsible_pm,created_by,updated_by) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Customer','3095550101','+13095550101','Fictional Lane','SYNTHETIC Tags','Keep scope','Keep access','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC Other','3095550102','+13095550102','Other Fictional Lane','SYNTHETIC Hidden','','','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into public.work_items(id,job_id,description,responsible_lead,created_by,updated_by) values
('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Work','33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
create function pg_temp.tag(p jsonb,r uuid default gen_random_uuid()) returns jsonb language sql as $$select public.save_job_classification('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',r,p);$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_tag_results(result) values(ok((select not rain_day and not filler and not whole_house and cardinality(trades)=0 from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Existing jobs start without invented tags/scopes'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select pg_temp.tag('{"rain_day":true,"filler":true,"trades":["plumbing","electrical"]}','abcdefab-cdef-4abc-8abc-000000000001')$t$,'PM saves independent tags and trades'));
insert into pg_temp.eigsti_tag_results(result) values(ok((select rain_day and filler and not whole_house and trades=array['electrical','plumbing']::text[] from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Trades canonicalized; both tags retained'));
insert into pg_temp.eigsti_tag_results(result) values(is((select scope||'/'||access_notes from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Keep scope/Keep access','Tags preserve unrelated job details'));
insert into pg_temp.eigsti_tag_results(result) values(is((select readiness||'/'||completion from public.work_items where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd'),'ready/open','Tags do not confirm or finish work'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select pg_temp.tag('{"rain_day":false}')$t$,'Narrow patch clears only rain tag'));
insert into pg_temp.eigsti_tag_results(result) values(ok((select filler and not rain_day and cardinality(trades)=2 from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Filler/scopes survive independent rain edit'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select pg_temp.tag('{"trades":["electrical","plumbing"],"filler":true,"rain_day":true}','abcdefab-cdef-4abc-8abc-000000000001')$t$,'Canonical retry acknowledged'));
insert into pg_temp.eigsti_tag_results(result) values(ok((select not rain_day from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Old retry does not undo newer tag change'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"rain_day":false}','abcdefab-cdef-4abc-8abc-000000000001')$t$,'23505','Request payload changed','Changed retry rejected'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"trades":["roofing","roofing"]}')$t$,'22023','Invalid trades','Duplicate trade rejected'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"trades":["invented"]}')$t$,'22023','Invalid trades','Unknown trade rejected'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"trades":[null]}')$t$,'22023','Invalid trades','Null trade rejected'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"filler":"true"}')$t$,'22023','Invalid job tags','Boolean strings rejected'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"responsible_pm":null}')$t$,'22023','Invalid job tags','Privilege fields rejected'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select pg_temp.tag('{"whole_house":true}')$t$,'Whole house selected explicitly'));
insert into pg_temp.eigsti_tag_results(result) values(is((select cardinality(trades) from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),2::integer,'Whole house does not invent every trade'));
insert into pg_temp.eigsti_tag_ids values('filler',(public.create_classified_job('abcdefab-cdef-4abc-8abc-000000000002','SYNTHETIC Filler','3095550103','Fictional Filler Lane','{"filler":true,"rain_day":true}') ->>'id')::uuid);
insert into pg_temp.eigsti_tag_results(result) values(ok((select filler and rain_day and lifecycle='open' from public.jobs where id=(select id from pg_temp.eigsti_tag_ids where label='filler')),'Standalone filler is an ordinary open job'));
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.work_items where job_id=(select id from pg_temp.eigsti_tag_ids where label='filler')),1::bigint,'Filler creates one ordinary work portion'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select public.create_classified_job('abcdefab-cdef-4abc-8abc-000000000002','SYNTHETIC Filler','3095550103','Fictional Filler Lane','{"rain_day":true,"filler":true}')$t$,'Create retry uses original identity'));
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.jobs where customer_name='SYNTHETIC Filler'),1::bigint,'Create retry does not duplicate job'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select public.create_classified_job('abcdefab-cdef-4abc-8abc-000000000002','SYNTHETIC Filler','3095550103','Fictional Filler Lane','{"filler":false}')$t$,'23505','Request payload changed','Create cannot reuse request with different tags'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select public.create_classified_job(gen_random_uuid(),'SYNTHETIC Invalid','3095550104','Fictional Lane','{"trades":["unknown"]}')$t$,'22023','Invalid trades','Invalid classification prevents job creation'));
insert into pg_temp.eigsti_tag_ids values('sub',(public.save_subcontractor(null,'abcdefab-cdef-4abc-8abc-000000000003','{"name":"SYNTHETIC Trades","phone":"3095550105","email":"trade@example.invalid","trades":["painting","drywall"]}')->>'id')::uuid);
insert into pg_temp.eigsti_tag_results(result) values(is((select cardinality(trades) from public.subcontractors where id=(select id from pg_temp.eigsti_tag_ids where label='sub')),2::integer,'Subcontractor supports multiple trades'));
insert into pg_temp.eigsti_tag_results(result) values(is((select phone_action from public.subcontractors where id=(select id from pg_temp.eigsti_tag_ids where label='sub')),'+13095550105','Readable phone has callable value'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select public.save_subcontractor((select id from pg_temp.eigsti_tag_ids where label='sub'),gen_random_uuid(),'{"trades":["roofing"]}')$t$,'Directory trade edit is narrow'));
insert into pg_temp.eigsti_tag_results(result) values(is((select name||'/'||phone from public.subcontractors where id=(select id from pg_temp.eigsti_tag_ids where label='sub')),'SYNTHETIC Trades/3095550105','Trade edit preserves name/phone'));
insert into pg_temp.eigsti_tag_results(result) values(ok((select trades=array['electrical','plumbing']::text[] from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Directory edit does not add scopes to project'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select public.save_subcontractor(null,gen_random_uuid(),'{"name":"X","phone":"","email":"bad","trades":[]}')$t$,'22023','Invalid subcontractor','Invalid directory email rejected'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$update public.jobs set filler=false$t$,'42501',null,'Direct job metadata overwrite denied'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$update public.subcontractors set name='forged'$t$,'42501',null,'Direct directory overwrite denied'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.jobs where filler),1::bigint,'Lead sees only owned tagged job, not unassigned filler'));
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.subcontractors where id=(select id from pg_temp.eigsti_tag_ids where label='sub')),1::bigint,'Lead can read trade directory'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"rain_day":true}')$t$,'42501','PM account required','Lead cannot edit job classification'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select public.save_subcontractor(null,gen_random_uuid(),'{"name":"X","phone":"","email":"","trades":[]}')$t$,'42501','Directory manager required','Lead cannot edit global directory'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.jobs where filler),0::bigint,'Unassigned helper cannot browse filler customer data'));
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.subcontractors),0::bigint,'Helper cannot browse global directory'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"filler":true}')$t$,'42501','PM account required','Helper cannot forge tag save'));
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"filler":true}')$t$,'42501','PM account required','Admin alone is not a project manager'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select public.save_subcontractor((select id from pg_temp.eigsti_tag_ids where label='sub'),gen_random_uuid(),'{"email":""}')$t$,'Admin manages directory and clears optional field'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select public.save_subcontractor((select id from pg_temp.eigsti_tag_ids where label='sub'),'abcdefab-cdef-4abc-8abc-000000000004','{"archive":true}')$t$,'Directory archive retains identity'));
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.subcontractors where id=(select id from pg_temp.eigsti_tag_ids where label='sub')),0::bigint,'Archived contact hidden from directory'));
insert into pg_temp.eigsti_tag_results(result) values(lives_ok($t$select public.save_subcontractor((select id from pg_temp.eigsti_tag_ids where label='sub'),'abcdefab-cdef-4abc-8abc-000000000004','{"archive":true}')$t$,'Archive retry acknowledged without restoring contact'));
select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select public.save_subcontractor(null,gen_random_uuid(),'{"name":"X","phone":"","email":"","trades":[]}')$t$,'42501','Directory manager required','Disabled manager denied'));
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select pg_temp.tag('{"filler":true}')$t$,'42501','PM account required','Disabled PM denied'));
set local role anon;
insert into pg_temp.eigsti_tag_results(result) values(throws_ok($t$select public.save_job_classification('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'{"filler":true}')$t$,'42501',null,'Anonymous RPC denied'));
reset role;
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.visits v join public.work_items w on w.id=v.work_item_id where w.job_id in ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',(select id from pg_temp.eigsti_tag_ids where label='filler'))),0::bigint,'Tags and filler creation never book a date or staff'));
insert into pg_temp.eigsti_tag_results(result) values(is((select count(*) from public.jobs where customer_name='SYNTHETIC Invalid'),0::bigint,'Invalid creation leaves no job behind'));
insert into pg_temp.eigsti_tag_results(result) values(ok(exists(select 1 from private.classification_events where before_state->>'rain_day'='true' and after_state->>'rain_day'='false'),'Job classification before/after history retained'));
insert into pg_temp.eigsti_tag_results(result) values(ok(exists(select 1 from private.subcontractor_events where subcontractor_id=(select id from pg_temp.eigsti_tag_ids where label='sub') and after_state->>'archived_at' is not null),'Directory archive history retained'));
insert into pg_temp.eigsti_tag_results(result) values(ok(not has_table_privilege('authenticated','private.classification_events','UPDATE') and not has_table_privilege('authenticated','private.subcontractor_events','DELETE'),'Employees cannot alter metadata history'));
do $validation$
declare failures text;
begin
 if (select count(*) from pg_temp.eigsti_tag_results)<>51 then raise exception 'Incomplete tag checks: expected 51'; end if;
 select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_tag_results where result not like 'ok %';
 if failures is not null then raise exception 'Tag/trade checks failed: %',failures; end if;
end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_tag_results;
rollback;
