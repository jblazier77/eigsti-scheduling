-- Apply AFTER 0001, in the isolated test project first. No seed data.
begin;

create table public.job_contacts (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete restrict,
  name text not null check (length(btrim(name)) between 1 and 100),
  relationship text not null default '' check (length(relationship) <= 100),
  phone text not null default '' check (length(phone) <= 40),
  phone_action text check (phone_action ~ '^\+1[0-9]{10}$'),
  email text not null default '' check (length(email) <= 254),
  notes text not null default '' check (length(notes) <= 1000),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid not null references public.app_users(id) on delete restrict,
  updated_by uuid not null references public.app_users(id) on delete restrict,
  check ((phone = '') = (phone_action is null))
);
create index job_contacts_active_job on public.job_contacts(job_id,created_at,id) where archived_at is null;
alter table public.job_contacts enable row level security;
revoke all on public.job_contacts from public,anon,authenticated;
grant select on public.job_contacts to authenticated;
create policy authorized_contact_read on public.job_contacts for select to authenticated
  using (archived_at is null and private.can_read_job(job_id));

-- Independent SQL validation is required even when the UI validates first.
create function private.contact_patch(p_patch jsonb,p_partial boolean)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare v_key text; v_value text; v_result jsonb := '{}'::jsonb;
begin
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' or p_patch = '{}'::jsonb then
    raise exception using errcode='22023',message='Invalid contact details';
  end if;
  if not p_partial and not (p_patch ?& array['name','relationship','phone','email','notes']) then
    raise exception using errcode='22023',message='Incomplete contact details';
  end if;
  for v_key in select jsonb_object_keys(p_patch) loop
    if v_key not in ('name','relationship','phone','email','notes') or jsonb_typeof(p_patch->v_key) <> 'string' then
      raise exception using errcode='22023',message='Invalid contact field';
    end if;
    v_value := p_patch->>v_key;
    if length(v_value) > (case v_key when 'name' then 100 when 'relationship' then 100 when 'phone' then 40 when 'email' then 254 else 1000 end)
      or (v_key <> 'notes' and v_value ~ '[[:cntrl:]]')
      or (v_key = 'notes' and regexp_replace(v_value,E'[\n\r\t]','','g') ~ '[[:cntrl:]]') then
      raise exception using errcode='22023',message='Invalid contact text';
    end if;
    if v_key <> 'notes' then v_value := btrim(v_value); end if;
    if v_key='name' and length(v_value)=0 then raise exception using errcode='22023',message='Contact name required'; end if;
    if v_key='phone' and v_value<>'' then perform private.phone_action(v_value); end if;
    if v_key='email' and v_value<>'' and v_value !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
      raise exception using errcode='22023',message='Invalid contact email';
    end if;
    v_result := v_result || jsonb_build_object(v_key,v_value);
  end loop;
  return v_result;
end;
$$;

