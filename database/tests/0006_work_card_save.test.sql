-- Isolated test only, apply 0001-0006 first. All fixtures roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_batch_results(ordinal integer primary key,result text not null) on commit drop;
grant insert,select on pg_temp.eigsti_batch_results to authenticated,anon;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','batch-work-1@example.invalid'),
('22222222-2222-4222-8222-222222222222','batch-work-2@example.invalid'),
('33333333-3333-4333-8333-333333333333','batch-work-3@example.invalid'),
('44444444-4444-4444-8444-444444444444','batch-work-4@example.invalid'),
('55555555-5555-4555-8555-555555555555','batch-work-5@example.invalid'),
('66666666-6666-4666-8666-666666666666','batch-work-6@example.invalid'),
('77777777-7777-4777-8777-777777777777','batch-work-7@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC Batch 1',array['pm'],true),
('22222222-2222-4222-8222-222222222222','SYNTHETIC Batch 2',array['pm'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Batch 3',array['lead'],true),
('44444444-4444-4444-8444-444444444444','SYNTHETIC Batch 4',array['helper'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Batch 5',array['admin'],true),
('66666666-6666-4666-8666-666666666666','SYNTHETIC Batch 6',array['pm'],false),
('77777777-7777-4777-8777-777777777777','SYNTHETIC Batch 7',array['lead'],false);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,responsible_pm,created_by,updated_by)
select j,'SYNTHETIC Customer','3095550101','+13095550101','Fictional Lane','SYNTHETIC Batch','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111' from unnest(array['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'::uuid]) j;
insert into public.work_items(id,job_id,description,responsible_lead,created_by,updated_by) values
('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Cabinets',null,'11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Countertops','33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Other job',null,'11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_batch_results values(1,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"Must roll back"}},{"work_id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","patch":{"responsible_lead":"77777777-7777-4777-8777-777777777777"}}]')$test$,'22023','Active lead required','Invalid second portion aborts whole save'));
insert into pg_temp.eigsti_batch_results values(2,is((select count(*) from public.work_items where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and description='Cabinets'),1::bigint,'Earlier valid edit rolled back'));
insert into pg_temp.eigsti_batch_results values(3,is((select count(*) from public.audit_events where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),0::bigint,'Earlier audit edit rolled back'));
reset role;
insert into pg_temp.eigsti_batch_results values(4,is((select count(*) from private.command_requests where operation='update_job_work_batch'),0::bigint,'Failed batch leaves no receipt'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_batch_results values(5,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"New cabinets"}},{"work_id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","patch":{"responsible_lead":null}}]')$test$,'42501','PM account required','Role fixture 3 cannot batch edit'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_batch_results values(6,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"New cabinets"}},{"work_id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","patch":{"responsible_lead":null}}]')$test$,'42501','PM account required','Role fixture 4 cannot batch edit'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_batch_results values(7,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"New cabinets"}},{"work_id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","patch":{"responsible_lead":null}}]')$test$,'42501','PM account required','Role fixture 5 cannot batch edit'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
insert into pg_temp.eigsti_batch_results values(8,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"New cabinets"}},{"work_id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","patch":{"responsible_lead":null}}]')$test$,'42501','PM account required','Role fixture 6 cannot batch edit'));
reset role;
set local role anon;
insert into pg_temp.eigsti_batch_results values(9,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"New cabinets"}},{"work_id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","patch":{"responsible_lead":null}}]')$test$,'42501',null,'Anonymous batch execution denied'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_batch_results values(10,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[]')$test$,'22023','Invalid work changes','Empty array rejected'));
insert into pg_temp.eigsti_batch_results values(11,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{}}]')$test$,'22023','Invalid work details','Empty patch rejected'));
insert into pg_temp.eigsti_batch_results values(12,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"completion":"completed"}}]')$test$,'22023','Invalid work field','Privilege field rejected'));
insert into pg_temp.eigsti_batch_results values(13,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"New"},"actor_id":"22222222-2222-4222-8222-222222222222"}]')$test$,'22023','Invalid work changes','Forged batch actor rejected'));
insert into pg_temp.eigsti_batch_results values(14,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"New"}},{"work_id":"CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC","patch":{"responsible_lead":null}}]')$test$,'22023','Duplicate work change','Case-normalized duplicate IDs rejected'));
insert into pg_temp.eigsti_batch_results values(15,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"invalid","patch":{"description":"New"}}]')$test$,'22023','Invalid work changes','Malformed work ID rejected'));
insert into pg_temp.eigsti_batch_results values(16,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"Must roll back"}},{"work_id":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","patch":{"description":"Forged parent"}}]')$test$,'P0002','Work unavailable','Cross-job second portion aborts save'));
insert into pg_temp.eigsti_batch_results values(17,is((select count(*) from public.work_items where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and description='Cabinets'),1::bigint,'Forged parent leaves valid first portion unchanged'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_batch_results values(18,lives_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"responsible_lead":"33333333-3333-4333-8333-333333333333"}')$test$,'Other PM changes lead before stale description save'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_batch_results values(19,lives_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"New cabinets"}},{"work_id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","patch":{"responsible_lead":null}}]')$test$,'One batch updates two portions'));
insert into pg_temp.eigsti_batch_results values(20,is((select count(*) from public.work_items where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and description='New cabinets' and responsible_lead='33333333-3333-4333-8333-333333333333'),1::bigint,'Description patch retains newer lead'));
insert into pg_temp.eigsti_batch_results values(21,is((select count(*) from public.work_items where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd' and description='Countertops' and responsible_lead is null),1::bigint,'Lead clear retains other portion description'));
insert into pg_temp.eigsti_batch_results values(22,is((select count(*) from public.audit_events where operation='update_job_work_batch' and actor_id='11111111-1111-4111-8111-111111111111' and request_id='ffffffff-ffff-4fff-8fff-ffffffffffff'),1::bigint,'Batch receipt is audited once'));
insert into pg_temp.eigsti_batch_results values(23,lives_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","patch":{"responsible_lead":null}},{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"New cabinets"}}]')$test$,'Reordered identical payload replays safely'));
insert into pg_temp.eigsti_batch_results values(24,is((select count(*) from public.audit_events where operation='update_job_work_batch' and actor_id='11111111-1111-4111-8111-111111111111' and request_id='ffffffff-ffff-4fff-8fff-ffffffffffff'),1::bigint,'Retry creates no extra batch audit'));
insert into pg_temp.eigsti_batch_results values(25,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"Different"}}]')$test$,'23505','Request payload changed','Changed retry payload rejected'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_batch_results values(26,lives_ok($test$select public.update_job_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc','{"description":"Newer save"}')$test$,'Later PM save succeeds'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_batch_results values(27,lives_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"New cabinets"}},{"work_id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","patch":{"responsible_lead":null}}]')$test$,'Lost-response retry confirms original receipt'));
insert into pg_temp.eigsti_batch_results values(28,is((select count(*) from public.work_items where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and description='Newer save'),1::bigint,'Old batch retry never overwrites newer save'));
insert into pg_temp.eigsti_batch_results values(29,ok((public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"New cabinets"}},{"work_id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","patch":{"responsible_lead":null}}]')->'work') @> '[{"id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","description":"Newer save"}]'::jsonb,'Retry response returns actual current work'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_batch_results values(30,lives_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"Other PM"}}]')$test$,'Retry IDs are scoped to actor'));
reset role;
update public.work_items set completion='completed' where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_batch_results values(31,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffff01','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"Partial update"}},{"work_id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","patch":{"description":"Completed rewrite"}}]')$test$,'22023','Open work required','Completed second portion aborts all changes'));
insert into pg_temp.eigsti_batch_results values(32,is((select count(*) from public.work_items where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and description='Other PM'),1::bigint,'Completed-work failure preserves first portion'));
insert into pg_temp.eigsti_batch_results values(33,is((select count(*) from public.audit_events where operation='update_job_work_batch' and request_id='ffffffff-ffff-4fff-8fff-ffffffffff01'),0::bigint,'Aborted card save has no summary audit'));
reset role;
update public.jobs set lifecycle='closed' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_batch_results values(34,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffff02','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"Closed rewrite"}}]')$test$,'P0002','Open job required','New batch on closed job denied'));
insert into pg_temp.eigsti_batch_results values(35,lives_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff','[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"New cabinets"}},{"work_id":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","patch":{"responsible_lead":null}}]')$test$,'Original successful receipt may be confirmed after job closure'));
insert into pg_temp.eigsti_batch_results values(36,is((select count(*) from public.work_items where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and description='Other PM'),1::bigint,'Closed-job retry does not replay mutations'));
insert into pg_temp.eigsti_batch_results values(37,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffff03','{}')$test$,'22023','Invalid work changes','Object instead of array rejected'));
insert into pg_temp.eigsti_batch_results values(38,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffff03',null)$test$,'22023','Invalid work changes','Null changes rejected'));
insert into pg_temp.eigsti_batch_results values(39,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',null,'[{"work_id":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","patch":{"description":"New"}}]')$test$,'22023','Invalid work changes','Missing retry identifier rejected'));
insert into pg_temp.eigsti_batch_results values(40,throws_ok($test$select public.update_job_work_batch('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffff03',(select jsonb_agg(jsonb_build_object('work_id','cccccccc-cccc-4ccc-8ccc-cccccccccccc','patch',jsonb_build_object('description','New'))) from generate_series(1,101)))$test$,'22023','Invalid work changes','Batch count bound enforced'));
reset role;
do $validation$
declare v_failures text;
begin
 if (select count(*) from pg_temp.eigsti_batch_results)<>40 then raise exception 'Incomplete batch tests: expected 40'; end if;
 select string_agg(result,E'\n' order by ordinal) into v_failures from pg_temp.eigsti_batch_results where result not like 'ok %';
 if v_failures is not null then raise exception 'Batch tests failed: %',v_failures; end if;
end;
$validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_batch_results;
rollback;
