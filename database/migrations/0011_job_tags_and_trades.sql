-- After 0010. Additive metadata only; no staffing or readiness changes.
begin;
create function private.valid_trade_ids(p_ids text[]) returns boolean language sql immutable set search_path='' as $$
 select p_ids is not null and cardinality(p_ids)<=15 and array_position(p_ids,null) is null
 and p_ids <@ array['roofing','siding','windows_doors','framing','electrical','plumbing','hvac','drywall','painting','flooring','cabinetry','tile','concrete','landscaping','general']::text[]
 and cardinality(p_ids)=(select count(distinct x) from unnest(p_ids) x);
$$;
alter table public.jobs add column rain_day boolean not null default false,
 add column filler boolean not null default false, add column whole_house boolean not null default false,
 add column trades text[] not null default '{}' check(private.valid_trade_ids(trades));
create index jobs_rain_day on public.jobs(responsible_pm,created_at desc,id desc) where rain_day and lifecycle='open';
create index jobs_filler on public.jobs(responsible_pm,created_at desc,id desc) where filler and lifecycle='open';

create function private.classification_patch(p_values jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare k text; ids text[]; result jsonb:='{}';
begin
 if p_values is null or jsonb_typeof(p_values)<>'object' then raise exception using errcode='22023',message='Invalid job tags'; end if;
 for k in select jsonb_object_keys(p_values) loop
  if k='trades' then
   if jsonb_typeof(p_values->k)<>'array' or exists(select 1 from jsonb_array_elements(p_values->k) v where jsonb_typeof(v)<>'string') then raise exception using errcode='22023',message='Invalid trades'; end if;
   select coalesce(array_agg(v order by v),'{}'::text[]) into ids from jsonb_array_elements_text(p_values->k) v;
   if not private.valid_trade_ids(ids) then raise exception using errcode='22023',message='Invalid trades'; end if;
   result:=result||jsonb_build_object(k,ids);
  elsif k in ('rain_day','filler','whole_house') and jsonb_typeof(p_values->k)='boolean' then result:=result||jsonb_build_object(k,p_values->k);
  else raise exception using errcode='22023',message='Invalid job tags'; end if;
 end loop;
 return result;
end; $$;
create table private.classification_events(
 id uuid primary key default gen_random_uuid(),job_id uuid not null references public.jobs(id),
 actor_id uuid not null references public.app_users(id),request_id uuid not null,
 before_state jsonb not null,after_state jsonb not null,created_at timestamptz not null default now()
);
alter table private.classification_events enable row level security;
revoke all on private.classification_events from public,anon,authenticated;

create function public.save_job_classification(p_job_id uuid,p_request_id uuid,p_patch jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); patch jsonb; payload jsonb; previous private.command_requests%rowtype; j public.jobs%rowtype; before_data jsonb;
begin
 perform 1 from public.app_users where id=actor and active and 'pm'=any(roles) for share;
 if not found then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 patch:=private.classification_patch(p_patch);
 if patch='{}' then raise exception using errcode='22023',message='Invalid job tags'; end if;
 payload:=jsonb_build_object('job_id',p_job_id,'patch',patch);
 perform pg_advisory_xact_lock(hashtextextended(actor::text||':save_job_classification:'||p_request_id::text,0));
 select * into previous from private.command_requests where actor_id=actor and operation='save_job_classification' and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',previous.result_id);
 end if;
 select * into j from public.jobs where id=p_job_id and lifecycle<>'archived' for update;
 if not found then raise exception using errcode='P0002',message='Job unavailable'; end if;
 before_data:=jsonb_build_object('rain_day',j.rain_day,'filler',j.filler,'whole_house',j.whole_house,'trades',j.trades);
 update public.jobs set rain_day=case when patch?'rain_day' then (patch->>'rain_day')::boolean else rain_day end,
 filler=case when patch?'filler' then (patch->>'filler')::boolean else filler end,
 whole_house=case when patch?'whole_house' then (patch->>'whole_house')::boolean else whole_house end,
 trades=case when patch?'trades' then array(select jsonb_array_elements_text(patch->'trades')) else trades end,
 updated_by=actor,updated_at=clock_timestamp() where id=p_job_id returning * into j;
 insert into private.classification_events(job_id,actor_id,request_id,before_state,after_state) values(j.id,actor,p_request_id,before_data,jsonb_build_object('rain_day',j.rain_day,'filler',j.filler,'whole_house',j.whole_house,'trades',j.trades));
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id) values(j.id,actor,'save_job_classification',array(select jsonb_object_keys(patch)),p_request_id);
 insert into private.command_requests(actor_id,request_id,operation,payload,result_id) values(actor,p_request_id,'save_job_classification',payload,j.id);
 return jsonb_build_object('id',j.id);
