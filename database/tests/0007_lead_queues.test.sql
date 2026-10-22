-- Isolated test only; apply 0001-0007. All fixtures roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_queue_results(ordinal integer primary key,result text not null) on commit drop;
create temporary table eigsti_queue_snapshot(revision bigint,event_count bigint) on commit drop;
grant insert,select on pg_temp.eigsti_queue_results to authenticated,anon;
grant select on pg_temp.eigsti_queue_snapshot to authenticated;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','queue-test-1@example.invalid'),
('22222222-2222-4222-8222-222222222222','queue-test-2@example.invalid'),
('33333333-3333-4333-8333-333333333333','queue-test-3@example.invalid'),
('44444444-4444-4444-8444-444444444444','queue-test-4@example.invalid'),
('55555555-5555-4555-8555-555555555555','queue-test-5@example.invalid'),
('66666666-6666-4666-8666-666666666666','queue-test-6@example.invalid'),
('77777777-7777-4777-8777-777777777777','queue-test-7@example.invalid'),
('88888888-8888-4888-8888-888888888888','queue-test-8@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC Queue 1',array['pm'],true),
('22222222-2222-4222-8222-222222222222','SYNTHETIC Queue 2',array['pm'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Queue 3',array['lead'],true),
('44444444-4444-4444-8444-444444444444','SYNTHETIC Queue 4',array['lead'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Queue 5',array['helper'],true),
('66666666-6666-4666-8666-666666666666','SYNTHETIC Queue 6',array['admin'],true),
('77777777-7777-4777-8777-777777777777','SYNTHETIC Queue 7',array['lead'],false),
('88888888-8888-4888-8888-888888888888','SYNTHETIC Queue 8',array['pm'],false);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,responsible_pm,lifecycle,created_by,updated_by) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Customer','3095550101','+13095550101','Fictional Lane','SYNTHETIC Queue Job','11111111-1111-4111-8111-111111111111','open','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC Customer','3095550101','+13095550101','Fictional Lane','SYNTHETIC Queue Job','22222222-2222-4222-8222-222222222222','open','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222'),
('cccccccc-cccc-4ccc-8ccc-cccccccccccc','SYNTHETIC Customer','3095550101','+13095550101','Fictional Lane','SYNTHETIC Queue Job','11111111-1111-4111-8111-111111111111','closed','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into public.work_items(id,job_id,description,responsible_lead,readiness,created_at,created_by,updated_by) values
('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Cabinets','33333333-3333-4333-8333-333333333333','ready','2026-10-01','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Countertops','33333333-3333-4333-8333-333333333333','ready','2026-10-02','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Framing','44444444-4444-4444-8444-444444444444','ready','2026-10-03','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('99999999-9999-4999-8999-999999999999','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Waiting work','33333333-3333-4333-8333-333333333333','waiting_unknown','2026-10-03','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
('12345678-1234-4234-8234-123456789abc','cccccccc-cccc-4ccc-8ccc-cccccccccccc','Closed job work','33333333-3333-4333-8333-333333333333','ready','2026-09-01','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into public.job_contacts(id,job_id,name,notes,created_by,updated_by) values('87654321-1234-4234-8234-123456789abc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Queue Contact','Original','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_queue_results values(1,is((select jsonb_array_length(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items')),3::integer,'Only open owned work appears; waiting stays queued'));
insert into pg_temp.eigsti_queue_results values(2,is((select array_agg(v->>'id' order by pos) from jsonb_array_elements(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') with ordinality e(v,pos)),array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','99999999-9999-4999-8999-999999999999']::text[],'Initial membership follows creation order'));
insert into pg_temp.eigsti_queue_results values(3,throws_ok($test$select * from private.lead_queues$test$,'42501',null,'Raw queue state cannot be read'));
insert into pg_temp.eigsti_queue_results values(4,throws_ok($test$select * from private.lead_queue_events$test$,'42501',null,'Raw audit state cannot be read'));
insert into pg_temp.eigsti_queue_results values(5,throws_ok($test$select private.sync_lead_queue('33333333-3333-4333-8333-333333333333')$test$,'42501',null,'Private membership helper not executable'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_queue_results values(6,is((select jsonb_array_length(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items')),3::integer,'Lead reads own queue'));
insert into pg_temp.eigsti_queue_results values(7,throws_ok($test$select public.get_lead_queue('44444444-4444-4444-8444-444444444444')$test$,'42501','PM or own lead queue required','Lead cannot read another queue'));
insert into pg_temp.eigsti_queue_results values(8,throws_ok($test$select public.save_lead_queue('44444444-4444-4444-8444-444444444444','abcdefab-cdef-4abc-8abc-000000000001',array['ffffffff-ffff-4fff-8fff-ffffffffffff']::uuid[])$test$,'42501','PM or own lead queue required','Lead cannot reorder another queue'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_queue_results values(9,throws_ok($test$select public.get_lead_queue('33333333-3333-4333-8333-333333333333')$test$,'42501','PM or own lead queue required','Helper cannot read lead queue'));
insert into pg_temp.eigsti_queue_results values(10,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','99999999-9999-4999-8999-999999999999']::uuid[])$test$,'42501','PM or own lead queue required','Helper cannot save lead queue'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
insert into pg_temp.eigsti_queue_results values(11,throws_ok($test$select public.get_lead_queue('33333333-3333-4333-8333-333333333333')$test$,'42501','PM or own lead queue required','Admin-only cannot read lead queue'));
insert into pg_temp.eigsti_queue_results values(12,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','99999999-9999-4999-8999-999999999999']::uuid[])$test$,'42501','PM or own lead queue required','Admin-only cannot save lead queue'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_queue_results values(13,throws_ok($test$select public.get_lead_queue('33333333-3333-4333-8333-333333333333')$test$,'42501','PM or own lead queue required','Inactive lead cannot read lead queue'));
insert into pg_temp.eigsti_queue_results values(14,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','99999999-9999-4999-8999-999999999999']::uuid[])$test$,'42501','PM or own lead queue required','Inactive lead cannot save lead queue'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);
insert into pg_temp.eigsti_queue_results values(15,throws_ok($test$select public.get_lead_queue('33333333-3333-4333-8333-333333333333')$test$,'42501','PM or own lead queue required','Inactive PM cannot read lead queue'));
insert into pg_temp.eigsti_queue_results values(16,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','99999999-9999-4999-8999-999999999999']::uuid[])$test$,'42501','PM or own lead queue required','Inactive PM cannot save lead queue'));
reset role;
set local role anon;
insert into pg_temp.eigsti_queue_results values(17,throws_ok($test$select public.get_lead_queue('33333333-3333-4333-8333-333333333333')$test$,'42501',null,'Anonymous queue read denied'));
insert into pg_temp.eigsti_queue_results values(18,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','99999999-9999-4999-8999-999999999999']::uuid[])$test$,'42501',null,'Anonymous queue save denied'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_queue_results values(19,throws_ok($test$select public.get_lead_queue('77777777-7777-4777-8777-777777777777')$test$,'P0002','Active lead unavailable','PM cannot target inactive lead'));
insert into pg_temp.eigsti_queue_results values(20,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','dddddddd-dddd-4ddd-8ddd-dddddddddddd','99999999-9999-4999-8999-999999999999']::uuid[])$test$,'22023','Invalid queue order','Duplicate work IDs rejected'));
insert into pg_temp.eigsti_queue_results values(21,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee']::uuid[])$test$,'22023','Queue membership changed','Omitted waiting work rejected'));
insert into pg_temp.eigsti_queue_results values(22,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','ffffffff-ffff-4fff-8fff-ffffffffffff']::uuid[])$test$,'22023','Queue membership changed','Unrelated work cannot be inserted into queue'));
insert into pg_temp.eigsti_queue_results values(23,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array[]::uuid[])$test$,'22023','Queue membership changed','Nonempty queue cannot be cleared by reorder'));
insert into pg_temp.eigsti_queue_results values(24,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',null)$test$,'22023','Invalid queue order','Null order rejected'));
insert into pg_temp.eigsti_queue_results values(25,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333',null,array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','99999999-9999-4999-8999-999999999999']::uuid[])$test$,'22023','Invalid queue order','Missing request ID rejected'));
insert into pg_temp.eigsti_queue_results values(26,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array['dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid,null])$test$,'22023','Invalid queue order','Null member rejected'));
insert into pg_temp.eigsti_queue_results values(27,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array_fill('dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid,array[501]))$test$,'22023','Invalid queue order','Queue input count bounded'));
insert into pg_temp.eigsti_queue_results values(28,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array[[ 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'::uuid, 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid ]])$test$,'22023','Invalid queue order','Multidimensional order rejected'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_queue_results values(29,lives_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array['99999999-9999-4999-8999-999999999999','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','dddddddd-dddd-4ddd-8ddd-dddddddddddd']::uuid[])$test$,'Other PM may reorder lead queue'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_queue_results values(30,lives_ok($test$select public.update_job_contact('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','87654321-1234-4234-8234-123456789abc','{"notes":"Unrelated edit retained"}')$test$,'Independent contact edit succeeds'));
insert into pg_temp.eigsti_queue_results values(31,lives_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000002',array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','99999999-9999-4999-8999-999999999999','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee']::uuid[])$test$,'Later PM saves stale full membership with no revision rejection'));
insert into pg_temp.eigsti_queue_results values(32,is((select array_agg(v->>'id' order by pos) from jsonb_array_elements(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') with ordinality e(v,pos)),array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','99999999-9999-4999-8999-999999999999','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee']::text[],'Latest committed full order wins'));
insert into pg_temp.eigsti_queue_results values(33,is((select notes from public.job_contacts where id='87654321-1234-4234-8234-123456789abc'),'Unrelated edit retained','Queue save preserves unrelated contact edit'));
reset role;
insert into pg_temp.eigsti_queue_results values(34,is((select count(*) from private.lead_queue_events where lead_id='33333333-3333-4333-8333-333333333333' and operation='reorder'),2::bigint,'Both PM orders retained in history'));
insert into pg_temp.eigsti_queue_results values(35,ok((select work_ids=array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','99999999-9999-4999-8999-999999999999','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee']::uuid[] and actor_id='11111111-1111-4111-8111-111111111111' from private.lead_queue_events where lead_id='33333333-3333-4333-8333-333333333333' order by revision desc limit 1),'History stores final full order and actor'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_queue_results values(36,lives_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array['99999999-9999-4999-8999-999999999999','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','dddddddd-dddd-4ddd-8ddd-dddddddddddd']::uuid[])$test$,'Identical old request may be retried'));
insert into pg_temp.eigsti_queue_results values(37,is((select array_agg(v->>'id' order by pos) from jsonb_array_elements(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') with ordinality e(v,pos)),array['dddddddd-dddd-4ddd-8ddd-dddddddddddd','99999999-9999-4999-8999-999999999999','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee']::text[],'Old retry never overwrites newer PM order'));
insert into pg_temp.eigsti_queue_results values(38,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000001',array['eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','dddddddd-dddd-4ddd-8ddd-dddddddddddd','99999999-9999-4999-8999-999999999999']::uuid[])$test$,'23505','Request payload changed','Changed replay payload rejected'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_queue_results values(39,lives_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000003',array['eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','99999999-9999-4999-8999-999999999999','dddddddd-dddd-4ddd-8ddd-dddddddddddd']::uuid[])$test$,'Lead may reorder own queue'));
insert into pg_temp.eigsti_queue_results values(40,is((select array_agg(v->>'id' order by pos) from jsonb_array_elements(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') with ordinality e(v,pos)),array['eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','99999999-9999-4999-8999-999999999999','dddddddd-dddd-4ddd-8ddd-dddddddddddd']::text[],'Own lead order saved'));
reset role;
insert into pg_temp.eigsti_queue_snapshot select revision,(select count(*) from private.lead_queue_events where lead_id='33333333-3333-4333-8333-333333333333') from private.lead_queues where lead_id='33333333-3333-4333-8333-333333333333';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_queue_results values(41,lives_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000004',array['eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','99999999-9999-4999-8999-999999999999','dddddddd-dddd-4ddd-8ddd-dddddddddddd']::uuid[])$test$,'No-op order acknowledged'));
insert into pg_temp.eigsti_queue_results values(42,is((public.get_lead_queue('33333333-3333-4333-8333-333333333333')->>'revision')::bigint,(select revision from pg_temp.eigsti_queue_snapshot),'No-op does not increment revision'));
reset role;
insert into pg_temp.eigsti_queue_results values(43,is((select count(*) from private.lead_queue_events where lead_id='33333333-3333-4333-8333-333333333333'),(select event_count from pg_temp.eigsti_queue_snapshot),'No-op creates no extra queue history'));
insert into public.work_items(id,job_id,description,responsible_lead,created_at,created_by,updated_by) values('abababab-abab-4bab-8bab-abababababab','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Newly assigned','33333333-3333-4333-8333-333333333333','2026-10-04','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_queue_results values(44,is((select array_agg(v->>'id' order by pos) from jsonb_array_elements(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') with ordinality e(v,pos)),array['eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','99999999-9999-4999-8999-999999999999','dddddddd-dddd-4ddd-8ddd-dddddddddddd','abababab-abab-4bab-8bab-abababababab']::text[],'Newly assigned work appends without replacing prior order'));
insert into pg_temp.eigsti_queue_results values(45,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000005',array['eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','99999999-9999-4999-8999-999999999999','dddddddd-dddd-4ddd-8ddd-dddddddddddd']::uuid[])$test$,'22023','Queue membership changed','Stale membership requires reload'));
reset role;
update public.work_items set responsible_lead=null where id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_queue_results values(46,is((select array_agg(v->>'id' order by pos) from jsonb_array_elements(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') with ordinality e(v,pos)),array['99999999-9999-4999-8999-999999999999','dddddddd-dddd-4ddd-8ddd-dddddddddddd','abababab-abab-4bab-8bab-abababababab']::text[],'Unassigned portion leaves queue; survivors retain order'));
reset role;
update public.work_items set responsible_lead='44444444-4444-4444-8444-444444444444' where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_queue_results values(47,is((select array_agg(v->>'id' order by pos) from jsonb_array_elements(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') with ordinality e(v,pos)),array['99999999-9999-4999-8999-999999999999','abababab-abab-4bab-8bab-abababababab']::text[],'Reassignment removes work from former queue'));
insert into pg_temp.eigsti_queue_results values(48,is((select array_agg(v->>'id' order by pos) from jsonb_array_elements(public.get_lead_queue('44444444-4444-4444-8444-444444444444')->'items') with ordinality e(v,pos)),array['ffffffff-ffff-4fff-8fff-ffffffffffff','dddddddd-dddd-4ddd-8ddd-dddddddddddd']::text[],'Reassignment appends to new lead queue'));
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_queue_results values(49,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000006',array['99999999-9999-4999-8999-999999999999','dddddddd-dddd-4ddd-8ddd-dddddddddddd','abababab-abab-4bab-8bab-abababababab']::uuid[])$test$,'22023','Queue membership changed','Former lead cannot re-add reassigned work'));
reset role;
update public.work_items set completion='completed' where id='abababab-abab-4bab-8bab-abababababab';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_queue_results values(50,is((select array_agg(v->>'id' order by pos) from jsonb_array_elements(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') with ordinality e(v,pos)),array['99999999-9999-4999-8999-999999999999']::text[],'Completed portion leaves queue'));
reset role;
update public.work_items set completion='open' where id='abababab-abab-4bab-8bab-abababababab';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_queue_results values(51,is((select array_agg(v->>'id' order by pos) from jsonb_array_elements(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') with ordinality e(v,pos)),array['99999999-9999-4999-8999-999999999999','abababab-abab-4bab-8bab-abababababab']::text[],'Reopened portion rejoins queue'));
reset role;
update public.jobs set lifecycle='closed' where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_queue_results values(52,is((select array_agg(v->>'id' order by pos) from jsonb_array_elements(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') with ordinality e(v,pos)),array['abababab-abab-4bab-8bab-abababababab']::text[],'Closing job removes its owned work'));
reset role;
update public.jobs set lifecycle='open' where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_queue_results values(53,is((select array_agg(v->>'id' order by pos) from jsonb_array_elements(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items') with ordinality e(v,pos)),array['abababab-abab-4bab-8bab-abababababab','99999999-9999-4999-8999-999999999999']::text[],'Reopened job work appends after current work'));
reset role;
update public.app_users set active=false where id='33333333-3333-4333-8333-333333333333';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_queue_results values(54,throws_ok($test$select public.get_lead_queue('33333333-3333-4333-8333-333333333333')$test$,'42501','PM or own lead queue required','Live deactivation blocks stale session queue read'));
insert into pg_temp.eigsti_queue_results values(55,throws_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000007',array['abababab-abab-4bab-8bab-abababababab','99999999-9999-4999-8999-999999999999']::uuid[])$test$,'42501','PM or own lead queue required','Live deactivation blocks queue save'));
reset role;
update public.app_users set active=true,roles=array['helper']::text[] where id='33333333-3333-4333-8333-333333333333';
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_queue_results values(56,throws_ok($test$select public.get_lead_queue('33333333-3333-4333-8333-333333333333')$test$,'42501','PM or own lead queue required','Live role removal blocks queue'));
reset role;
update public.app_users set roles=array['lead']::text[] where id='33333333-3333-4333-8333-333333333333';
update public.work_items set responsible_lead=null where id in ('abababab-abab-4bab-8bab-abababababab','99999999-9999-4999-8999-999999999999');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_queue_results values(57,is((select jsonb_array_length(public.get_lead_queue('33333333-3333-4333-8333-333333333333')->'items')),0::integer,'Clearing final ownership empties queue'));
insert into pg_temp.eigsti_queue_results values(58,lives_ok($test$select public.save_lead_queue('33333333-3333-4333-8333-333333333333','abcdefab-cdef-4abc-8abc-000000000008',array[]::uuid[])$test$,'Empty full membership is acknowledged'));
reset role;
do $validation$
declare v_failures text;
begin
 if (select count(*) from pg_temp.eigsti_queue_results)<>58 then raise exception 'Incomplete queue tests: expected 58'; end if;
 select string_agg(result,E'\n' order by ordinal) into v_failures from pg_temp.eigsti_queue_results where result not like 'ok %';
 if v_failures is not null then raise exception 'Queue tests failed: %',v_failures; end if;
end;
$validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_queue_results;
rollback;
