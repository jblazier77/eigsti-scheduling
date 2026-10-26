-- ISOLATED TEST PROJECT ONLY. Apply 0017 once after 0016.
-- All checks must pass; synthetic fixtures roll back before migration commit.
begin;
do $preflight$ begin
 if to_regprocedure('public.save_employee(uuid,uuid,timestamp with time zone,jsonb)') is null and to_regclass('private.employee_events') is null then raise exception 'Planning review requires applied 0016.'; end if;
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='jobs' and column_name='priority') or to_regprocedure('public.pm_help_requests()') is not null then raise exception '0017 may already be applied. Do not rerun; verify state.'; end if;
end; $preflight$;
-- Apply once after 0016. Planning information only; no existing data is removed.
alter table public.jobs add column priority integer check(priority between 1 and 9999);
alter table public.work_items add column estimated_days numeric(5,2) check(estimated_days>0 and estimated_days<=999);
create index jobs_priority_order on public.jobs(priority asc nulls last,created_at desc,id desc);

create function private.review_number(p_value jsonb,p_kind text) returns numeric language plpgsql immutable set search_path='' as $$
declare n numeric;
begin
 if p_value is null or p_value='null'::jsonb then return null; end if;
 if jsonb_typeof(p_value)<>'number' then raise exception using errcode='22023',message='Invalid planning number'; end if;
 n:=(p_value#>>'{}')::numeric;
 if n<=0 or (p_kind='priority' and (n>9999 or n<>trunc(n))) or (p_kind='days' and (n>999 or n<>round(n,2))) then raise exception using errcode='22023',message='Invalid planning number'; end if;
 return n;
end; $$;
revoke all on function private.review_number(jsonb,text) from public,anon,authenticated;

create function public.save_job_priority(p_job_id uuid,p_request_id uuid,p_priority jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare n integer; payload jsonb; prior private.command_requests%rowtype;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 n:=private.review_number(p_priority,'priority');payload:=jsonb_build_object('job',p_job_id,'priority',n);
 perform id from public.jobs where id=p_job_id and lifecycle='open' for update;
 if not found then raise exception using errcode='P0002',message='Open job required'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='save_job_priority' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 update public.jobs set priority=n,updated_at=clock_timestamp(),updated_by=auth.uid() where id=p_job_id;
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id) values(p_job_id,auth.uid(),'save_job_priority',array['priority'],p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'save_job_priority',p_request_id,payload,p_job_id);
 return jsonb_build_object('id',p_job_id);
end; $$;

create function public.create_planning_work(p_job_id uuid,p_request_id uuid,p_values jsonb,p_plan jsonb,p_helpers integer,p_materials jsonb,p_days jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare n numeric; payload jsonb; prior private.command_requests%rowtype; result jsonb;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 -- JSON array/object extraction yields jsonb null, not SQL NULL. Normalize at the wrapper boundary.
 p_plan:=nullif(p_plan,'null'::jsonb);
 p_materials:=nullif(p_materials,'null'::jsonb);
 n:=private.review_number(p_days,'days');
 payload:=jsonb_build_object('job',p_job_id,'values',p_values,'plan',p_plan,'helpers',p_helpers,'materials',p_materials,'days',n);
 perform id from public.jobs where id=p_job_id and lifecycle='open' for update;
 if not found then raise exception using errcode='P0002',message='Open job required'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='create_planning_work' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 if exists(select 1 from private.command_requests where actor_id=auth.uid() and request_id=p_request_id and operation in ('create_quick_work','create_job_work_with_plan','create_job_work')) then raise exception using errcode='23505',message='Request payload changed'; end if;
 result:=public.create_quick_work(p_job_id,p_request_id,p_values,p_plan,p_helpers,p_materials);
 update public.work_items set estimated_days=n where id=(result->>'id')::uuid;
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id) values(p_job_id,auth.uid(),'create_planning_work',array['estimated_days'],p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'create_planning_work',p_request_id,payload,(result->>'id')::uuid);
 return result;
end; $$;

create function public.save_work_details(p_work_id uuid,p_request_id uuid,p_values jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items%rowtype; j public.jobs%rowtype; prior private.command_requests%rowtype; payload jsonb; k text; patch jsonb; n numeric;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not(private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Work planner required'; end if;
 if p_request_id is null or p_values is null or jsonb_typeof(p_values)<>'object' or p_values='{}'::jsonb then raise exception using errcode='22023',message='Invalid work details'; end if;
 for k in select jsonb_object_keys(p_values) loop
  if k not in ('description','estimated_days','responsible_lead','default_helpers') then raise exception using errcode='22023',message='Invalid work field'; end if;
 end loop;
 select x.* into j from public.jobs x join public.work_items y on y.job_id=x.id where y.id=p_work_id for update of x;
 select * into w from public.work_items where id=p_work_id for update;
 if w.id is null or j.lifecycle<>'open' or w.completion<>'open' then raise exception using errcode='P0002',message='Open work required'; end if;
 if not private.has_role('pm') and (w.responsible_lead is distinct from auth.uid() or not private.can_read_job(j.id)) then raise exception using errcode='42501',message='Responsible lead required'; end if;
 if not private.has_role('pm') and p_values ? 'responsible_lead' then raise exception using errcode='42501',message='PM account required'; end if;
 payload:=jsonb_build_object('work',p_work_id,'values',p_values);
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='save_work_details' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',w.id,'job_id',j.id);
 end if;
 patch:=p_values-array['estimated_days','default_helpers'];
 if patch<>'{}'::jsonb then
  patch:=private.work_patch(patch);
  if private.has_role('pm') then perform public.update_job_work(j.id,w.id,patch);
  else update public.work_items set description=patch->>'description' where id=w.id; end if;
 end if;
 if p_values ? 'estimated_days' then n:=private.review_number(p_values->'estimated_days','days');update public.work_items set estimated_days=n where id=w.id; end if;
 if p_values ? 'default_helpers' then
  if jsonb_typeof(p_values->'default_helpers')<>'number' or (p_values->>'default_helpers')::numeric not between 0 and 20 or (p_values->>'default_helpers')::numeric<>trunc((p_values->>'default_helpers')::numeric) then raise exception using errcode='22023',message='Invalid helper count'; end if;
  update public.work_items set default_helpers=(p_values->>'default_helpers')::integer where id=w.id;
 end if;
 update public.work_items set updated_at=clock_timestamp(),updated_by=auth.uid() where id=w.id;
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id) values(j.id,auth.uid(),'save_work_details',array(select jsonb_object_keys(p_values)),p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'save_work_details',p_request_id,payload,w.id);
 return jsonb_build_object('id',w.id,'job_id',j.id);
end; $$;

create function public.pm_help_requests() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(r) order by r.priority asc nulls last,r.start_date asc nulls last,r.job_id,r.work_id,r.visit_id) from (
 select j.id job_id,j.title,w.id work_id,w.description,j.priority,v.id visit_id,v.start_date,v.end_date,v.required_helpers requested,
 a.assigned::integer assigned,(v.required_helpers-a.assigned)::integer missing
 from public.jobs j join public.work_items w on w.job_id=j.id join public.visits v on v.work_item_id=w.id
 cross join lateral (select count(distinct p.user_id) assigned from public.visit_participants p join public.app_users u on u.id=p.user_id
 where p.visit_id=v.id and p.duty='helping' and p.user_id<>v.coordinator_id and u.active and u.roles && array['lead','helper']::text[]) a
 where j.responsible_pm=auth.uid() and j.lifecycle='open' and w.completion='open' and v.state='planned' and v.end_date>=(now() at time zone 'America/Chicago')::date and v.required_helpers>a.assigned
 union all
 select j.id,j.title,w.id,w.description,j.priority,null::uuid,null::date,null::date,w.default_helpers,0,w.default_helpers
 from public.jobs j join public.work_items w on w.job_id=j.id where j.responsible_pm=auth.uid() and j.lifecycle='open' and w.completion='open' and w.default_helpers>0
 and not exists(select 1 from public.visits v where v.work_item_id=w.id and v.state='planned')
 ) r),'[]'::jsonb);
