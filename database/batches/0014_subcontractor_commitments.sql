-- ISOLATED TEST PROJECT ONLY. Apply 0014 once after applied 0013.
-- 48 checks; synthetic fixtures roll back before commit. Never rerun older bundles.
begin;
do $preflight$
begin
 if to_regprocedure('public.create_quick_work(uuid,uuid,jsonb,jsonb,integer,jsonb)') is null then raise exception 'Commitments batch requires applied 0013.'; end if;
 if to_regclass('public.contact_commitments') is not null or to_regprocedure('public.list_contact_commitments(date,date,boolean)') is not null then raise exception '0014 may already be applied. Do not rerun; verify project state.'; end if;
end; $preflight$;
-- Optional commitments belong to job subcontractor contacts. Apply once after 0013.
alter table public.job_contacts add constraint job_contacts_job_id_id_key unique(job_id,id);
create table public.contact_commitments(
 id uuid primary key default gen_random_uuid(),job_id uuid not null references public.jobs(id),contact_id uuid not null,
 commitment_date date check(commitment_date is null or commitment_date between date '2000-01-01' and date '2099-12-31'),
 note text not null default '' check(length(note)<=2000),archived_at timestamptz,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 created_by uuid not null references public.app_users(id),updated_by uuid not null references public.app_users(id),
 foreign key(job_id,contact_id) references public.job_contacts(job_id,id),
 check(commitment_date is not null or length(btrim(note))>0)
);
create index contact_commitments_day on public.contact_commitments(commitment_date,job_id) where archived_at is null;
alter table public.contact_commitments enable row level security;
revoke all on public.contact_commitments from public,anon,authenticated;
create table private.contact_commitment_events(
 id uuid primary key default gen_random_uuid(),commitment_id uuid not null references public.contact_commitments(id),
 actor_id uuid not null references public.app_users(id),request_id uuid,operation text not null,
 before_state jsonb,after_state jsonb not null,created_at timestamptz not null default now()
);
alter table private.contact_commitment_events enable row level security;
revoke all on private.contact_commitment_events from public,anon,authenticated;
create function private.can_manage_commitments(p_job_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.jobs j where j.id=p_job_id and j.lifecycle='open' and
 (private.has_role('pm') or (private.has_role('lead') and
 (exists(select 1 from public.work_items w where w.job_id=j.id and w.completion='open' and w.responsible_lead=auth.uid())
 or exists(select 1 from public.visits v join public.work_items w on w.id=v.work_item_id where w.job_id=j.id and v.state='planned' and v.coordinator_id=auth.uid())))));
