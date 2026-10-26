-- Apply once after 0017. Atomic updates for the unified work editor.
begin;
create function public.save_work_setup(p_work_id uuid,p_request_id uuid,p_patch jsonb,p_materials jsonb,p_plan jsonb,p_visits jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items%rowtype; j public.jobs%rowtype; payload jsonb; prior private.command_requests%rowtype; k text; entry jsonb; visit_id uuid; seen uuid[]:=array[]::uuid[]; roster uuid[];
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not(private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Work planner required'; end if;
 if p_request_id is null or p_patch is null or jsonb_typeof(p_patch)<>'object' then raise exception using errcode='22023',message='Invalid work details'; end if;
 p_materials:=nullif(p_materials,'null'::jsonb);p_plan:=nullif(p_plan,'null'::jsonb);
 if p_visits is null or jsonb_typeof(p_visits)<>'array' or jsonb_array_length(p_visits)>100 then raise exception using errcode='22023',message='Invalid work dates'; end if;
 select x.* into j from public.jobs x join public.work_items y on y.job_id=x.id where y.id=p_work_id for update of x;
 select * into w from public.work_items where id=p_work_id for update;
 if w.id is null or j.lifecycle<>'open' or w.completion<>'open' then raise exception using errcode='P0002',message='Open work required'; end if;
 if not private.can_read_job(j.id) then raise exception using errcode='42501',message='Job access required'; end if;
 if (p_patch<>'{}'::jsonb or p_materials is not null) and not private.has_role('pm') and w.responsible_lead is distinct from auth.uid() then raise exception using errcode='42501',message='Responsible lead required'; end if;
 payload:=jsonb_build_object('work',p_work_id,'patch',p_patch,'materials',p_materials,'plan',p_plan,'visits',p_visits);
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='save_work_setup' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',w.id,'job_id',j.id);
 end if;
 if exists(select 1 from private.command_requests where actor_id=auth.uid() and request_id=p_request_id and operation in ('save_work_details','save_work_materials','save_visit')) then raise exception using errcode='23505',message='Request payload changed'; end if;
 if p_patch<>'{}'::jsonb then perform public.save_work_details(w.id,p_request_id,p_patch); end if;
 if p_materials is not null then perform public.save_work_materials(w.id,p_request_id,p_materials); end if;
 if p_plan is not null then
  if exists(select 1 from public.visits where work_item_id=w.id and state='planned' and start_date=(p_plan->>'start_date')::date and end_date=(p_plan->>'end_date')::date and coordinator_id=(p_plan->>'coordinator_id')::uuid and slot=p_plan->>'slot' and start_time is not distinct from (p_plan->>'start_time')::time and end_time is not distinct from (p_plan->>'end_time')::time) then raise exception using errcode='22023',message='Edit existing work dates'; end if;
  perform public.save_visit(w.id,null,p_request_id,p_plan);
 end if;
 for entry in select value from jsonb_array_elements(p_visits) loop
  if jsonb_typeof(entry)<>'object' or not(entry ?& array['id','patch','helpers','cancel']) or (select count(*) from jsonb_object_keys(entry))<>4 then raise exception using errcode='22023',message='Invalid work dates'; end if;
  visit_id:=(entry->>'id')::uuid;
  if visit_id is null or visit_id=any(seen) then raise exception using errcode='22023',message='Invalid work dates'; end if;
  seen:=array_append(seen,visit_id);
  perform id from public.visits where id=visit_id and work_item_id=w.id and state='planned' for update;
  if not found then raise exception using errcode='P0002',message='Visit unavailable'; end if;
  if jsonb_typeof(entry->'cancel')<>'boolean' then raise exception using errcode='22023',message='Invalid work dates'; end if;
  if (entry->>'cancel')::boolean then
   perform public.save_visit(w.id,visit_id,gen_random_uuid(),'{"state":"cancelled"}'::jsonb);
  else
   roster:=null;
   if entry->'helpers'<>'null'::jsonb then
    if jsonb_typeof(entry->'helpers')<>'array' then raise exception using errcode='22023',message='Invalid staffing'; end if;
    select coalesce(array_agg(x::uuid),'{}'::uuid[]) into roster from jsonb_array_elements_text(entry->'helpers') x;
   end if;
   perform public.save_visit_card(w.id,visit_id,gen_random_uuid(),entry->'patch',roster);
  end if;
 end loop;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'save_work_setup',p_request_id,payload,w.id);
 return jsonb_build_object('id',w.id,'job_id',j.id);
end; $$;
revoke all on function public.save_work_setup(uuid,uuid,jsonb,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.save_work_setup(uuid,uuid,jsonb,jsonb,jsonb,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