create function public.create_job_contact(p_job_id uuid,p_request_id uuid,p_values jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := auth.uid(); v_values jsonb; v_payload jsonb; v_prior private.command_requests%rowtype; v_contact public.job_contacts%rowtype;
begin
  if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
  if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
  v_values := private.contact_patch(p_values,false);
  v_payload := jsonb_build_object('job_id',p_job_id,'values',v_values);
  perform pg_advisory_xact_lock(hashtextextended(v_actor::text || ':create_job_contact:' || p_request_id::text,0));
  select * into v_prior from private.command_requests where actor_id=v_actor and operation='create_job_contact' and request_id=p_request_id;
  if found then
    if v_prior.payload <> v_payload then raise exception using errcode='23505',message='Request payload changed'; end if;
    -- A retry confirms the original creation; it must not restore an archived contact.
    return jsonb_build_object('id',v_prior.result_id);
  end if;
  -- Serialize the per-job contact limit, including simultaneous creates by different PMs.
  perform 1 from public.jobs where id=p_job_id for update;
  if not found then raise exception using errcode='P0002',message='Job unavailable'; end if;
  if (select count(*) from public.job_contacts where job_id=p_job_id and archived_at is null) >= 100 then
    raise exception using errcode='22023',message='Contact limit reached';
  end if;
  insert into public.job_contacts(job_id,name,relationship,phone,phone_action,email,notes,created_by,updated_by)
    values(p_job_id,v_values->>'name',v_values->>'relationship',v_values->>'phone',
      case when v_values->>'phone'='' then null else private.phone_action(v_values->>'phone') end,
      v_values->>'email',v_values->>'notes',v_actor,v_actor) returning * into v_contact;
  insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
    values(p_job_id,v_actor,'create_job_contact',array['contact:' || v_contact.id::text,'name','relationship','phone','email','notes'],p_request_id);
  insert into private.command_requests(actor_id,request_id,operation,payload,result_id)
    values(v_actor,p_request_id,'create_job_contact',v_payload,v_contact.id);
  return jsonb_build_object('id',v_contact.id);
end;
$$;

create function public.update_job_contact(p_job_id uuid,p_contact_id uuid,p_patch jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_patch jsonb; v_contact public.job_contacts%rowtype; v_fields text[];
begin
  if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
  v_patch := private.contact_patch(p_patch,true);
  update public.job_contacts set
    name=case when v_patch ? 'name' then v_patch->>'name' else name end,
    relationship=case when v_patch ? 'relationship' then v_patch->>'relationship' else relationship end,
    phone=case when v_patch ? 'phone' then v_patch->>'phone' else phone end,
    phone_action=case when v_patch ? 'phone' then case when v_patch->>'phone'='' then null else private.phone_action(v_patch->>'phone') end else phone_action end,
    email=case when v_patch ? 'email' then v_patch->>'email' else email end,
    notes=case when v_patch ? 'notes' then v_patch->>'notes' else notes end,
    updated_at=clock_timestamp(),updated_by=auth.uid()
    where id=p_contact_id and job_id=p_job_id and archived_at is null returning * into v_contact;
  if not found then raise exception using errcode='P0002',message='Contact unavailable'; end if;
  select array_agg(key order by key) into v_fields from jsonb_object_keys(v_patch) key;
  insert into public.audit_events(job_id,actor_id,operation,changed_fields)
    values(p_job_id,auth.uid(),'update_job_contact',array['contact:' || p_contact_id::text] || v_fields);
  return jsonb_build_object('id',v_contact.id);
end;
$$;

create function public.archive_job_contact(p_job_id uuid,p_contact_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_contact public.job_contacts%rowtype;
begin
  if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
  select * into v_contact from public.job_contacts where id=p_contact_id and job_id=p_job_id for update;
  if not found then raise exception using errcode='P0002',message='Contact unavailable'; end if;
  if v_contact.archived_at is null then
    update public.job_contacts set archived_at=clock_timestamp(),updated_at=clock_timestamp(),updated_by=auth.uid() where id=p_contact_id;
    insert into public.audit_events(job_id,actor_id,operation,changed_fields)
      values(p_job_id,auth.uid(),'archive_job_contact',array['contact:' || p_contact_id::text,'archived_at']);
  end if;
  return jsonb_build_object('id',v_contact.id);
end;
$$;

revoke all on function private.contact_patch(jsonb,boolean) from public,anon,authenticated;
revoke all on function public.create_job_contact(uuid,uuid,jsonb),public.update_job_contact(uuid,uuid,jsonb),public.archive_job_contact(uuid,uuid) from public,anon,authenticated;
grant execute on function public.create_job_contact(uuid,uuid,jsonb),public.update_job_contact(uuid,uuid,jsonb),public.archive_job_contact(uuid,uuid) to authenticated;
comment on table public.job_contacts is 'Additional job contacts; access follows the job, PM-only command writes, removal archives without deleting history. Not a company trade directory.';
notify pgrst, 'reload schema';
commit;
