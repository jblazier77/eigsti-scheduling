-- ISOLATED TEST PROJECT ONLY. Apply 0015 once after applied 0014.
-- 35 guarded checks; fixtures roll back before schema commit.
begin;
do $preflight$
begin
 if to_regprocedure('public.list_contact_commitments(date,date,boolean)') is null then raise exception 'Archive batch requires applied 0014.'; end if;
 if to_regprocedure('public.set_job_archive(uuid,uuid,text,text)') is not null or to_regclass('private.job_archive_events') is not null then raise exception '0015 may already be applied. Do not rerun; verify project state.'; end if;
end; $preflight$;
-- Apply once after 0014. Archive is reversible job organization, not work completion.
create table private.job_archive_events(
 id uuid primary key default gen_random_uuid(),job_id uuid not null references public.jobs(id),
 actor_id uuid not null references public.app_users(id),request_id uuid not null,
 before_state text not null,after_state text not null,created_at timestamptz not null default now()
);
alter table private.job_archive_events enable row level security;
revoke all on private.job_archive_events from public,anon,authenticated;
create function public.set_job_archive(p_job_id uuid,p_request_id uuid,p_action text,p_expected text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.jobs%rowtype;prior private.command_requests%rowtype;payload jsonb;target text;old_state text;today date:=(now() at time zone 'America/Chicago')::date;
begin
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_job_id is null or p_request_id is null or p_action is null or p_action not in ('archive','restore') or p_expected is null or p_expected not in ('open','closed','archived') then raise exception using errcode='22023',message='Invalid archive request'; end if;
 payload:=jsonb_build_object('job',p_job_id,'action',p_action,'expected',p_expected);
 -- Same lock order as scheduling; no future booking can slip in while archiving.
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 select * into j from public.jobs where id=p_job_id for update;
 if not found then raise exception using errcode='P0002',message='Job unavailable'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='set_job_archive' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',j.id,'lifecycle',j.lifecycle,'replayed',true);
 end if;
 if j.lifecycle<>p_expected or (p_action='archive' and j.lifecycle='archived') or (p_action='restore' and j.lifecycle='open') then raise exception using errcode='22023',message='Job status changed. Refresh the job before trying again.'; end if;
 if p_action='archive' then
  if exists(select 1 from public.visits v join public.work_items w on w.id=v.work_item_id where w.job_id=j.id and v.state='planned' and v.end_date>=today) then raise exception using errcode='22023',message='Resolve today or future crew dates before archiving this job.'; end if;
  if exists(select 1 from public.contact_commitments c join public.job_contacts t on t.id=c.contact_id and t.job_id=c.job_id where c.job_id=j.id and c.archived_at is null and t.archived_at is null and lower(btrim(t.relationship))='subcontractor' and c.commitment_date>=today) then raise exception using errcode='22023',message='Resolve today or future subcontractor commitments before archiving this job.'; end if;
 end if;
 old_state:=j.lifecycle;target:=case when p_action='archive' then 'archived' else 'open' end;
 update public.jobs set lifecycle=target,updated_at=clock_timestamp(),updated_by=auth.uid() where id=j.id;
 insert into private.job_archive_events(job_id,actor_id,request_id,before_state,after_state) values(j.id,auth.uid(),p_request_id,old_state,target);
 insert into public.audit_events(job_id,actor_id,request_id,operation,changed_fields) values(j.id,auth.uid(),p_request_id,'set_job_archive',array['lifecycle']);
 insert into private.command_requests(actor_id,request_id,operation,payload,result_id) values(auth.uid(),p_request_id,'set_job_archive',payload,j.id);
 return jsonb_build_object('id',j.id,'lifecycle',target,'replayed',false);
end; $$;
revoke all on function public.set_job_archive(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.set_job_archive(uuid,uuid,text,text) to authenticated;

-- Archived/closed jobs remain available as history, outside operational calendars.
create or replace function public.list_schedule(p_start date,p_end date,p_all boolean default false) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not (private.has_role('pm') or private.has_role('lead') or private.has_role('helper')) then raise exception using errcode='42501',message='Schedule access required'; end if;
 if p_start is null or p_end is null or p_end<p_start or p_end-p_start>30 then raise exception using errcode='22023',message='Invalid schedule range'; end if;
 if p_all and not private.has_role('pm') then raise exception using errcode='42501',message='PM required'; end if;
 if (select count(*) from public.visits v join public.work_items w on w.id=v.work_item_id join public.jobs j on j.id=w.job_id
 where j.lifecycle='open' and v.start_date<=p_end and v.end_date>=p_start and v.state<>'cancelled' and
 ((private.has_role('pm') and (p_all or j.responsible_pm=auth.uid())) or (not private.has_role('pm') and exists(select 1 from public.visit_participants p where p.visit_id=v.id and p.user_id=auth.uid()))))>500 then raise exception using errcode='22023',message='Schedule limit exceeded'; end if;
 return coalesce((select jsonb_agg(private.visit_result(v.id) order by v.start_date,v.start_time nulls first,v.id)
 from public.visits v join public.work_items w on w.id=v.work_item_id join public.jobs j on j.id=w.job_id
 where j.lifecycle='open' and v.start_date<=p_end and v.end_date>=p_start and v.state<>'cancelled' and
 ((private.has_role('pm') and (p_all or j.responsible_pm=auth.uid())) or (not private.has_role('pm') and exists(select 1 from public.visit_participants p where p.visit_id=v.id and p.user_id=auth.uid())))),'[]'::jsonb);
end; $$;
notify pgrst,'reload schema';

savepoint archive_fixture_checks;
-- Isolated test project only. Every synthetic fixture rolls back.
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

rollback to savepoint archive_fixture_checks;
release savepoint archive_fixture_checks;
commit;
select 35::integer as checks,0::integer as failed,'0015 applied; synthetic fixtures removed'::text as result;