end; $$;

create function public.create_job_workspace(p_request_id uuid,p_customer text,p_phone text,p_address text,p_classification jsonb,p_details jsonb,p_priority jsonb,p_work jsonb,p_contacts jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare payload jsonb; prior private.command_requests%rowtype; result jsonb; v_job uuid; item jsonb; item_request uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null or jsonb_typeof(p_work) is distinct from 'array' or jsonb_typeof(p_contacts) is distinct from 'array' or jsonb_array_length(p_work)>20 or jsonb_array_length(p_contacts)>20 then raise exception using errcode='22023',message='Invalid job setup'; end if;
 payload:=jsonb_build_object('customer',p_customer,'phone',p_phone,'address',p_address,'classification',p_classification,'details',p_details,'priority',p_priority,'work',p_work,'contacts',p_contacts);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':create_job_workspace:'||p_request_id::text,0));
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='create_job_workspace' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':create_classified_job:'||p_request_id::text,0));
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':create_job:'||p_request_id::text,0));
 if exists(select 1 from private.command_requests where actor_id=auth.uid() and request_id=p_request_id and operation in ('create_job','create_classified_job')) then raise exception using errcode='23505',message='Request payload changed'; end if;
 result:=public.create_classified_job(p_request_id,p_customer,p_phone,p_address,p_classification);v_job:=(result->>'id')::uuid;
 if p_details is null or jsonb_typeof(p_details)<>'object' or exists(select 1 from jsonb_object_keys(p_details) k where k not in ('title','scope','access_notes')) then raise exception using errcode='22023',message='Invalid job setup'; end if;
 if p_details<>'{}'::jsonb then perform public.update_job(v_job,p_details); end if;
 perform public.save_job_priority(v_job,p_request_id,p_priority);
 -- create_job supplies one Whole job item; remove only this newly-created placeholder
 -- when explicit task drafts were supplied, before any dates or ownership exist.
 if jsonb_array_length(p_work)>0 then delete from public.work_items where job_id=v_job; end if;
 for item in select value from jsonb_array_elements(p_work) loop
  item_request:=gen_random_uuid();
  perform public.create_planning_work(v_job,item_request,item->'values',item->'plan',(item->>'helpers')::integer,item->'materials',item->'days');
 end loop;
 for item in select value from jsonb_array_elements(p_contacts) loop perform public.create_job_contact(v_job,gen_random_uuid(),item); end loop;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'create_job_workspace',p_request_id,payload,v_job);
 return result;
