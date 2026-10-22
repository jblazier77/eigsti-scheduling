-- Apply once after 0001-0004. Lead contact creation only; no seed data.
begin;

create or replace function public.create_job_contact(p_job_id uuid,p_request_id uuid,p_values jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := auth.uid(); v_values jsonb; v_payload jsonb; v_prior private.command_requests%rowtype; v_contact public.job_contacts%rowtype;
begin
  if not (private.has_role('pm') or (private.has_role('lead') and private.can_read_job(p_job_id))) then raise exception using errcode='42501',message='PM or assigned lead required'; end if;
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
  -- Recheck access after waiting for the parent lock used by ownership changes.
  if not (private.has_role('pm') or (private.has_role('lead') and private.can_read_job(p_job_id))) then raise exception using errcode='42501',message='PM or assigned lead required'; end if;
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

revoke all on function public.create_job_contact(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.create_job_contact(uuid,uuid,jsonb) to authenticated;
comment on table public.job_contacts is 'Additional job contacts; PM or assigned lead creation, PM-only update/archive; job-scoped reads and retained removal history.';
notify pgrst,'reload schema';
commit;
