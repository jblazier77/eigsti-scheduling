-- Apply once after 0016. Planning information only; no existing data is removed.
begin;
alter table public.jobs add column priority integer check(priority between 1 and 9999);
alter table public.work_items add column estimated_days numeric(5,2) check(estimated_days>0 and estimated_days<=999);
create index jobs_priority_order on public.jobs(priority asc nulls last,created_at desc,id desc);

create function private.review_number(p_value jsonb,p_kind text) returns numeric language plpgsql immutable set search_path='' as $$
declare n numeric;
begin
 if p_value is null or p_value='null'::jsonb then return null; end if;
 if jsonb_typeof(p_value)<>'number' then raise exception using errcode='22023',message='Invalid planning number'; end if;
 n:=(p_value#>>'{}')::numeric;
 if n<=0 or (p_kind='priority' and (n>9999 or n<>trunc(n))) or (p_kind='days' and (n>999 or n<>round(n,2))) then raise exception using errcode='22023',message='Invalid planning number'; end if;
 return n;
end; $$;
revoke all on function private.review_number(jsonb,text) from public,anon,authenticated;

create function public.save_job_priority(p_job_id uuid,p_request_id uuid,p_priority jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare n integer; payload jsonb; prior private.command_requests%rowtype;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 n:=private.review_number(p_priority,'priority');payload:=jsonb_build_object('job',p_job_id,'priority',n);
 perform id from public.jobs where id=p_job_id and lifecycle='open' for update;
 if not found then raise exception using errcode='P0002',message='Open job required'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='save_job_priority' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 update public.jobs set priority=n,updated_at=clock_timestamp(),updated_by=auth.uid() where id=p_job_id;
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id) values(p_job_id,auth.uid(),'save_job_priority',array['priority'],p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'save_job_priority',p_request_id,payload,p_job_id);
 return jsonb_build_object('id',p_job_id);
end; $$;

create function public.create_planning_work(p_job_id uuid,p_request_id uuid,p_values jsonb,p_plan jsonb,p_helpers integer,p_materials jsonb,p_days jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare n numeric; payload jsonb; prior private.command_requests%rowtype; result jsonb;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null then raise exception using errcode='22023',message='Request identifier required'; end if;
 -- JSON array/object extraction yields jsonb null, not SQL NULL. Normalize at the wrapper boundary.
 p_plan:=nullif(p_plan,'null'::jsonb);
 p_materials:=nullif(p_materials,'null'::jsonb);
 n:=private.review_number(p_days,'days');
 payload:=jsonb_build_object('job',p_job_id,'values',p_values,'plan',p_plan,'helpers',p_helpers,'materials',p_materials,'days',n);
 perform id from public.jobs where id=p_job_id and lifecycle='open' for update;
 if not found then raise exception using errcode='P0002',message='Open job required'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='create_planning_work' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 if exists(select 1 from private.command_requests where actor_id=auth.uid() and request_id=p_request_id and operation in ('create_quick_work','create_job_work_with_plan','create_job_work')) then raise exception using errcode='23505',message='Request payload changed'; end if;
 result:=public.create_quick_work(p_job_id,p_request_id,p_values,p_plan,p_helpers,p_materials);
 update public.work_items set estimated_days=n where id=(result->>'id')::uuid;
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id) values(p_job_id,auth.uid(),'create_planning_work',array['estimated_days'],p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'create_planning_work',p_request_id,payload,(result->>'id')::uuid);
 return result;
end; $$;

create function public.save_work_details(p_work_id uuid,p_request_id uuid,p_values jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items%rowtype; j public.jobs%rowtype; prior private.command_requests%rowtype; payload jsonb; k text; patch jsonb; n numeric;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not(private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Work planner required'; end if;
 if p_request_id is null or p_values is null or jsonb_typeof(p_values)<>'object' or p_values='{}'::jsonb then raise exception using errcode='22023',message='Invalid work details'; end if;
 for k in select jsonb_object_keys(p_values) loop
  if k not in ('description','estimated_days','responsible_lead','default_helpers') then raise exception using errcode='22023',message='Invalid work field'; end if;
 end loop;
 select x.* into j from public.jobs x join public.work_items y on y.job_id=x.id where y.id=p_work_id for update of x;
 select * into w from public.work_items where id=p_work_id for update;
 if w.id is null or j.lifecycle<>'open' or w.completion<>'open' then raise exception using errcode='P0002',message='Open work required'; end if;
 if not private.has_role('pm') and (w.responsible_lead is distinct from auth.uid() or not private.can_read_job(j.id)) then raise exception using errcode='42501',message='Responsible lead required'; end if;
 if not private.has_role('pm') and p_values ? 'responsible_lead' then raise exception using errcode='42501',message='PM account required'; end if;
 payload:=jsonb_build_object('work',p_work_id,'values',p_values);
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='save_work_details' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',w.id,'job_id',j.id);
 end if;
 patch:=p_values-array['estimated_days','default_helpers'];
 if patch<>'{}'::jsonb then
  patch:=private.work_patch(patch);
  if private.has_role('pm') then perform public.update_job_work(j.id,w.id,patch);
  else update public.work_items set description=patch->>'description' where id=w.id; end if;
 end if;
 if p_values ? 'estimated_days' then n:=private.review_number(p_values->'estimated_days','days');update public.work_items set estimated_days=n where id=w.id; end if;
 if p_values ? 'default_helpers' then
  if jsonb_typeof(p_values->'default_helpers')<>'number' or (p_values->>'default_helpers')::numeric not between 0 and 20 or (p_values->>'default_helpers')::numeric<>trunc((p_values->>'default_helpers')::numeric) then raise exception using errcode='22023',message='Invalid helper count'; end if;
  update public.work_items set default_helpers=(p_values->>'default_helpers')::integer where id=w.id;
 end if;
 update public.work_items set updated_at=clock_timestamp(),updated_by=auth.uid() where id=w.id;
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id) values(j.id,auth.uid(),'save_work_details',array(select jsonb_object_keys(p_values)),p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'save_work_details',p_request_id,payload,w.id);
 return jsonb_build_object('id',w.id,'job_id',j.id);
end; $$;

create function public.pm_help_requests() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(r) order by r.priority asc nulls last,r.start_date asc nulls last,r.job_id,r.work_id,r.visit_id) from (
 select j.id job_id,j.title,w.id work_id,w.description,j.priority,v.id visit_id,v.start_date,v.end_date,v.required_helpers requested,
 a.assigned::integer assigned,(v.required_helpers-a.assigned)::integer missing
 from public.jobs j join public.work_items w on w.job_id=j.id join public.visits v on v.work_item_id=w.id
 cross join lateral (select count(distinct p.user_id) assigned from public.visit_participants p join public.app_users u on u.id=p.user_id
 where p.visit_id=v.id and p.duty='helping' and p.user_id<>v.coordinator_id and u.active and u.roles && array['lead','helper']::text[]) a
 where j.responsible_pm=auth.uid() and j.lifecycle='open' and w.completion='open' and v.state='planned' and v.end_date>=(now() at time zone 'America/Chicago')::date and v.required_helpers>a.assigned
 union all
 select j.id,j.title,w.id,w.description,j.priority,null::uuid,null::date,null::date,w.default_helpers,0,w.default_helpers
 from public.jobs j join public.work_items w on w.job_id=j.id where j.responsible_pm=auth.uid() and j.lifecycle='open' and w.completion='open' and w.default_helpers>0
 and not exists(select 1 from public.visits v where v.work_item_id=w.id and v.state='planned')
 ) r),'[]'::jsonb);
