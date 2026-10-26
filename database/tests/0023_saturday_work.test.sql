-- Isolated test project only. Synthetic fixtures and every change roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_saturday_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_saturday_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_saturday_results,pg_temp.eigsti_saturday_ids to authenticated,anon;
grant usage on sequence pg_temp.eigsti_saturday_results_ordinal_seq to authenticated,anon;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','quick-pm@example.invalid'),
('22222222-2222-4222-8222-222222222222','review-pm2@example.invalid'),
('33333333-3333-4333-8333-333333333333','quick-lead@example.invalid'),
('44444444-4444-4444-8444-444444444444','quick-other@example.invalid'),
('55555555-5555-4555-8555-555555555555','quick-helper@example.invalid'),
('77777777-7777-4777-8777-777777777777','quick-admin@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC PM',array['pm'],true),
('22222222-2222-4222-8222-222222222222','SYNTHETIC PM2',array['pm'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Lead',array['lead'],true),
('44444444-4444-4444-8444-444444444444','SYNTHETIC Other lead',array['lead'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Helper',array['helper'],true),
('77777777-7777-4777-8777-777777777777','SYNTHETIC Admin',array['admin'],true);
create function pg_temp.saturday_work(j uuid,r uuid,n text,s date,e date,t text default 'day') returns jsonb language sql as $helper$
 select public.create_staffed_work(j,r,jsonb_build_object('description',n,'responsible_lead',null),jsonb_build_object('start_date',s,'end_date',e,'slot',t,'coordinator_id',null,'required_helpers',1,'certainty','tentative'),1,null,null,'["55555555-5555-4555-8555-555555555555"]');
$helper$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_saturday_ids values('job',(public.create_job_workspace('abcdefab-cdef-4abc-8abc-000000000001','SYNTHETIC Saturday','3095550101','Fictional Saturday Lane','{}','{}','null','[]','[]')->>'id')::uuid);
insert into pg_temp.eigsti_saturday_results(result) values(lives_ok($q$select pg_temp.saturday_work((select id from pg_temp.eigsti_saturday_ids where label='job'),'abcdefab-cdef-4abc-8abc-000000000002','SYNTHETIC Saturday install','2099-01-10','2099-01-10')$q$,'Saturday date-only crew work without lead saves'));
insert into pg_temp.eigsti_saturday_ids values('work',(pg_temp.saturday_work((select id from pg_temp.eigsti_saturday_ids where label='job'),'abcdefab-cdef-4abc-8abc-000000000002','SYNTHETIC Saturday install','2099-01-10','2099-01-10')->>'id')::uuid);
reset role;
insert into pg_temp.eigsti_saturday_ids select 'visit',id from public.visits where work_item_id=(select id from pg_temp.eigsti_saturday_ids where label='work');
insert into pg_temp.eigsti_saturday_results(result) values(ok((select start_date='2099-01-10' and coordinator_id is null from public.visits where id=(select id from pg_temp.eigsti_saturday_ids where label='visit')),'Saturday and unassigned lead retained'));
insert into pg_temp.eigsti_saturday_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select id from pg_temp.eigsti_saturday_ids where label='visit')),0::bigint,'Date-only Saturday creates no exclusive reservation'));
set local role authenticated;
insert into pg_temp.eigsti_saturday_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.list_schedule('2099-01-10','2099-01-10',false)) x where x->>'id'=(select id from pg_temp.eigsti_saturday_ids where label='visit')::text),'Saturday appears in PM schedule'));
insert into pg_temp.eigsti_saturday_results(result) values(lives_ok($q$select public.save_visit((select id from pg_temp.eigsti_saturday_ids where label='work'),(select id from pg_temp.eigsti_saturday_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000003','{"slot":"morning"}')$q$,'Optional Saturday time block saves'));
reset role;
insert into pg_temp.eigsti_saturday_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select id from pg_temp.eigsti_saturday_ids where label='visit')),1::bigint,'Saturday helper is actually reserved'));
set local role authenticated;
insert into pg_temp.eigsti_saturday_results(result) values(throws_ok($q$select pg_temp.saturday_work((select id from pg_temp.eigsti_saturday_ids where label='job'),'abcdefab-cdef-4abc-8abc-000000000004','SYNTHETIC Conflicting Saturday','2099-01-10','2099-01-10','morning')$q$,'23P01','Staff scheduling conflict','Saturday overlaps are blocked'));
insert into pg_temp.eigsti_saturday_results(result) values(lives_ok($q$select pg_temp.saturday_work((select id from pg_temp.eigsti_saturday_ids where label='job'),'abcdefab-cdef-4abc-8abc-000000000005','SYNTHETIC Second Saturday','2099-01-10','2099-01-10')$q$,'Multiple date-only Saturday jobs remain valid'));
insert into pg_temp.eigsti_saturday_results(result) values(throws_ok($q$select pg_temp.saturday_work((select id from pg_temp.eigsti_saturday_ids where label='job'),'abcdefab-cdef-4abc-8abc-000000000006','SYNTHETIC Sunday','2099-01-11','2099-01-11')$q$,null,null,'Sunday start and end stay rejected'));
insert into pg_temp.eigsti_saturday_results(result) values(lives_ok($q$select pg_temp.saturday_work((select id from pg_temp.eigsti_saturday_ids where label='job'),'abcdefab-cdef-4abc-8abc-000000000007','SYNTHETIC Multi-day','2099-01-16','2099-01-19','all_day')$q$,'Friday through Monday crew work saves'));
reset role;
insert into pg_temp.eigsti_saturday_ids select 'multi',v.id from public.visits v join public.work_items w on w.id=v.work_item_id where w.description='SYNTHETIC Multi-day' and w.job_id=(select id from pg_temp.eigsti_saturday_ids where label='job');
insert into pg_temp.eigsti_saturday_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select id from pg_temp.eigsti_saturday_ids where label='multi')),3::bigint,'Multi-day reservations cover Friday Saturday Monday'));
insert into pg_temp.eigsti_saturday_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select id from pg_temp.eigsti_saturday_ids where label='multi') and extract(isodow from starts_at at time zone 'America/Chicago')=6),1::bigint,'Multi-day Saturday included'));
insert into pg_temp.eigsti_saturday_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select id from pg_temp.eigsti_saturday_ids where label='multi') and extract(isodow from starts_at at time zone 'America/Chicago')=7),0::bigint,'Multi-day Sunday skipped'));
insert into pg_temp.eigsti_saturday_results(result) values(is((select count(*) from public.work_items where job_id=(select id from pg_temp.eigsti_saturday_ids where label='job') and description in ('SYNTHETIC Conflicting Saturday','SYNTHETIC Sunday')),0::bigint,'Rejected work leaves no partial records'));
set local role authenticated;
insert into pg_temp.eigsti_saturday_results(result) values(lives_ok($q$select public.save_visit((select id from pg_temp.eigsti_saturday_ids where label='work'),(select id from pg_temp.eigsti_saturday_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000008','{"state":"cancelled"}')$q$,'Saturday reservation may be cancelled'));
reset role;
insert into pg_temp.eigsti_saturday_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select id from pg_temp.eigsti_saturday_ids where label='visit')),0::bigint,'Saturday cancellation releases reservation'));
do $validation$ begin if exists(select 1 from pg_temp.eigsti_saturday_results where result not like 'ok %') then raise exception 'Saturday work checks failed'; end if; end; $validation$;
select result from pg_temp.eigsti_saturday_results order by ordinal;
select * from finish();
rollback;
