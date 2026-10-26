-- Apply once after 0018. Select named help before the first dated save.
begin;
create function public.planning_staff(p_job_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not(private.has_role('pm') or (p_job_id is not null and private.has_role('lead') and private.can_read_job(p_job_id))) then raise exception using errcode='42501',message='Work planner required'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.display_name,'busy',false) order by u.display_name,u.id) from public.app_users u where u.active and u.roles && array['lead','helper']::text[]),'[]'::jsonb);
end; $$;
create function private.planning_helpers(p_helpers jsonb) returns uuid[] language plpgsql immutable set search_path='' as $$
declare result uuid[];
begin
 if p_helpers is null or p_helpers='null'::jsonb then return null; end if;
 if jsonb_typeof(p_helpers)<>'array' or jsonb_array_length(p_helpers)>20 then raise exception using errcode='22023',message='Invalid staffing'; end if;
 if exists(select 1 from jsonb_array_elements(p_helpers) x where jsonb_typeof(x)<>'string' or (x#>>'{}')!~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then raise exception using errcode='22023',message='Invalid staffing'; end if;
 select coalesce(array_agg(x::uuid order by x::uuid),'{}'::uuid[]) into result from jsonb_array_elements_text(p_helpers) x;
 if cardinality(result)<>(select count(distinct x) from unnest(result) x) then raise exception using errcode='22023',message='Invalid staffing'; end if;
 return result;
end; $$;
revoke all on function private.planning_helpers(jsonb) from public,anon,authenticated;
create function public.save_work_setup_with_help(p_work_id uuid,p_request_id uuid,p_patch jsonb,p_materials jsonb,p_plan jsonb,p_visits jsonb,p_new_helpers jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare roster uuid[]; payload jsonb; prior private.command_requests%rowtype; result jsonb; new_visit uuid; job_id uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not(private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Work planner required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 select w.job_id into job_id from public.work_items w where w.id=p_work_id;
 if job_id is null or not private.can_read_job(job_id) then raise exception using errcode='42501',message='Job access required'; end if;
 p_plan:=nullif(p_plan,'null'::jsonb);p_materials:=nullif(p_materials,'null'::jsonb);roster:=private.planning_helpers(p_new_helpers);
 if cardinality(roster)>0 and p_plan is null then raise exception using errcode='22023',message='Choose a date to assign named help'; end if;
 payload:=jsonb_build_object('work',p_work_id,'patch',p_patch,'materials',p_materials,'plan',p_plan,'visits',p_visits,'helpers',to_jsonb(roster));
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='save_work_setup_with_help' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',p_work_id,'job_id',job_id);
 end if;
 if exists(select 1 from private.command_requests where actor_id=auth.uid() and operation='save_work_setup' and request_id=p_request_id) then raise exception using errcode='23505',message='Request payload changed'; end if;
 result:=public.save_work_setup(p_work_id,p_request_id,p_patch,p_materials,p_plan,p_visits);
 if p_plan is not null and roster is not null then
  select result_id into new_visit from private.command_requests where actor_id=auth.uid() and operation='save_visit' and request_id=p_request_id;
  if new_visit is null then raise exception using errcode='P0002',message='Visit unavailable'; end if;
  perform public.staff_visit(new_visit,gen_random_uuid(),roster);
 end if;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'save_work_setup_with_help',p_request_id,payload,p_work_id);
 return result;
end; $$;
create function public.create_staffed_work(p_job_id uuid,p_request_id uuid,p_values jsonb,p_plan jsonb,p_helpers integer,p_materials jsonb,p_days jsonb,p_named_helpers jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare roster uuid[]; payload jsonb; prior private.command_requests%rowtype; result jsonb; new_visit uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 p_plan:=nullif(p_plan,'null'::jsonb);p_materials:=nullif(p_materials,'null'::jsonb);roster:=private.planning_helpers(p_named_helpers);
 if cardinality(roster)>0 and p_plan is null then raise exception using errcode='22023',message='Choose a date to assign named help'; end if;
 payload:=jsonb_build_object('job',p_job_id,'values',p_values,'plan',p_plan,'helpers',p_helpers,'materials',p_materials,'days',p_days,'named',to_jsonb(roster));
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='create_staffed_work' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 if exists(select 1 from private.command_requests where actor_id=auth.uid() and operation='create_planning_work' and request_id=p_request_id) then raise exception using errcode='23505',message='Request payload changed'; end if;
 result:=public.create_planning_work(p_job_id,p_request_id,p_values,p_plan,p_helpers,p_materials,p_days);
 if p_plan is not null and roster is not null then
  select result_id into new_visit from private.command_requests where actor_id=auth.uid() and operation='save_visit' and request_id=p_request_id;
  if new_visit is null then raise exception using errcode='P0002',message='Visit unavailable'; end if;
  perform public.staff_visit(new_visit,gen_random_uuid(),roster);
 end if;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'create_staffed_work',p_request_id,payload,(result->>'id')::uuid);
 return result;
end; $$;
revoke all on function public.planning_staff(uuid),public.save_work_setup_with_help(uuid,uuid,jsonb,jsonb,jsonb,jsonb,jsonb),public.create_staffed_work(uuid,uuid,jsonb,jsonb,integer,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.planning_staff(uuid),public.save_work_setup_with_help(uuid,uuid,jsonb,jsonb,jsonb,jsonb,jsonb),public.create_staffed_work(uuid,uuid,jsonb,jsonb,integer,jsonb,jsonb,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