end; $$;

-- Wrapper creates the normal job/default work and its optional tags in ONE transaction.
create function public.create_classified_job(p_request_id uuid,p_customer text,p_phone text,p_address text,p_classification jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); patch jsonb; payload jsonb; previous private.command_requests%rowtype; result jsonb;
begin
 perform 1 from public.app_users where id=actor and active and 'pm'=any(roles) for share;
 if not found then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 patch:=private.classification_patch(p_classification);
 payload:=jsonb_build_object('customer',p_customer,'phone',p_phone,'address',p_address,'classification',patch);
 perform pg_advisory_xact_lock(hashtextextended(actor::text||':create_classified_job:'||p_request_id::text,0));
 select * into previous from private.command_requests where actor_id=actor and operation='create_classified_job' and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',previous.result_id);
 end if;
 -- Do not upgrade a UUID previously used through the legacy create endpoint.
 if exists(select 1 from private.command_requests where actor_id=actor and operation='create_job' and request_id=p_request_id) then raise exception using errcode='23505',message='Request payload changed'; end if;
 result:=public.create_job(p_request_id,p_customer,p_phone,p_address);
 if patch<>'{}' then perform public.save_job_classification((result->>'id')::uuid,p_request_id,patch); end if;
 insert into private.command_requests(actor_id,request_id,operation,payload,result_id) values(actor,p_request_id,'create_classified_job',payload,(result->>'id')::uuid);
 return jsonb_build_object('id',result->>'id');
end; $$;

create table public.subcontractors(
 id uuid primary key default gen_random_uuid(),name text not null check(length(btrim(name)) between 1 and 100),
 phone text not null default '' check(length(phone)<=40),phone_action text check(phone_action ~ '^\+1[0-9]{10}$'),
 email text not null default '' check(length(email)<=254),trades text[] not null default '{}' check(private.valid_trade_ids(trades)),
 archived_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 created_by uuid not null references public.app_users(id),updated_by uuid not null references public.app_users(id),
 check((phone='')=(phone_action is null))
);
create index subcontractor_active_name on public.subcontractors(name,id) where archived_at is null;
alter table public.subcontractors enable row level security;
revoke all on public.subcontractors from public,anon,authenticated;
grant select on public.subcontractors to authenticated;
create policy subcontractor_directory_read on public.subcontractors for select to authenticated using(archived_at is null and (private.has_role('pm') or private.has_role('admin') or private.has_role('lead')));
create table private.subcontractor_events(
 id uuid primary key default gen_random_uuid(),subcontractor_id uuid not null references public.subcontractors(id),actor_id uuid not null references public.app_users(id),
 request_id uuid not null,before_state jsonb not null,after_state jsonb not null,created_at timestamptz not null default now()
);
alter table private.subcontractor_events enable row level security;
revoke all on private.subcontractor_events from public,anon,authenticated;

