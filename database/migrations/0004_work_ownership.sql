-- Apply once after 0001-0003 in the isolated test project. No seed data.
begin;

create function private.work_patch(p_patch jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare v_key text; v_text text; v_result jsonb := '{}'::jsonb;
begin
  if p_patch is null or jsonb_typeof(p_patch)<>'object' or p_patch='{}'::jsonb then
    raise exception using errcode='22023',message='Invalid work details';
  end if;
  for v_key in select jsonb_object_keys(p_patch) loop
    if v_key='description' then
      v_text := p_patch->>v_key;
      if jsonb_typeof(p_patch->v_key)<>'string' or length(v_text)>1000 or length(btrim(v_text)) not between 1 and 1000 or v_text ~ '[[:cntrl:]]' then
        raise exception using errcode='22023',message='Invalid work description';
      end if;
      v_result := v_result || jsonb_build_object(v_key,btrim(v_text));
    elsif v_key='responsible_lead' then
      if p_patch->v_key='null'::jsonb then
        v_result := v_result || jsonb_build_object(v_key,null);
      else
        v_text := p_patch->>v_key;
        if jsonb_typeof(p_patch->v_key)<>'string' or v_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
          raise exception using errcode='22023',message='Invalid lead identifier';
        end if;
        v_result := v_result || jsonb_build_object(v_key,(v_text::uuid)::text);
      end if;
    else
      raise exception using errcode='22023',message='Invalid work field';
    end if;
  end loop;
  return v_result;
end;
$$;

-- Scoped directory: no email, credentials or unrelated job details are exposed.
create function public.list_assignable_leads()
returns table(id uuid,display_name text) language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
  return query select u.id,u.display_name from public.app_users u where u.active and 'lead'=any(u.roles) order by u.display_name,u.id;
end;
$$;

create function public.list_job_work(p_job_id uuid)
returns table(id uuid,job_id uuid,description text,responsible_lead uuid,lead_name text,completion text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.can_read_job(p_job_id) then raise exception using errcode='42501',message='Job access required'; end if;
  return query select w.id,w.job_id,w.description,w.responsible_lead,
    case when u.id is null then null else u.display_name || case when u.active then '' else ' (inactive)' end end,
    w.completion from public.work_items w left join public.app_users u on u.id=w.responsible_lead
    where w.job_id=p_job_id order by w.created_at,w.id;
end;
$$;

create function public.create_job_work(p_job_id uuid,p_request_id uuid,p_values jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := auth.uid(); v_values jsonb; v_payload jsonb; v_prior private.command_requests%rowtype;
  v_work public.work_items%rowtype; v_lead uuid; v_lifecycle text;
begin
  if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
  if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
  v_values := private.work_patch(p_values);
  if not (v_values ?& array['description','responsible_lead']) then raise exception using errcode='22023',message='Incomplete work details'; end if;
  v_payload := jsonb_build_object('job_id',p_job_id,'values',v_values);
  perform pg_advisory_xact_lock(hashtextextended(v_actor::text || ':create_job_work:' || p_request_id::text,0));
  select * into v_prior from private.command_requests where actor_id=v_actor and operation='create_job_work' and request_id=p_request_id;
  if found then
    if v_prior.payload<>v_payload then raise exception using errcode='23505',message='Request payload changed'; end if;
    return jsonb_build_object('id',v_prior.result_id);
  end if;
  select lifecycle into v_lifecycle from public.jobs where id=p_job_id for update;
  if not found or v_lifecycle<>'open' then raise exception using errcode='P0002',message='Open job required'; end if;
  if (select count(*) from public.work_items where job_id=p_job_id)>=100 then raise exception using errcode='22023',message='Work limit reached'; end if;
  v_lead := (v_values->>'responsible_lead')::uuid;
  if v_lead is not null then
    perform 1 from public.app_users where id=v_lead and active and 'lead'=any(roles) for share;
    if not found then raise exception using errcode='22023',message='Active lead required'; end if;
  end if;
  insert into public.work_items(job_id,description,responsible_lead,created_by,updated_by)
    values(p_job_id,v_values->>'description',v_lead,v_actor,v_actor) returning * into v_work;
  insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
    values(p_job_id,v_actor,'create_job_work',array['work:' || v_work.id::text,'description','responsible_lead'],p_request_id);
  insert into private.command_requests(actor_id,request_id,operation,payload,result_id)
    values(v_actor,p_request_id,'create_job_work',v_payload,v_work.id);
  return jsonb_build_object('id',v_work.id);
end;
$$;

create function public.update_job_work(p_job_id uuid,p_work_id uuid,p_patch jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := auth.uid(); v_patch jsonb; v_work public.work_items%rowtype;
  v_lead uuid; v_description text; v_lifecycle text; v_fields text[] := array[]::text[];
begin
  if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
  v_patch := private.work_patch(p_patch);
  select lifecycle into v_lifecycle from public.jobs where id=p_job_id for update;
  if not found or v_lifecycle<>'open' then raise exception using errcode='P0002',message='Open job required'; end if;
  select * into v_work from public.work_items where id=p_work_id and job_id=p_job_id for update;
  if not found then raise exception using errcode='P0002',message='Work unavailable'; end if;
  if v_work.completion<>'open' then raise exception using errcode='22023',message='Open work required'; end if;
  v_lead := case when v_patch ? 'responsible_lead' then (v_patch->>'responsible_lead')::uuid else v_work.responsible_lead end;
  v_description := case when v_patch ? 'description' then v_patch->>'description' else v_work.description end;
  if v_lead is distinct from v_work.responsible_lead then
    if v_lead is not null then
      perform 1 from public.app_users where id=v_lead and active and 'lead'=any(roles) for share;
      if not found then raise exception using errcode='22023',message='Active lead required'; end if;
    end if;
    v_fields := array_append(v_fields,'responsible_lead');
  end if;
  if v_description is distinct from v_work.description then v_fields := array_append(v_fields,'description'); end if;
  if cardinality(v_fields)>0 then
    update public.work_items set description=v_description,responsible_lead=v_lead,updated_by=v_actor,updated_at=now() where id=v_work.id;
    insert into public.audit_events(job_id,actor_id,operation,changed_fields)
      values(p_job_id,v_actor,'update_job_work',array['work:' || v_work.id::text] || v_fields);
  end if;
  return jsonb_build_object('id',v_work.id);
end;
$$;

revoke all on function private.work_patch(jsonb) from public,anon,authenticated;
revoke all on function public.list_assignable_leads(),public.list_job_work(uuid),public.create_job_work(uuid,uuid,jsonb),public.update_job_work(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.list_assignable_leads(),public.list_job_work(uuid),public.create_job_work(uuid,uuid,jsonb),public.update_job_work(uuid,uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
