-- Apply once after 0008. Combine narrow visit fields and optional roster in one transaction.
begin;
create function public.save_visit_card(p_work_id uuid,p_visit_id uuid,p_request_id uuid,p_patch jsonb,p_helpers uuid[] default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.visits%rowtype; w public.work_items%rowtype; j public.jobs%rowtype;
 v_ids uuid[]; v_prior private.command_requests%rowtype; v_payload jsonb; k text;
begin
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Visit planning required'; end if;
 if p_work_id is null or p_visit_id is null or p_request_id is null or p_patch is null or jsonb_typeof(p_patch)<>'object'
 then raise exception using errcode='22023',message='Invalid visit'; end if;
 for k in select jsonb_object_keys(p_patch) loop
  if k not in ('start_date','end_date','slot','start_time','end_time','coordinator_id','required_helpers','certainty')
  then raise exception using errcode='22023',message='Invalid visit field'; end if;
 end loop;
 if p_helpers is not null then
  if cardinality(p_helpers)>20 or (cardinality(p_helpers)>0 and array_ndims(p_helpers)<>1) or array_position(p_helpers,null) is not null
  then raise exception using errcode='22023',message='Invalid staffing'; end if;
  select coalesce(array_agg(x order by x),'{}'::uuid[]) into v_ids from (select distinct unnest(p_helpers) x) s;
  if cardinality(v_ids)<>cardinality(p_helpers) then raise exception using errcode='22023',message='Invalid staffing'; end if;
 end if;
 if p_patch='{}'::jsonb and p_helpers is null then raise exception using errcode='22023',message='Invalid visit'; end if;
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Visit planning required'; end if;
 select x.* into j from public.jobs x join public.work_items y on y.job_id=x.id where y.id=p_work_id for update of x;
 select * into w from public.work_items where id=p_work_id for update;
 select * into v from public.visits where id=p_visit_id and work_item_id=p_work_id for update;
 if v.id is null then raise exception using errcode='P0002',message='Visit unavailable'; end if;
 if not private.has_role('pm') and v.coordinator_id<>auth.uid() then raise exception using errcode='42501',message='Visit coordinator required'; end if;
 v_payload:=jsonb_build_object('work',p_work_id,'visit',p_visit_id,'patch',p_patch,'helpers',to_jsonb(v_ids));
 select * into v_prior from private.command_requests where actor_id=auth.uid() and operation='save_visit_card' and request_id=p_request_id;
 if found then
  if v_prior.payload<>v_payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return private.visit_result(v.id);
 end if;
 if j.lifecycle<>'open' or w.completion<>'open' or v.state<>'planned' then raise exception using errcode='22023',message='Open work required'; end if;
 -- Check against the ORIGINAL roster before temporarily clearing it. Leads cannot
 -- remove named help even by reducing need or changing dates in the same request.
 if p_helpers is not null and not private.has_role('pm') and exists(select 1 from public.visit_participants where visit_id=v.id and duty='helping' and not user_id=any(v_ids))
 then raise exception using errcode='42501',message='PM required to replace named help'; end if;
 if p_patch<>'{}'::jsonb then
  if p_helpers is not null then delete from public.visit_participants where visit_id=v.id and duty='helping'; end if;
  perform public.save_visit(w.id,v.id,gen_random_uuid(),p_patch);
 end if;
 if p_helpers is not null then perform public.staff_visit(v.id,gen_random_uuid(),v_ids); end if;
 -- Existing helpers retain their command-step audit snapshots. The card-level
 -- snapshot below records the final complete roster; no historical event is changed.
 insert into private.visit_events(visit_id,actor_id,request_id,operation,snapshot)
 values(v.id,auth.uid(),p_request_id,'save_visit_card',private.visit_result(v.id));
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
 values(w.job_id,auth.uid(),'save_visit_card',array(select jsonb_object_keys(p_patch) union select 'participants' where p_helpers is not null),p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id)
 values(auth.uid(),'save_visit_card',p_request_id,v_payload,v.id);
 return private.visit_result(v.id);
end; $$;
revoke all on function public.save_visit_card(uuid,uuid,uuid,jsonb,uuid[]) from public,anon,authenticated;
grant execute on function public.save_visit_card(uuid,uuid,uuid,jsonb,uuid[]) to authenticated;
commit;