$$;
create function public.job_contact_commitments(p_job_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not private.can_read_job(p_job_id) then raise exception using errcode='42501',message='Job access required'; end if;
 return jsonb_build_object('can_manage',private.can_manage_commitments(p_job_id),'items',coalesce((select jsonb_agg(to_jsonb(c) order by c.commitment_date nulls last,c.created_at,c.id)
 from public.contact_commitments c join public.job_contacts t on t.id=c.contact_id and t.job_id=c.job_id
 where c.job_id=p_job_id and c.archived_at is null and t.archived_at is null and lower(btrim(t.relationship))='subcontractor'),'[]'::jsonb));
end; $$;
create function public.save_contact_commitment(p_job_id uuid,p_contact_id uuid,p_id uuid,p_request_id uuid,p_values jsonb,p_remove boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.contact_commitments%rowtype;t public.job_contacts%rowtype; prior private.command_requests%rowtype;
 expected date; note_value text; payload jsonb; before_data jsonb;
begin
 if not private.can_manage_commitments(p_job_id) then raise exception using errcode='42501',message='Job planner required'; end if;
 if p_job_id is null or p_contact_id is null or p_request_id is null or p_remove is null then raise exception using errcode='22023',message='Invalid commitment'; end if;
 if p_remove then
  if p_id is null or p_values is distinct from '{}'::jsonb then raise exception using errcode='22023',message='Invalid commitment'; end if;
 else
  if p_values is null or jsonb_typeof(p_values)<>'object' or not(p_values ?& array['commitment_date','note']) or (select count(*) from jsonb_object_keys(p_values))<>2 or jsonb_typeof(p_values->'note')<>'string' then raise exception using errcode='22023',message='Invalid commitment'; end if;
  note_value:=btrim(p_values->>'note');
  if length(note_value)>2000 or translate(note_value,chr(10)||chr(13)||chr(9),'') ~ '[[:cntrl:]]' then raise exception using errcode='22023',message='Invalid commitment'; end if;
  if p_values->'commitment_date'<>'null'::jsonb then
   if jsonb_typeof(p_values->'commitment_date')<>'string' or (p_values->>'commitment_date')!~'^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' then raise exception using errcode='22023',message='Invalid commitment'; end if;
   expected:=(p_values->>'commitment_date')::date;
  end if;
  if expected is null and note_value='' then raise exception using errcode='22023',message='Enter a commitment date or note'; end if;
  p_values:=jsonb_build_object('commitment_date',expected,'note',note_value);
 end if;
 payload:=jsonb_build_object('job',p_job_id,'contact',p_contact_id,'id',p_id,'values',p_values,'remove',p_remove);
 perform id from public.app_users where id=auth.uid() for share;
 perform id from public.jobs where id=p_job_id for update;
 if not private.can_manage_commitments(p_job_id) then raise exception using errcode='42501',message='Job planner required'; end if;
 select * into t from public.job_contacts where id=p_contact_id and job_id=p_job_id for update;
 if t.id is null then raise exception using errcode='P0002',message='Contact unavailable'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='save_contact_commitment' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id,'job_id',p_job_id);
 end if;
 if t.archived_at is not null or lower(btrim(t.relationship))<>'subcontractor' then raise exception using errcode='22023',message='Active subcontractor contact required'; end if;
 if p_id is not null then
  select * into c from public.contact_commitments where id=p_id and contact_id=t.id and job_id=p_job_id for update;
  if c.id is null or c.archived_at is not null then raise exception using errcode='P0002',message='Commitment unavailable'; end if;
  before_data:=to_jsonb(c);
  if p_remove then update public.contact_commitments set archived_at=clock_timestamp(),updated_at=clock_timestamp(),updated_by=auth.uid() where id=c.id returning * into c;
  else update public.contact_commitments set commitment_date=expected,note=note_value,updated_at=clock_timestamp(),updated_by=auth.uid() where id=c.id returning * into c; end if;
 else
  if (select count(*) from public.contact_commitments where job_id=p_job_id and archived_at is null)>=200 or (select count(*) from public.contact_commitments where contact_id=t.id and archived_at is null)>=50 then raise exception using errcode='22023',message='Commitment limit reached'; end if;
  insert into public.contact_commitments(job_id,contact_id,commitment_date,note,created_by,updated_by) values(p_job_id,t.id,expected,note_value,auth.uid(),auth.uid()) returning * into c;
 end if;
 insert into private.contact_commitment_events(commitment_id,actor_id,request_id,operation,before_state,after_state) values(c.id,auth.uid(),p_request_id,case when p_remove then 'remove' when p_id is null then 'create' else 'update' end,before_data,to_jsonb(c));
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id) values(p_job_id,auth.uid(),'save_contact_commitment',array['contact:'||t.id::text,'commitment'],p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'save_contact_commitment',p_request_id,payload,c.id);
 return jsonb_build_object('id',c.id,'job_id',p_job_id);
end; $$;
create function public.create_contact_with_commitment(p_job_id uuid,p_request_id uuid,p_values jsonb,p_commitment jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; prior private.command_requests%rowtype; payload jsonb; vals jsonb;
begin
 if not private.can_manage_commitments(p_job_id) then raise exception using errcode='42501',message='Job planner required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 vals:=private.contact_patch(p_values,false);payload:=jsonb_build_object('job',p_job_id,'values',vals,'commitment',p_commitment);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':create_job_contact:'||p_request_id::text,0));
 perform id from public.app_users where id=auth.uid() for share;
 perform id from public.jobs where id=p_job_id for update;
 if not private.can_manage_commitments(p_job_id) then raise exception using errcode='42501',message='Job planner required'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='create_contact_with_commitment' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id,'job_id',p_job_id);
 end if;
 result:=public.create_job_contact(p_job_id,p_request_id,vals);
 if p_commitment is not null then perform public.save_contact_commitment(p_job_id,(result->>'id')::uuid,null,p_request_id,p_commitment,false); end if;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'create_contact_with_commitment',p_request_id,payload,(result->>'id')::uuid);
 return result||jsonb_build_object('job_id',p_job_id);
