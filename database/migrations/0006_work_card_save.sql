-- Apply once after 0001-0005 in isolated test. No seed data.
begin;

create function public.update_job_work_batch(p_job_id uuid,p_request_id uuid,p_changes jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := auth.uid(); v_change jsonb; v_id uuid; v_patch jsonb;
  v_seen uuid[] := array[]::uuid[]; v_changes jsonb := '[]'::jsonb;
  v_payload jsonb; v_prior private.command_requests%rowtype; v_lifecycle text;
begin
  if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
  if p_request_id is null or p_changes is null or jsonb_typeof(p_changes)<>'array' then
    raise exception using errcode='22023',message='Invalid work changes';
  end if;
  if jsonb_array_length(p_changes) not between 1 and 100 then raise exception using errcode='22023',message='Invalid work changes'; end if;
  for v_change in select value from jsonb_array_elements(p_changes) loop
    if jsonb_typeof(v_change)<>'object' then raise exception using errcode='22023',message='Invalid work changes'; end if;
    if not (v_change ?& array['work_id','patch']) or (select count(*) from jsonb_object_keys(v_change))<>2
      or jsonb_typeof(v_change->'work_id')<>'string'
      or (v_change->>'work_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      raise exception using errcode='22023',message='Invalid work changes';
    end if;
    v_id := (v_change->>'work_id')::uuid;
    if v_id=any(v_seen) then raise exception using errcode='22023',message='Duplicate work change'; end if;
    v_seen := array_append(v_seen,v_id);
    v_patch := private.work_patch(v_change->'patch');
    v_changes := v_changes || jsonb_build_array(jsonb_build_object('work_id',v_id,'patch',v_patch));
  end loop;
  select jsonb_agg(value order by value->>'work_id') into v_changes from jsonb_array_elements(v_changes);
  v_payload := jsonb_build_object('job_id',p_job_id,'changes',v_changes);
  perform pg_advisory_xact_lock(hashtextextended(v_actor::text || ':update_job_work_batch:' || p_request_id::text,0));
  select * into v_prior from private.command_requests where actor_id=v_actor and operation='update_job_work_batch' and request_id=p_request_id;
  if found then
    if v_prior.payload<>v_payload then raise exception using errcode='23505',message='Request payload changed'; end if;
    -- A lost response may be retried without replaying old edits over newer work.
    return jsonb_build_object('id',v_prior.result_id,'work',coalesce((select jsonb_agg(to_jsonb(w)) from public.list_job_work(p_job_id) w),'[]'::jsonb));
  end if;
  select lifecycle into v_lifecycle from public.jobs where id=p_job_id for update;
  if not found or v_lifecycle<>'open' then raise exception using errcode='P0002',message='Open job required'; end if;
  -- Each existing command preserves its role/parent/open-work/active-lead checks.
  -- Any exception aborts this entire RPC, including earlier row and audit writes.
  for v_change in select value from jsonb_array_elements(v_changes) loop
    perform public.update_job_work(p_job_id,(v_change->>'work_id')::uuid,v_change->'patch');
  end loop;
  insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
    values(p_job_id,v_actor,'update_job_work_batch',array(select 'work:' || (value->>'work_id') from jsonb_array_elements(v_changes)),p_request_id);
  insert into private.command_requests(actor_id,request_id,operation,payload,result_id)
    values(v_actor,p_request_id,'update_job_work_batch',v_payload,p_job_id);
  return jsonb_build_object('id',p_job_id,'work',coalesce((select jsonb_agg(to_jsonb(w)) from public.list_job_work(p_job_id) w),'[]'::jsonb));
end;
$$;
revoke all on function public.update_job_work_batch(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.update_job_work_batch(uuid,uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