create function public.save_subcontractor(p_id uuid,p_request_id uuid,p_patch jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); patch jsonb:='{}'; k text; v text; ids jsonb; payload jsonb; previous private.command_requests%rowtype; s public.subcontractors%rowtype; before_data jsonb:='{}';
begin
 perform 1 from public.app_users where id=actor and active and roles&&array['pm','admin']::text[] for share;
 if not found then raise exception using errcode='42501',message='Directory manager required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 if p_patch is null or jsonb_typeof(p_patch)<>'object' or p_patch='{}' then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
 for k in select jsonb_object_keys(p_patch) loop
  if k='trades' then patch:=patch||private.classification_patch(jsonb_build_object(k,p_patch->k));
  elsif k='archive' and p_patch->k='true'::jsonb then patch:=patch||jsonb_build_object(k,true);
  elsif k in ('name','phone','email') and jsonb_typeof(p_patch->k)='string' then
   v:=btrim(p_patch->>k);
   if length(p_patch->>k)>(case k when 'name' then 100 when 'phone' then 40 else 254 end) or (p_patch->>k) ~ '[[:cntrl:]]' or (k='name' and v='') then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
   if k='phone' and v<>'' then perform private.phone_action(v); end if;
   if k='email' and v<>'' and v !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
   patch:=patch||jsonb_build_object(k,v);
  else raise exception using errcode='22023',message='Invalid subcontractor'; end if;
 end loop;
 if patch?'archive' and patch<>'{"archive":true}'::jsonb then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
 payload:=jsonb_build_object('id',p_id,'patch',patch);
 perform pg_advisory_xact_lock(hashtextextended(actor::text||':save_subcontractor:'||p_request_id::text,0));
 select * into previous from private.command_requests where actor_id=actor and operation='save_subcontractor' and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',previous.result_id);
 end if;
 -- Serialize directory capacity and row edits; no scheduling/queue locks needed.
 perform pg_advisory_xact_lock(hashtextextended('eigsti:subcontractors',0));
 if p_id is null then
  if not(patch?&array['name','phone','email','trades']) or patch?'archive' then raise exception using errcode='22023',message='Invalid subcontractor'; end if;
  if (select count(*) from public.subcontractors where archived_at is null)>=500 then raise exception using errcode='22023',message='Directory limit reached'; end if;
  insert into public.subcontractors(name,phone,phone_action,email,trades,created_by,updated_by) values(patch->>'name',patch->>'phone',case when patch->>'phone'='' then null else private.phone_action(patch->>'phone') end,patch->>'email',array(select jsonb_array_elements_text(patch->'trades')),actor,actor) returning * into s;
 else
  select * into s from public.subcontractors where id=p_id and archived_at is null for update;
  if not found then raise exception using errcode='P0002',message='Subcontractor unavailable'; end if;
  before_data:=to_jsonb(s);
  update public.subcontractors set name=coalesce(patch->>'name',name),phone=coalesce(patch->>'phone',phone),
   phone_action=case when patch?'phone' then case when patch->>'phone'='' then null else private.phone_action(patch->>'phone') end else phone_action end,
   email=coalesce(patch->>'email',email),trades=case when patch?'trades' then array(select jsonb_array_elements_text(patch->'trades')) else trades end,
   archived_at=case when patch?'archive' then clock_timestamp() else archived_at end,updated_at=clock_timestamp(),updated_by=actor where id=p_id returning * into s;
 end if;
 insert into private.subcontractor_events(subcontractor_id,actor_id,request_id,before_state,after_state) values(s.id,actor,p_request_id,before_data,to_jsonb(s));
 insert into private.command_requests(actor_id,request_id,operation,payload,result_id) values(actor,p_request_id,'save_subcontractor',payload,s.id);
 return jsonb_build_object('id',s.id);
end; $$;

revoke all on function private.valid_trade_ids(text[]),private.classification_patch(jsonb) from public,anon,authenticated;
revoke all on function public.save_job_classification(uuid,uuid,jsonb),public.create_classified_job(uuid,text,text,text,jsonb),public.save_subcontractor(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.save_job_classification(uuid,uuid,jsonb),public.create_classified_job(uuid,text,text,text,jsonb),public.save_subcontractor(uuid,uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