end; $$;
revoke all on function public.save_job_priority(uuid,uuid,jsonb),public.create_planning_work(uuid,uuid,jsonb,jsonb,integer,jsonb,jsonb),public.save_work_details(uuid,uuid,jsonb),public.pm_help_requests(),public.create_job_workspace(uuid,text,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.save_job_priority(uuid,uuid,jsonb),public.create_planning_work(uuid,uuid,jsonb,jsonb,integer,jsonb,jsonb),public.save_work_details(uuid,uuid,jsonb),public.pm_help_requests(),public.create_job_workspace(uuid,text,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) to authenticated;
notify pgrst,'reload schema';

savepoint review_fixture_checks;
-- Isolated test project only. Synthetic fixtures and every change roll back.
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_review_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_review_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_review_results,pg_temp.eigsti_review_ids to authenticated,anon;
grant usage on sequence pg_temp.eigsti_review_results_ordinal_seq to authenticated,anon;
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
insert into public.jobs(id,customer_name,phone,phone_action,address,title,scope,access_notes,responsible_pm,created_by,updated_by) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Planning','3095550101','+13095550101','Fictional Lane','SYNTHETIC Planning','Keep scope','Keep access','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');

create function pg_temp.review_create(r uuid default gen_random_uuid(), d jsonb default '0.5', h integer default 2, n text default 'SYNTHETIC Estimated work') returns jsonb language sql as $$ select public.create_planning_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',r,jsonb_build_object('description',n,'responsible_lead','33333333-3333-4333-8333-333333333333'),null,h,null,d); $$;
create function pg_temp.review_workspace(r uuid, tasks jsonb default '[]', contacts jsonb default '[]') returns jsonb language sql as $$select public.create_job_workspace(r,'SYNTHETIC Setup','3095550101','Fictional Setup Lane','{}','{"scope":"Keep scope","access_notes":"Gate note"}','2',tasks,contacts);$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','abcdefab-cdef-4abc-8abc-000000000101','1')$t$,'PM sets priority'));
insert into pg_temp.eigsti_review_results(result) values(is((select priority from public.jobs where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),1,'Priority persists'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','abcdefab-cdef-4abc-8abc-000000000101','1')$t$,'Priority retry succeeds'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','abcdefab-cdef-4abc-8abc-000000000101','2')$t$,'23505','Request payload changed','Changed priority retry blocked'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'0')$t$,'22023','Invalid planning number','Invalid priority 0 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'-1')$t$,'22023','Invalid planning number','Invalid priority -1 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'1.5')$t$,'22023','Invalid planning number','Invalid priority 1.5 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'10000')$t$,'22023','Invalid planning number','Invalid priority 10000 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'"1"')$t$,'22023','Invalid planning number','Invalid priority 1 denied'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'null')$t$,'Priority can be cleared'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select pg_temp.review_create('abcdefab-cdef-4abc-8abc-000000000102')$t$,'Half day and undated help saved together'));
insert into pg_temp.eigsti_review_ids select 'work',id from public.work_items where description='SYNTHETIC Estimated work' and job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
insert into pg_temp.eigsti_review_results(result) values(ok((select estimated_days=0.5 and default_helpers=2 from public.work_items where id=(select id from pg_temp.eigsti_review_ids where label='work')),'Estimate and helpers persisted'));
insert into pg_temp.eigsti_review_results(result) values(is(jsonb_array_length(public.pm_help_requests()),1,'Undated request appears on PM dashboard'));
insert into pg_temp.eigsti_review_results(result) values(ok((public.pm_help_requests()->0->>'missing')::integer=2,'Undated shortfall is two'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select pg_temp.review_create('abcdefab-cdef-4abc-8abc-000000000102')$t$,'Work retry acknowledged'));
insert into pg_temp.eigsti_review_results(result) values(is((select count(*) from public.work_items where description='SYNTHETIC Estimated work'),1::bigint,'No duplicate work'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_create(gen_random_uuid(),'0')$t$,'22023','Invalid planning number','Invalid estimated days 0 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_create(gen_random_uuid(),'-1')$t$,'22023','Invalid planning number','Invalid estimated days -1 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_create(gen_random_uuid(),'1000')$t$,'22023','Invalid planning number','Invalid estimated days 1000 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_create(gen_random_uuid(),'0.001')$t$,'22023','Invalid planning number','Invalid estimated days 0.001 denied'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_create(gen_random_uuid(),'"1"')$t$,'22023','Invalid planning number','Invalid estimated days 1 denied'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.save_work_details((select id from pg_temp.eigsti_review_ids where label='work'),'abcdefab-cdef-4abc-8abc-000000000103','{"description":"SYNTHETIC Lead edited","estimated_days":1.25}')$t$,'Responsible lead edits task and days'));
insert into pg_temp.eigsti_review_results(result) values(ok((select estimated_days=1.25 and description='SYNTHETIC Lead edited' from public.work_items where id=(select id from pg_temp.eigsti_review_ids where label='work')),'Lead changes persisted'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_work_details((select id from pg_temp.eigsti_review_ids where label='work'),gen_random_uuid(),'{"responsible_lead":null}')$t$,'42501','PM account required','Lead cannot change ownership'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.pm_help_requests()$t$,'42501','PM account required','Lead cannot read PM dashboard'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_job_priority('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',gen_random_uuid(),'1')$t$,'42501','PM account required','Lead cannot set priority'));
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_work_details((select id from pg_temp.eigsti_review_ids where label='work'),gen_random_uuid(),'{"estimated_days":2}')$t$,'42501','Responsible lead required','Unassigned lead cannot edit'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.save_work_details((select id from pg_temp.eigsti_review_ids where label='work'),gen_random_uuid(),'{"estimated_days":2}')$t$,'42501','Work planner required','Helper cannot edit estimates'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select pg_temp.review_create('abcdefab-cdef-4abc-8abc-000000000102')$t$,'Original create retry after lead changes acknowledged'));
insert into pg_temp.eigsti_review_results(result) values(ok((select estimated_days=1.25 and description='SYNTHETIC Lead edited' from public.work_items where id=(select id from pg_temp.eigsti_review_ids where label='work')),'Create retry preserves subsequent edits'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select pg_temp.review_workspace('abcdefab-cdef-4abc-8abc-000000000104')$t$,'Minimal full-page job save succeeds'));
insert into pg_temp.eigsti_review_ids values('setup',(pg_temp.review_workspace('abcdefab-cdef-4abc-8abc-000000000104')->>'id')::uuid);
insert into pg_temp.eigsti_review_results(result) values(ok((select scope='Keep scope' and access_notes='Gate note' and priority=2 from public.jobs where id=(select id from pg_temp.eigsti_review_ids where label='setup')),'Scope notes and priority saved together'));
insert into pg_temp.eigsti_review_results(result) values(is((select count(*) from public.work_items where job_id=(select id from pg_temp.eigsti_review_ids where label='setup')),1::bigint,'Minimal save keeps Whole job'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select pg_temp.review_workspace('abcdefab-cdef-4abc-8abc-000000000105','[{"values":{"description":"SYNTHETIC Setup work","responsible_lead":"33333333-3333-4333-8333-333333333333"},"plan":null,"helpers":1,"materials":{"material_name":"Windows","material_status":"in_stock","material_expected_on":null},"days":0.5}]','[{"name":"SYNTHETIC Installer","relationship":"Subcontractor","phone":"3095550102","email":"","notes":"Call ahead"}]')$t$,'Work materials help and contact save with job'));
insert into pg_temp.eigsti_review_ids values('full',(pg_temp.review_workspace('abcdefab-cdef-4abc-8abc-000000000105','[{"values":{"description":"SYNTHETIC Setup work","responsible_lead":"33333333-3333-4333-8333-333333333333"},"plan":null,"helpers":1,"materials":{"material_name":"Windows","material_status":"in_stock","material_expected_on":null},"days":0.5}]','[{"name":"SYNTHETIC Installer","relationship":"Subcontractor","phone":"3095550102","email":"","notes":"Call ahead"}]')->>'id')::uuid);
insert into pg_temp.eigsti_review_results(result) values(is((select count(*) from public.work_items where job_id=(select id from pg_temp.eigsti_review_ids where label='full')),1::bigint,'Explicit task replaces newly created placeholder only'));
insert into pg_temp.eigsti_review_results(result) values(ok((select estimated_days=0.5 and default_helpers=1 and material_status='in_stock' from public.work_items where job_id=(select id from pg_temp.eigsti_review_ids where label='full')),'Nested quick-work details preserved'));
insert into pg_temp.eigsti_review_results(result) values(is((select count(*) from public.job_contacts where job_id=(select id from pg_temp.eigsti_review_ids where label='full')),1::bigint,'Contact created exactly once'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_workspace('abcdefab-cdef-4abc-8abc-000000000106','[{"values":{"description":"SYNTHETIC Setup work","responsible_lead":"33333333-3333-4333-8333-333333333333"},"plan":null,"helpers":1,"materials":{"material_name":"Windows","material_status":"in_stock","material_expected_on":null},"days":-1}]','[{"name":"SYNTHETIC Installer","relationship":"Subcontractor","phone":"3095550102","email":"","notes":"Call ahead"}]')$t$,'22023','Invalid planning number','Invalid task rolls back entire new job'));
insert into pg_temp.eigsti_review_results(result) values(is((select count(*) from public.jobs where address='Fictional Setup Lane'),2::bigint,'Failed setup leaves no partial job'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select pg_temp.review_workspace('abcdefab-cdef-4abc-8abc-000000000105')$t$,'23505','Request payload changed','Changed job setup retry rejected'));
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into pg_temp.eigsti_review_results(result) values(is(jsonb_array_length(public.pm_help_requests()),0,'Other PM cannot see these requests'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.save_visit((select id from pg_temp.eigsti_review_ids where label='work'),null,'abcdefab-cdef-4abc-8abc-000000000111','{"start_date":"2099-01-05","end_date":"2099-01-05","slot":"day","coordinator_id":"33333333-3333-4333-8333-333333333333","required_helpers":2,"certainty":"tentative"}')$t$,'Estimated task can still be scheduled with no time'));
insert into pg_temp.eigsti_review_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.pm_help_requests()) r where r->>'work_id'=(select id::text from pg_temp.eigsti_review_ids where label='work') and r->>'start_date'='2099-01-05' and (r->>'missing')::integer=2),'Scheduled help replaces undated request'));
insert into pg_temp.eigsti_review_results(result) values(ok((select estimated_days=1.25 from public.work_items where id=(select id from pg_temp.eigsti_review_ids where label='work')),'Scheduling preserves estimate'));
insert into pg_temp.eigsti_review_ids values('visit',(select (r->>'visit_id')::uuid from jsonb_array_elements(public.pm_help_requests()) r where r->>'work_id'=(select id::text from pg_temp.eigsti_review_ids where label='work') limit 1));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.staff_visit((select id from pg_temp.eigsti_review_ids where label='visit'),gen_random_uuid(),array['55555555-5555-4555-8555-555555555555']::uuid[])$t$,'First helper assigned'));
insert into pg_temp.eigsti_review_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.pm_help_requests()) r where r->>'work_id'=(select id::text from pg_temp.eigsti_review_ids where label='work') and (r->>'assigned')::integer=1 and (r->>'missing')::integer=1),'Partially filled request remains visible'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.staff_visit((select id from pg_temp.eigsti_review_ids where label='visit'),gen_random_uuid(),array['55555555-5555-4555-8555-555555555555','44444444-4444-4444-8444-444444444444']::uuid[])$t$,'Lead may fill second helping space'));
insert into pg_temp.eigsti_review_results(result) values(ok(not exists(select 1 from jsonb_array_elements(public.pm_help_requests()) r where r->>'work_id'=(select id::text from pg_temp.eigsti_review_ids where label='work')),'Filled request clears automatically'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.create_classified_job('abcdefab-cdef-4abc-8abc-000000000112','SYNTHETIC Legacy','3095550101','Legacy Lane','{}')$t$,'Legacy creation remains available'));
insert into pg_temp.eigsti_review_results(result) values(throws_ok($t$select public.create_job_workspace('abcdefab-cdef-4abc-8abc-000000000112','SYNTHETIC Legacy','3095550101','Legacy Lane','{}','{}','null','[]','[]')$t$,'23505','Request payload changed','Workspace cannot upgrade an existing job request'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.create_planning_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','abcdefab-cdef-4abc-8abc-000000000120','{"description":"SYNTHETIC JSON null options","responsible_lead":null}','null',0,'null','null')$t$,'Explicit JSON null dates materials and estimate stay optional'));
insert into pg_temp.eigsti_review_results(result) values(lives_ok($t$select public.create_planning_work('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','abcdefab-cdef-4abc-8abc-000000000120','{"description":"SYNTHETIC JSON null options","responsible_lead":null}',null,0,null,null)$t$,'SQL NULL retry has the same canonical payload'));
insert into pg_temp.eigsti_review_results(result) values(is((select count(*) from public.work_items where description='SYNTHETIC JSON null options'),1::bigint,'Null representations do not duplicate work'));
reset role;
insert into pg_temp.eigsti_review_results(result) values(ok(not has_function_privilege('anon','public.pm_help_requests()','EXECUTE'),'Anonymous dashboard denied'));
insert into pg_temp.eigsti_review_results(result) values(ok(not has_table_privilege('authenticated','public.jobs','UPDATE'),'No direct job writes granted'));
insert into pg_temp.eigsti_review_results(result) values(ok(not has_table_privilege('authenticated','public.work_items','UPDATE'),'No direct work writes granted'));
do $validation$ declare failures text; begin select string_agg(result,E'\n' order by ordinal) into failures from pg_temp.eigsti_review_results where result not like 'ok %'; if failures is not null then raise exception 'Planning review checks failed: %',failures; end if; end; $validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_review_results;

rollback to savepoint review_fixture_checks;
release savepoint review_fixture_checks;
commit;
select 56::integer as checks,0::integer as failed,'0017 applied; synthetic fixtures removed'::text as result;
