-- Apply once after 0011 in the isolated test project. No user/job fixtures.
begin;
create function public.create_job_work_with_plan(p_job_id uuid,p_request_id uuid,p_values jsonb,p_plan jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare vals jsonb; payload jsonb; prior private.command_requests%rowtype; result jsonb; planned jsonb; k text;
begin
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_job_id is null or p_request_id is null then raise exception using errcode='22023',message='Invalid work details'; end if;
 vals:=private.work_patch(p_values);
 if not(vals ?& array['description','responsible_lead']) then raise exception using errcode='22023',message='Incomplete work details'; end if;
 if p_plan is not null then
  if jsonb_typeof(p_plan)<>'object' or not(p_plan ?& array['start_date','end_date','slot','coordinator_id']) then raise exception using errcode='22023',message='Invalid visit'; end if;
  for k in select jsonb_object_keys(p_plan) loop
   if k not in ('start_date','end_date','slot','start_time','end_time','coordinator_id','required_helpers','certainty') then raise exception using errcode='22023',message='Invalid visit field'; end if;
  end loop;
  if vals->>'responsible_lead' is null or p_plan->>'coordinator_id' is distinct from vals->>'responsible_lead' then raise exception using errcode='22023',message='Active lead required'; end if;
 end if;
 payload:=jsonb_build_object('job',p_job_id,'values',vals,'plan',p_plan);
 -- Same schedule -> actor -> job ordering used by existing visit/card commands.
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 perform id from public.jobs where id=p_job_id and lifecycle='open' for update;
 if not found then raise exception using errcode='P0002',message='Open job required'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='create_job_work_with_plan' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 result:=public.create_job_work(p_job_id,p_request_id,vals);
 if p_plan is not null then planned:=public.save_visit((result->>'id')::uuid,null,p_request_id,p_plan); end if;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id)
 values(auth.uid(),'create_job_work_with_plan',p_request_id,payload,(result->>'id')::uuid);
 return result;
end; $$;

alter table public.work_items
 add column material_name text not null default '' check(length(material_name)<=300 and material_name !~ '[[:cntrl:]]'),
 add column material_status text not null default 'not_set' check(material_status in ('not_set','not_needed','need_to_order','ordered','in_stock')),
 add column material_expected_on date check(material_expected_on is null or material_expected_on between date '2000-01-01' and date '2099-12-31');
create table private.work_material_events (
 id uuid primary key default gen_random_uuid(),work_id uuid not null references public.work_items(id),
 actor_id uuid not null references public.app_users(id),request_id uuid not null,
 before_state jsonb not null,after_state jsonb not null,created_at timestamptz not null default now()
);
alter table private.work_material_events enable row level security;
revoke all on private.work_material_events from public,anon,authenticated;

create function public.save_work_materials(p_work_id uuid,p_request_id uuid,p_values jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items%rowtype; j public.jobs%rowtype; prior private.command_requests%rowtype;
 name_value text; status_value text; expected date; payload jsonb; before_data jsonb; k text;
begin
 if not(private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Work planner required'; end if;
 if p_work_id is null or p_request_id is null or p_values is null or jsonb_typeof(p_values)<>'object' or not(p_values ?& array['material_name','material_status','material_expected_on']) then raise exception using errcode='22023',message='Invalid material details'; end if;
 for k in select jsonb_object_keys(p_values) loop
  if k not in ('material_name','material_status','material_expected_on') then raise exception using errcode='22023',message='Invalid material details'; end if;
 end loop;
 if jsonb_typeof(p_values->'material_name')<>'string' or jsonb_typeof(p_values->'material_status')<>'string' then raise exception using errcode='22023',message='Invalid material details'; end if;
 name_value:=btrim(p_values->>'material_name');status_value:=p_values->>'material_status';
 if length(name_value)>300 or name_value ~ '[[:cntrl:]]' or status_value not in ('not_set','not_needed','need_to_order','ordered','in_stock') or (status_value in ('need_to_order','ordered','in_stock') and name_value='') then raise exception using errcode='22023',message='Invalid material details'; end if;
 if p_values->'material_expected_on'<>'null'::jsonb then
  if jsonb_typeof(p_values->'material_expected_on')<>'string' or (p_values->>'material_expected_on')!~'^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' then raise exception using errcode='22023',message='Invalid material date'; end if;
  expected:=(p_values->>'material_expected_on')::date;
 end if;
 if status_value in ('not_set','not_needed','in_stock') and expected is not null then raise exception using errcode='22023',message='Invalid material date'; end if;
 payload:=jsonb_build_object('work',p_work_id,'values',jsonb_build_object('material_name',name_value,'material_status',status_value,'material_expected_on',expected));
 perform id from public.app_users where id=auth.uid() for share;
 if not(private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Work planner required'; end if;
 select x.* into j from public.jobs x join public.work_items y on y.job_id=x.id where y.id=p_work_id for update of x;
 select * into w from public.work_items where id=p_work_id for update;
 if w.id is null then raise exception using errcode='P0002',message='Work unavailable'; end if;
 if not private.has_role('pm') and w.responsible_lead is distinct from auth.uid() then raise exception using errcode='42501',message='Responsible lead required'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='save_work_materials' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',w.id,'job_id',j.id);
 end if;
 if j.lifecycle<>'open' or w.completion<>'open' then raise exception using errcode='22023',message='Open work required'; end if;
 before_data:=to_jsonb(w);
 update public.work_items set material_name=name_value,material_status=status_value,material_expected_on=expected,
 readiness=case when status_value in ('in_stock','not_needed') then 'ready' when expected is not null then 'waiting_date' else 'waiting_unknown' end,
 waiting_until=expected,updated_at=clock_timestamp(),updated_by=auth.uid() where id=w.id;
 insert into private.work_material_events(work_id,actor_id,request_id,before_state,after_state)
 select w.id,auth.uid(),p_request_id,before_data,to_jsonb(updated) from public.work_items updated where id=w.id;
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
 values(j.id,auth.uid(),'save_work_materials',array['materials','readiness'],p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'save_work_materials',p_request_id,payload,w.id);
 return jsonb_build_object('id',w.id,'job_id',j.id);
end; $$;
revoke all on function public.create_job_work_with_plan(uuid,uuid,jsonb,jsonb),public.save_work_materials(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.create_job_work_with_plan(uuid,uuid,jsonb,jsonb),public.save_work_materials(uuid,uuid,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

