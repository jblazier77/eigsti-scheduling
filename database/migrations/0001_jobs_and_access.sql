-- Supabase PostgreSQL migration. NOT applied or runtime-verified in this environment.
-- Requires Supabase Auth schemas/roles. No customer or synthetic seed data here.
begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table public.app_users (
  id uuid primary key references auth.users(id) on delete restrict,
  display_name text not null check (length(btrim(display_name)) between 1 and 100),
  roles text[] not null check (cardinality(roles) > 0 and roles <@ array['admin','pm','lead','helper']::text[]),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null check (length(btrim(customer_name)) between 1 and 100),
  phone text not null check (length(btrim(phone)) between 1 and 40),
  phone_action text not null check (phone_action ~ '^\+1[0-9]{10}$'),
  address text not null check (length(btrim(address)) between 1 and 300),
  title text not null check (length(btrim(title)) between 1 and 405),
  scope text not null default '' check (length(scope) <= 5000),
  access_notes text not null default '' check (length(access_notes) <= 2000),
  responsible_pm uuid references public.app_users(id) on delete restrict,
  lifecycle text not null default 'open' check (lifecycle in ('open','closed','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid not null references public.app_users(id) on delete restrict,
  updated_by uuid not null references public.app_users(id) on delete restrict
);

create table public.work_items (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete restrict,
  description text not null check (length(btrim(description)) between 1 and 1000),
  responsible_lead uuid references public.app_users(id) on delete restrict,
  readiness text not null default 'ready' check (readiness in ('ready','waiting_date','waiting_unknown')),
  waiting_until date,
  completion text not null default 'open' check (completion in ('open','completed')),
  remaining_note text not null default '' check (length(remaining_note) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid not null references public.app_users(id) on delete restrict,
  updated_by uuid not null references public.app_users(id) on delete restrict,
  check ((readiness = 'waiting_date') = (waiting_until is not null))
);

-- Access entitlement only: does not reserve staff or create a helper schedule.
-- Phase 2 assignment transactions must maintain/revoke helper entitlements from visits.
-- No public write path, and no app UI for manually granting this ACL.
create table private.job_access (
  job_id uuid not null references public.jobs(id) on delete restrict,
  user_id uuid not null references public.app_users(id) on delete restrict,
  reason text not null check (reason in ('helping_assignment','shared_lead')),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid not null references public.app_users(id) on delete restrict,
  primary key (job_id,user_id,reason)
);

create table private.command_requests (
  actor_id uuid not null references public.app_users(id),
  request_id uuid not null,
  operation text not null,
  payload jsonb not null,
  result_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (actor_id,operation,request_id)
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete restrict,
  actor_id uuid not null references public.app_users(id) on delete restrict,
  operation text not null,
  changed_fields text[] not null,
  request_id uuid,
  created_at timestamptz not null default now()
);

create index jobs_pm_lifecycle on public.jobs(responsible_pm,lifecycle,created_at desc,id desc);
create index jobs_created on public.jobs(created_at desc,id desc);
create index work_lead_job on public.work_items(responsible_lead,job_id);
create index work_job on public.work_items(job_id);
create index access_user_job on private.job_access(user_id,job_id) where revoked_at is null;
create index audit_job_created on public.audit_events(job_id,created_at desc);

create function private.has_role(p_role text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.app_users u where u.id = auth.uid() and u.active and p_role = any(u.roles));
$$;

create function private.can_read_job(p_job_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.app_users u where u.id = auth.uid() and u.active and (
      'pm' = any(u.roles)
      or ('lead' = any(u.roles) and exists (
        select 1 from public.work_items w where w.job_id = p_job_id and w.responsible_lead = u.id))
      or (u.roles && array['lead','helper']::text[]
        and exists (select 1 from public.jobs j where j.id=p_job_id and j.lifecycle='open') and exists (
        select 1 from private.job_access a where a.user_id = u.id and a.job_id = p_job_id and a.revoked_at is null))
    )
  );
$$;

create function private.phone_action(p_phone text)
returns text language plpgsql immutable set search_path = '' as $$
declare v_digits text;
begin
  if p_phone is null or length(btrim(p_phone)) not between 1 and 40 or p_phone !~ '^[+()0-9[:space:].-]+$' then
    raise exception using errcode = '22023', message = 'Invalid phone';
  end if;
  v_digits := regexp_replace(p_phone, '[^0-9]', '', 'g');
  if length(v_digits) = 10 then return '+1' || v_digits; end if;
  if length(v_digits) = 11 and left(v_digits,1) = '1' then return '+' || v_digits; end if;
  raise exception using errcode = '22023', message = 'Invalid phone';
end;
$$;

alter table public.app_users enable row level security;
alter table public.jobs enable row level security;
alter table public.work_items enable row level security;
alter table public.audit_events enable row level security;
alter table private.job_access enable row level security;
alter table private.command_requests enable row level security;

revoke all on public.app_users, public.jobs, public.work_items, public.audit_events from public, anon, authenticated;
revoke all on private.job_access, private.command_requests from public, anon, authenticated;
grant select on public.app_users, public.jobs, public.work_items, public.audit_events to authenticated;

create policy own_active_profile on public.app_users for select to authenticated using (id = (select auth.uid()) and active);
create policy authorized_job_read on public.jobs for select to authenticated using (private.can_read_job(id));
create policy authorized_work_read on public.work_items for select to authenticated using (private.can_read_job(job_id));
create policy authorized_audit_read on public.audit_events for select to authenticated using (
  private.has_role('pm') or (private.has_role('lead') and private.can_read_job(job_id))
);

create function public.create_job(p_request_id uuid, p_customer text, p_phone text, p_address text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_payload jsonb;
  v_prior private.command_requests%rowtype;
  v_job public.jobs%rowtype;
  v_phone_action text;
begin
  if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
  if p_request_id is null or p_customer is null or p_address is null
    or length(btrim(p_customer)) not between 1 and 100 or length(btrim(p_address)) not between 1 and 300
    or p_customer ~ '[[:cntrl:]]' or p_address ~ '[[:cntrl:]]' then
    raise exception using errcode='22023',message='Invalid job details';
  end if;
  v_phone_action := private.phone_action(p_phone);
  v_payload := jsonb_build_object('customer',btrim(p_customer),'phone',btrim(p_phone),'address',btrim(p_address));
  -- Serialize identical retries even if they arrive before the first commit.
  perform pg_advisory_xact_lock(hashtextextended(v_actor::text || ':create_job:' || p_request_id::text,0));
  select * into v_prior from private.command_requests where actor_id=v_actor and operation='create_job' and request_id=p_request_id;
  if found then
    if v_prior.payload <> v_payload then raise exception using errcode='23505',message='Request payload changed'; end if;
    select * into strict v_job from public.jobs where id=v_prior.result_id;
    return to_jsonb(v_job);
  end if;
  insert into public.jobs(customer_name,phone,phone_action,address,title,responsible_pm,created_by,updated_by)
    values(btrim(p_customer),btrim(p_phone),v_phone_action,btrim(p_address),btrim(p_customer) || ' - ' || btrim(p_address),v_actor,v_actor,v_actor)
    returning * into v_job;
  insert into public.work_items(job_id,description,created_by,updated_by)
    values(v_job.id,'Whole job',v_actor,v_actor);
  insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
    values(v_job.id,v_actor,'create_job',array['customer_name','phone','address','default_work_item'],p_request_id);
  insert into private.command_requests(actor_id,request_id,operation,payload,result_id)
    values(v_actor,p_request_id,'create_job',v_payload,v_job.id);
  return to_jsonb(v_job);
end;
$$;

create function public.update_job(p_job_id uuid,p_patch jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_job public.jobs%rowtype; v_key text; v_value text; v_fields text[];
begin
  if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' or p_patch = '{}'::jsonb then
    raise exception using errcode='22023',message='Invalid patch';
  end if;
  for v_key in select jsonb_object_keys(p_patch) loop
    if v_key not in ('customer_name','phone','address','title','scope','access_notes') or jsonb_typeof(p_patch->v_key) <> 'string' then
      raise exception using errcode='22023',message='Invalid patch field';
    end if;
    v_value := p_patch->>v_key;
    if v_key in ('customer_name','phone','address','title') and length(btrim(v_value)) = 0 then
      raise exception using errcode='22023',message='Required field';
    end if;
    if length(v_value) > (case v_key when 'customer_name' then 100 when 'phone' then 40 when 'address' then 300 when 'title' then 405 when 'scope' then 5000 else 2000 end)
      or (v_value ~ '[[:cntrl:]]' and v_key in ('customer_name','phone','address','title')) then
      raise exception using errcode='22023',message='Invalid patch length';
    end if;
  end loop;
  -- UPDATE locks only this job. Current values for omitted fields survive concurrent saves.
  update public.jobs set
    customer_name=case when p_patch ? 'customer_name' then btrim(p_patch->>'customer_name') else customer_name end,
    phone=case when p_patch ? 'phone' then btrim(p_patch->>'phone') else phone end,
    phone_action=case when p_patch ? 'phone' then private.phone_action(p_patch->>'phone') else phone_action end,
    address=case when p_patch ? 'address' then btrim(p_patch->>'address') else address end,
    title=case when p_patch ? 'title' then btrim(p_patch->>'title') else title end,
    scope=case when p_patch ? 'scope' then p_patch->>'scope' else scope end,
    access_notes=case when p_patch ? 'access_notes' then p_patch->>'access_notes' else access_notes end,
    updated_at=clock_timestamp(),updated_by=auth.uid()
    where id=p_job_id returning * into v_job;
  if not found then raise exception using errcode='P0002',message='Job not found'; end if;
  select array_agg(key order by key) into v_fields from jsonb_object_keys(p_patch) key;
  insert into public.audit_events(job_id,actor_id,operation,changed_fields) values(v_job.id,auth.uid(),'update_job',v_fields);
  return to_jsonb(v_job);
end;
$$;

revoke all on function private.has_role(text), private.can_read_job(uuid), private.phone_action(text) from public,anon,authenticated;
grant execute on function private.has_role(text), private.can_read_job(uuid) to authenticated;
revoke all on function public.create_job(uuid,text,text,text), public.update_job(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.create_job(uuid,text,text,text), public.update_job(uuid,jsonb) to authenticated;

comment on table private.job_access is 'Job information entitlement only; no staffing reservation. Maintain from named visits in Phase 2.';
comment on function public.create_job(uuid,text,text,text) is 'PM-only atomic job, default work item, audit and retry record.';
commit;