end; $$;
create function public.list_contact_commitments(p_start date,p_end date,p_all boolean default false) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not(private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Calendar planner required'; end if;
 if p_start is null or p_end is null or p_end<p_start or p_end-p_start>30 then raise exception using errcode='22023',message='Invalid commitment range'; end if;
 if (select count(*) from public.contact_commitments c join public.jobs j on j.id=c.job_id join public.job_contacts t on t.id=c.contact_id and t.job_id=c.job_id
 where c.archived_at is null and t.archived_at is null and lower(btrim(t.relationship))='subcontractor' and j.lifecycle='open' and c.commitment_date between p_start and p_end
 and ((private.has_role('pm') and (coalesce(p_all,false) or j.responsible_pm=auth.uid())) or (not private.has_role('pm') and private.has_role('lead') and private.can_read_job(j.id))))>500 then raise exception using errcode='22023',message='Commitment calendar limit'; end if;
 return coalesce((select jsonb_agg(to_jsonb(c)||jsonb_build_object('contact_name',t.name,'phone_action',t.phone_action,'job_title',j.title) order by c.commitment_date,j.title,t.name,c.id)
 from public.contact_commitments c join public.jobs j on j.id=c.job_id join public.job_contacts t on t.id=c.contact_id and t.job_id=c.job_id
 where c.archived_at is null and t.archived_at is null and lower(btrim(t.relationship))='subcontractor' and j.lifecycle='open' and c.commitment_date between p_start and p_end
 and ((private.has_role('pm') and (coalesce(p_all,false) or j.responsible_pm=auth.uid())) or (not private.has_role('pm') and private.has_role('lead') and private.can_read_job(j.id)))),'[]'::jsonb);
end; $$;
create function private.archive_contact_commitments() returns trigger language plpgsql security definer set search_path='' as $$
declare c public.contact_commitments%rowtype;before_data jsonb;
begin
 if new.archived_at is null and lower(btrim(new.relationship))='subcontractor' then return null; end if;
 for c in select * from public.contact_commitments where contact_id=new.id and archived_at is null for update loop
  before_data:=to_jsonb(c);
  update public.contact_commitments set archived_at=clock_timestamp(),updated_at=clock_timestamp(),updated_by=new.updated_by where id=c.id returning * into c;
  insert into private.contact_commitment_events(commitment_id,actor_id,operation,before_state,after_state) values(c.id,new.updated_by,'contact_unavailable',before_data,to_jsonb(c));
 end loop;
 return null;
end; $$;
create trigger archive_contact_commitments after update of archived_at,relationship on public.job_contacts for each row execute function private.archive_contact_commitments();
revoke all on function private.can_manage_commitments(uuid),private.archive_contact_commitments() from public,anon,authenticated;
revoke all on function public.job_contact_commitments(uuid),public.save_contact_commitment(uuid,uuid,uuid,uuid,jsonb,boolean),public.create_contact_with_commitment(uuid,uuid,jsonb,jsonb),public.list_contact_commitments(date,date,boolean) from public,anon,authenticated;
grant execute on function public.job_contact_commitments(uuid),public.save_contact_commitment(uuid,uuid,uuid,uuid,jsonb,boolean),public.create_contact_with_commitment(uuid,uuid,jsonb,jsonb),public.list_contact_commitments(date,date,boolean) to authenticated;
notify pgrst,'reload schema';

savepoint commitment_fixture_checks;
-- Isolated test project only. Every synthetic fixture rolls back.
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

rollback to savepoint commitment_fixture_checks;
release savepoint commitment_fixture_checks;
commit;
select 48::integer as checks,0::integer as failed,'0014 applied; synthetic fixtures removed'::text as result;
