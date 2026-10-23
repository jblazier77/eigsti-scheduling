-- Apply once after applied 0012. Keep all quick-work details in one transaction.
begin;
alter table public.work_items add column default_helpers integer not null default 0 check(default_helpers between 0 and 20);
create function public.create_quick_work(p_job_id uuid,p_request_id uuid,p_values jsonb,p_plan jsonb,p_helpers integer,p_materials jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare vals jsonb; plan_values jsonb; payload jsonb; prior private.command_requests%rowtype; result jsonb; work_id uuid;
begin
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_job_id is null or p_request_id is null or p_helpers is null or p_helpers not between 0 and 20 then raise exception using errcode='22023',message='Invalid helper count'; end if;
 vals:=private.work_patch(p_values);
 if not(vals ?& array['description','responsible_lead']) then raise exception using errcode='22023',message='Incomplete work details'; end if;
 plan_values:=p_plan;
 if p_plan is not null then
  if jsonb_typeof(p_plan)<>'object' then raise exception using errcode='22023',message='Invalid visit'; end if;
  if p_plan ? 'required_helpers' and p_plan->'required_helpers' is distinct from to_jsonb(p_helpers) then raise exception using errcode='22023',message='Invalid helper count'; end if;
  plan_values:=p_plan||jsonb_build_object('required_helpers',p_helpers);
 end if;
 payload:=jsonb_build_object('job',p_job_id,'values',vals,'plan',plan_values,'helpers',p_helpers,'materials',p_materials);
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 perform id from public.jobs where id=p_job_id and lifecycle='open' for update;
 if not found then raise exception using errcode='P0002',message='Open job required'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='create_quick_work' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 result:=public.create_job_work_with_plan(p_job_id,p_request_id,vals,plan_values);work_id:=(result->>'id')::uuid;
 update public.work_items set default_helpers=p_helpers,updated_at=clock_timestamp(),updated_by=auth.uid() where id=work_id;
 if p_materials is not null then perform public.save_work_materials(work_id,p_request_id,p_materials); end if;
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
 values(p_job_id,auth.uid(),'create_quick_work',array['work:'||work_id::text,'default_helpers','schedule','materials'],p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id)
 values(auth.uid(),'create_quick_work',p_request_id,payload,work_id);
 return result;
end; $$;
revoke all on function public.create_quick_work(uuid,uuid,jsonb,jsonb,integer,jsonb) from public,anon,authenticated;
grant execute on function public.create_quick_work(uuid,uuid,jsonb,jsonb,integer,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