end; $$;

create function public.create_job_workspace(p_request_id uuid,p_customer text,p_phone text,p_address text,p_classification jsonb,p_details jsonb,p_priority jsonb,p_work jsonb,p_contacts jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare payload jsonb; prior private.command_requests%rowtype; result jsonb; v_job uuid; item jsonb; item_request uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not private.has_role('pm') then raise exception using errcode='42501',message='PM account required'; end if;
 if p_request_id is null or jsonb_typeof(p_work) is distinct from 'array' or jsonb_typeof(p_contacts) is distinct from 'array' or jsonb_array_length(p_work)>20 or jsonb_array_length(p_contacts)>20 then raise exception using errcode='22023',message='Invalid job setup'; end if;
 payload:=jsonb_build_object('customer',p_customer,'phone',p_phone,'address',p_address,'classification',p_classification,'details',p_details,'priority',p_priority,'work',p_work,'contacts',p_contacts);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':create_job_workspace:'||p_request_id::text,0));
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='create_job_workspace' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('id',prior.result_id);
 end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':create_classified_job:'||p_request_id::text,0));
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':create_job:'||p_request_id::text,0));
 if exists(select 1 from private.command_requests where actor_id=auth.uid() and request_id=p_request_id and operation in ('create_job','create_classified_job')) then raise exception using errcode='23505',message='Request payload changed'; end if;
 result:=public.create_classified_job(p_request_id,p_customer,p_phone,p_address,p_classification);v_job:=(result->>'id')::uuid;
 if p_details is null or jsonb_typeof(p_details)<>'object' or exists(select 1 from jsonb_object_keys(p_details) k where k not in ('title','scope','access_notes')) then raise exception using errcode='22023',message='Invalid job setup'; end if;
 if p_details<>'{}'::jsonb then perform public.update_job(v_job,p_details); end if;
 perform public.save_job_priority(v_job,p_request_id,p_priority);
 -- create_job supplies one Whole job item; remove only this newly-created placeholder
 -- when explicit task drafts were supplied, before any dates or ownership exist.
 if jsonb_array_length(p_work)>0 then delete from public.work_items where job_id=v_job; end if;
 for item in select value from jsonb_array_elements(p_work) loop
  item_request:=gen_random_uuid();
  perform public.create_planning_work(v_job,item_request,item->'values',item->'plan',(item->>'helpers')::integer,item->'materials',item->'days');
 end loop;
 for item in select value from jsonb_array_elements(p_contacts) loop perform public.create_job_contact(v_job,gen_random_uuid(),item); end loop;
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'create_job_workspace',p_request_id,payload,v_job);
 return result;
end; $$;
revoke all on function public.save_job_priority(uuid,uuid,jsonb),public.create_planning_work(uuid,uuid,jsonb,jsonb,integer,jsonb,jsonb),public.save_work_details(uuid,uuid,jsonb),public.pm_help_requests(),public.create_job_workspace(uuid,text,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.save_job_priority(uuid,uuid,jsonb),public.create_planning_work(uuid,uuid,jsonb,jsonb,integer,jsonb,jsonb),public.save_work_details(uuid,uuid,jsonb),public.pm_help_requests(),public.create_job_workspace(uuid,text,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
