begin;
do $preflight$ begin if position('create_staffed_work' in pg_get_functiondef('public.create_job_workspace(uuid,text,text,text,jsonb,jsonb,jsonb,jsonb,jsonb)'::regprocedure))=0 then raise exception 'Requires 0021'; end if; if exists(select 1 from information_schema.columns where table_schema='public' and table_name='visits' and column_name='coordinator_id' and is_nullable='YES') then raise exception '0022 already present; do not rerun'; end if; end; $preflight$;
-- Apply once after 0021. PM may schedule work before choosing a lead.
alter table public.visits alter column coordinator_id drop not null;
create or replace function public.save_visit(p_work_id uuid,p_visit_id uuid,p_request_id uuid,p_patch jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.visits%rowtype; w public.work_items%rowtype; v_job public.jobs%rowtype;
 v_prior private.command_requests%rowtype; v_payload jsonb; k text; v_actor uuid:=auth.uid(); v_new boolean:=p_visit_id is null;
begin
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Visit planning required'; end if;
 if p_work_id is null or p_request_id is null or p_patch is null or jsonb_typeof(p_patch)<>'object' or p_patch='{}'::jsonb then raise exception using errcode='22023',message='Invalid visit'; end if;
 for k in select jsonb_object_keys(p_patch) loop
  if k not in ('start_date','end_date','slot','start_time','end_time','required_helpers','certainty','coordinator_id','state') then raise exception using errcode='22023',message='Invalid visit field'; end if;
  if k='required_helpers' then
   if jsonb_typeof(p_patch->k)<>'number' or (p_patch->>k)!~'^[0-9]{1,2}$' then raise exception using errcode='22023',message='Invalid helper count'; end if;
  elsif k in ('start_time','end_time','coordinator_id') and p_patch->k='null'::jsonb then null;
  elsif jsonb_typeof(p_patch->k)<>'string' then raise exception using errcode='22023',message='Invalid visit value'; end if;
 end loop;
 -- Schedule commands serialize before parent locks; no command here acquires a queue lock.
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Visit planning required'; end if;
 select j.* into v_job from public.jobs j join public.work_items x on x.job_id=j.id where x.id=p_work_id for update of j;
 select * into w from public.work_items where id=p_work_id for update;
 if w.id is null then raise exception using errcode='P0002',message='Work unavailable'; end if;
 if not v_new then select * into v from public.visits where id=p_visit_id and work_item_id=p_work_id for update; end if;
 if not v_new and v.id is null then raise exception using errcode='P0002',message='Visit unavailable'; end if;
 if not private.has_role('pm') and not coalesce(((v_new and w.responsible_lead=v_actor) or (not v_new and v.coordinator_id=v_actor)),false) then raise exception using errcode='42501',message='Visit coordinator required'; end if;
 v_payload:=jsonb_build_object('work',p_work_id,'visit',p_visit_id,'patch',p_patch);
 select * into v_prior from private.command_requests where actor_id=v_actor and operation='save_visit' and request_id=p_request_id;
 if found then
  if v_prior.payload<>v_payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return private.visit_result(v_prior.result_id);
 end if;
 if v_job.lifecycle<>'open' or w.completion<>'open' or v.state='completed' then raise exception using errcode='22023',message='Open work required'; end if;
 if v_new then
  if not p_patch ?& array['start_date','end_date','slot','coordinator_id'] then raise exception using errcode='22023',message='Visit dates and coordinator required'; end if;
  v.id:=gen_random_uuid(); v.work_item_id:=p_work_id; v.required_helpers:=0; v.certainty:='tentative'; v.state:='planned';
 end if;
 if p_patch ? 'coordinator_id' then
  if not private.has_role('pm') and (p_patch->>'coordinator_id')::uuid is distinct from v_actor then raise exception using errcode='42501',message='PM required to change coordinator'; end if;
  v.coordinator_id:=(p_patch->>'coordinator_id')::uuid;
 end if;
 if v.coordinator_id is not null then
  perform 1 from public.app_users where id=v.coordinator_id and active and 'lead'=any(roles) for share;
  if not found then raise exception using errcode='22023',message='Active staff required'; end if;
 elsif not private.has_role('pm') then raise exception using errcode='42501',message='PM required to leave lead unassigned'; end if;
 if p_patch ? 'start_date' then v.start_date:=(p_patch->>'start_date')::date; end if;
 if p_patch ? 'end_date' then v.end_date:=(p_patch->>'end_date')::date; end if;
 if p_patch ? 'slot' then v.slot:=p_patch->>'slot'; end if;
 if p_patch ? 'start_time' then v.start_time:=(p_patch->>'start_time')::time; end if;
 if p_patch ? 'end_time' then v.end_time:=(p_patch->>'end_time')::time; end if;
 if v.slot<>'timed' then v.start_time:=null; v.end_time:=null; end if;
 if p_patch ? 'required_helpers' then v.required_helpers:=(p_patch->>'required_helpers')::integer; end if;
 if p_patch ? 'certainty' then v.certainty:=p_patch->>'certainty'; end if;
 if p_patch ? 'state' then
  if p_patch->>'state' not in ('planned','cancelled') then raise exception using errcode='22023',message='Invalid visit state'; end if;
  v.state:=p_patch->>'state';
 end if;
 if v.required_helpers < (select count(*) from public.visit_participants where visit_id=v.id and duty='helping') then raise exception using errcode='22023',message='Named help exceeds need'; end if;
 if exists(select 1 from public.visit_participants where visit_id=v.id and user_id=v.coordinator_id and duty='helping') then raise exception using errcode='22023',message='Coordinator already helping'; end if;
 if v_new then
  insert into public.visits(id,work_item_id,coordinator_id,start_date,end_date,slot,start_time,end_time,required_helpers,certainty,state,created_by,updated_by)
   values(v.id,w.id,v.coordinator_id,v.start_date,v.end_date,v.slot,v.start_time,v.end_time,v.required_helpers,v.certainty,v.state,v_actor,v_actor);
 else
  update public.visits set coordinator_id=v.coordinator_id,start_date=v.start_date,end_date=v.end_date,slot=v.slot,start_time=v.start_time,end_time=v.end_time,
   required_helpers=v.required_helpers,certainty=v.certainty,state=v.state,updated_by=v_actor,updated_at=clock_timestamp() where id=v.id;
 end if;
 delete from public.visit_participants where visit_id=v.id and duty='leading';
 if v.coordinator_id is not null then insert into public.visit_participants values(v.id,v.coordinator_id,'leading'); end if;
 perform private.rebuild_visit(v.id);
 insert into private.visit_events(visit_id,actor_id,request_id,operation,snapshot) values(v.id,v_actor,p_request_id,'save_visit',private.visit_result(v.id));
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
 values(w.job_id,v_actor,case when v_new then 'create_visit' else 'update_visit' end,array(select jsonb_object_keys(p_patch) order by 1),p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(v_actor,'save_visit',p_request_id,v_payload,v.id);
 return private.visit_result(v.id);
end; $$;
create or replace function public.staff_visit(p_visit_id uuid,p_request_id uuid,p_helpers uuid[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v public.visits%rowtype; w public.work_items%rowtype; j public.jobs%rowtype; v_ids uuid[]; v_prior private.command_requests%rowtype; v_payload jsonb;
begin
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Visit planning required'; end if;
 if p_request_id is null or p_helpers is null or cardinality(p_helpers)>20 or (cardinality(p_helpers)>0 and array_ndims(p_helpers)<>1) or array_position(p_helpers,null) is not null
 then raise exception using errcode='22023',message='Invalid staffing'; end if;
 select coalesce(array_agg(x order by x),'{}'::uuid[]) into v_ids from (select distinct unnest(p_helpers) x) s;
 if cardinality(v_ids)<>cardinality(p_helpers) then raise exception using errcode='22023',message='Invalid staffing'; end if;
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Visit planning required'; end if;
 select x.* into j from public.jobs x join public.work_items y on y.job_id=x.id join public.visits z on z.work_item_id=y.id where z.id=p_visit_id for update of x;
 select x.* into w from public.work_items x join public.visits y on y.work_item_id=x.id where y.id=p_visit_id for update of x;
 select * into v from public.visits where id=p_visit_id for update;
 if v.id is null then raise exception using errcode='P0002',message='Visit unavailable'; end if;
 if not private.has_role('pm') and v.coordinator_id is distinct from auth.uid() then raise exception using errcode='42501',message='Visit coordinator required'; end if;
 v_payload:=jsonb_build_object('visit',p_visit_id,'helpers',v_ids);
 select * into v_prior from private.command_requests where actor_id=auth.uid() and operation='staff_visit' and request_id=p_request_id;
 if found then
  if v_prior.payload<>v_payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return private.visit_result(v.id);
 end if;
 if j.lifecycle<>'open' or w.completion<>'open' or v.state<>'planned' then raise exception using errcode='22023',message='Open work required'; end if;
 if cardinality(v_ids)>v.required_helpers or v.coordinator_id=any(v_ids) then raise exception using errcode='22023',message='Invalid staffing'; end if;
 if not private.has_role('pm') and exists(select 1 from public.visit_participants where visit_id=v.id and duty='helping' and not user_id=any(v_ids))
 then raise exception using errcode='42501',message='PM required to replace named help'; end if;
 perform id from public.app_users where id=any(v_ids) order by id for share;
 if (select count(*) from public.app_users where id=any(v_ids) and active and roles && array['lead','helper']::text[])<>cardinality(v_ids)
 then raise exception using errcode='22023',message='Active staff required'; end if;
 delete from public.visit_participants where visit_id=v.id and duty='helping';
 insert into public.visit_participants select v.id,unnest(v_ids),'helping';
 perform private.rebuild_visit(v.id);
 update public.visits set updated_at=clock_timestamp(),updated_by=auth.uid() where id=v.id;
 insert into private.visit_events(visit_id,actor_id,request_id,operation,snapshot) values(v.id,auth.uid(),p_request_id,'staff_visit',private.visit_result(v.id));
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id) values(w.job_id,auth.uid(),'staff_visit',array['participants'],p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id) values(auth.uid(),'staff_visit',p_request_id,v_payload,v.id);
 return private.visit_result(v.id);
end; $$;
create or replace function public.visit_staff_options(p_visit_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v public.visits%rowtype;
begin
 select * into v from public.visits where id=p_visit_id;
 if (private.has_role('pm') or (private.has_role('lead') and v.coordinator_id=auth.uid())) is not true then raise exception using errcode='42501',message='Visit coordinator required'; end if;
 if v.id is null then raise exception using errcode='P0002',message='Visit unavailable'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',u.id,'name',u.display_name,'busy',exists(
 select 1 from private.visit_bookings a join private.visit_bookings b on b.user_id=u.id and b.visit_id<>v.id and a.starts_at<b.ends_at and b.starts_at<a.ends_at
 where a.visit_id=v.id)) order by u.display_name,u.id) from public.app_users u where u.active and u.roles && array['lead','helper']::text[] and u.id is distinct from v.coordinator_id),'[]'::jsonb);
end; $$;
create or replace function public.save_visit_card(p_work_id uuid,p_visit_id uuid,p_request_id uuid,p_patch jsonb,p_helpers uuid[] default null)
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
 if not private.has_role('pm') and v.coordinator_id is distinct from auth.uid() then raise exception using errcode='42501',message='Visit coordinator required'; end if;
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
create or replace function public.work_progress_command(p_work_id uuid,p_visit_id uuid,p_follow_up_id uuid,p_request_id uuid,p_command text,p_values jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.work_items%rowtype; j public.jobs%rowtype; v public.visits%rowtype; f public.work_follow_ups%rowtype;
 v_prior private.command_requests%rowtype; payload jsonb; before_data jsonb; result_id uuid; new_visit jsonb;
 note_value text:=''; due_value date; needs_return boolean:=false; reopen_value boolean:=false; k text; owner_value uuid;
begin
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Progress planning required'; end if;
 if p_work_id is null or p_request_id is null or p_command is null or p_command not in ('finish_visit','complete_work','record_return','resolve_return','reopen_work','plan_return')
 or p_values is null or jsonb_typeof(p_values)<>'object' then raise exception using errcode='22023',message='Invalid progress command'; end if;
 if (p_command='finish_visit' and (p_visit_id is null or p_follow_up_id is not null))
 or (p_command in ('resolve_return','plan_return') and (p_follow_up_id is null or p_visit_id is not null))
 or (p_command in ('complete_work','reopen_work') and (p_visit_id is not null or p_follow_up_id is not null))
 or (p_command='record_return' and p_follow_up_id is not null) then raise exception using errcode='22023',message='Invalid progress relationship'; end if;
 for k in select jsonb_object_keys(p_values) loop
  if (p_command='finish_visit' and k not in ('note','needs_return','due_date'))
  or (p_command='record_return' and k not in ('note','due_date','reopen'))
  or (p_command in ('complete_work','reopen_work','resolve_return'))
  or (p_command='plan_return' and k not in ('start_date','end_date','slot','start_time','end_time','coordinator_id','required_helpers','certainty'))
  then raise exception using errcode='22023',message='Invalid progress field'; end if;
 end loop;
 if p_values ? 'note' then
  if jsonb_typeof(p_values->'note')<>'string' then raise exception using errcode='22023',message='Invalid remaining note'; end if;
  note_value:=btrim(p_values->>'note');
  if length(note_value)>2000 or translate(note_value,chr(10)||chr(13)||chr(9),'') ~ '[[:cntrl:]]' then raise exception using errcode='22023',message='Invalid remaining note'; end if;
 end if;
 if p_values ? 'needs_return' then
  if jsonb_typeof(p_values->'needs_return')<>'boolean' then raise exception using errcode='22023',message='Invalid return flag'; end if;
  needs_return:=(p_values->>'needs_return')::boolean;
 end if;
 if p_values ? 'reopen' then
  if jsonb_typeof(p_values->'reopen')<>'boolean' then raise exception using errcode='22023',message='Invalid return flag'; end if;
  reopen_value:=(p_values->>'reopen')::boolean;
 end if;
 if p_values ? 'due_date' and p_values->'due_date'<>'null'::jsonb then
  if jsonb_typeof(p_values->'due_date')<>'string' or (p_values->>'due_date')!~'^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' then raise exception using errcode='22023',message='Invalid return date'; end if;
  due_value:=(p_values->>'due_date')::date;
 end if;
 if (p_command='record_return' or needs_return) and note_value='' then raise exception using errcode='22023',message='Describe return work'; end if;
 if p_command='finish_visit' then p_values:=jsonb_build_object('note',note_value,'due_date',due_value,'needs_return',needs_return); end if;
 if p_command='record_return' then p_values:=jsonb_build_object('note',note_value,'due_date',due_value,'reopen',reopen_value); end if;
 payload:=jsonb_build_object('work',p_work_id,'visit',p_visit_id,'follow_up',p_follow_up_id,'values',p_values);
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id=auth.uid() for share;
 if not (private.has_role('pm') or private.has_role('lead')) then raise exception using errcode='42501',message='Progress planning required'; end if;
 select x.* into j from public.jobs x join public.work_items y on y.job_id=x.id where y.id=p_work_id for update of x;
 select * into w from public.work_items where id=p_work_id for update;
 if w.id is null then raise exception using errcode='P0002',message='Work unavailable'; end if;
 if p_visit_id is not null then
  select * into v from public.visits where id=p_visit_id and work_item_id=w.id for update;
  if v.id is null then raise exception using errcode='P0002',message='Visit unavailable'; end if;
 end if;
 if p_follow_up_id is not null then
  select * into f from public.work_follow_ups where id=p_follow_up_id and work_item_id=w.id and job_id=j.id for update;
  if f.id is null then raise exception using errcode='P0002',message='Return unavailable'; end if;
 end if;
 if not private.has_role('pm') then
  if p_command='finish_visit' or (p_command='record_return' and p_visit_id is not null) then
   if v.coordinator_id is distinct from auth.uid() then raise exception using errcode='42501',message='Visit coordinator required'; end if;
  elsif w.responsible_lead is distinct from auth.uid() then raise exception using errcode='42501',message='Responsible lead required'; end if;
 end if;
 select * into v_prior from private.command_requests where actor_id=auth.uid() and operation='progress:'||p_command and request_id=p_request_id;
 if found then
  if v_prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return jsonb_build_object('job_id',j.id,'work_id',w.id,'result_id',v_prior.result_id,
    'visit',case when p_command in ('finish_visit','plan_return') then private.visit_result(v_prior.result_id) else null end);
 end if;
 if j.lifecycle<>'open' then raise exception using errcode='22023',message='Open job required'; end if;
 before_data:=private.work_progress_snapshot(w.id); result_id:=w.id;
 if p_command='finish_visit' then
  if v.state<>'planned' then raise exception using errcode='22023',message='Planned visit required'; end if;
  if w.completion<>'open' then raise exception using errcode='22023',message='Open work required'; end if;
  update public.visits set state='completed',updated_at=clock_timestamp(),updated_by=auth.uid() where id=v.id;
  perform private.rebuild_visit(v.id);
  if note_value<>'' then update public.work_items set remaining_note=note_value,updated_at=clock_timestamp(),updated_by=auth.uid() where id=w.id; end if;
  if needs_return then
   if (select count(*) from public.work_follow_ups where job_id=j.id and state='open')>=100 then raise exception using errcode='22023',message='Return limit reached'; end if;
   select id into owner_value from public.app_users where id=w.responsible_lead and active;
   insert into public.work_follow_ups(job_id,work_item_id,source_visit_id,owner_id,note,due_date,created_by,updated_by)
   values(j.id,w.id,v.id,coalesce(owner_value,auth.uid()),note_value,due_value,auth.uid(),auth.uid());
  end if;
  insert into private.visit_events(visit_id,actor_id,request_id,operation,snapshot) values(v.id,auth.uid(),p_request_id,'finish_visit',private.visit_result(v.id));
  result_id:=v.id;
 elsif p_command='complete_work' then
  if w.completion<>'open' then raise exception using errcode='22023',message='Open work required'; end if;
  if exists(select 1 from public.visits where work_item_id=w.id and state='planned') then raise exception using errcode='22023',message='Planned visits remain'; end if;
  if exists(select 1 from public.work_follow_ups where work_item_id=w.id and state='open') then raise exception using errcode='22023',message='Open returns remain'; end if;
  update public.work_items set completion='completed',remaining_note='',updated_at=clock_timestamp(),updated_by=auth.uid() where id=w.id;
 elsif p_command='reopen_work' then
  if w.completion<>'completed' then raise exception using errcode='22023',message='Completed work required'; end if;
  update public.work_items set completion='open',updated_at=clock_timestamp(),updated_by=auth.uid() where id=w.id;
 elsif p_command='record_return' then
  if w.completion='completed' and not reopen_value then raise exception using errcode='22023',message='Reopen portion explicitly'; end if;
  if (select count(*) from public.work_follow_ups where job_id=j.id and state='open')>=100 then raise exception using errcode='22023',message='Return limit reached'; end if;
  update public.work_items set completion='open',remaining_note=note_value,updated_at=clock_timestamp(),updated_by=auth.uid() where id=w.id;
  select id into owner_value from public.app_users where id=w.responsible_lead and active;
  insert into public.work_follow_ups(job_id,work_item_id,source_visit_id,owner_id,note,due_date,created_by,updated_by)
  values(j.id,w.id,p_visit_id,coalesce(owner_value,auth.uid()),note_value,due_value,auth.uid(),auth.uid()) returning id into result_id;
 elsif p_command='resolve_return' then
  if f.state<>'open' then raise exception using errcode='22023',message='Open return required'; end if;
  if exists(select 1 from public.visits where follow_up_id=f.id and state='planned') then raise exception using errcode='22023',message='Return visit still planned'; end if;
  update public.work_follow_ups set state='done',updated_at=clock_timestamp(),updated_by=auth.uid() where id=f.id;
  result_id:=f.id;
 elsif p_command='plan_return' then
  if f.state<>'open' or w.completion<>'open' then raise exception using errcode='22023',message='Open return required'; end if;
  if exists(select 1 from public.visits where follow_up_id=f.id and state='planned') then raise exception using errcode='22023',message='Return already scheduled'; end if;
  new_visit:=public.save_visit(w.id,null,gen_random_uuid(),p_values);
  result_id:=(new_visit->>'id')::uuid;
  update public.visits set follow_up_id=f.id where id=result_id;
  insert into private.visit_events(visit_id,actor_id,request_id,operation,snapshot) values(result_id,auth.uid(),p_request_id,'plan_return',private.visit_result(result_id));
 end if;
 insert into private.work_progress_events(work_item_id,actor_id,request_id,operation,before_state,after_state)
 values(w.id,auth.uid(),p_request_id,p_command,before_data,private.work_progress_snapshot(w.id));
 insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
 values(j.id,auth.uid(),p_command,array['work_progress'],p_request_id);
 insert into private.command_requests(actor_id,operation,request_id,payload,result_id)
 values(auth.uid(),'progress:'||p_command,p_request_id,payload,result_id);
 return jsonb_build_object('job_id',j.id,'work_id',w.id,'result_id',result_id,
  'visit',case when p_command in ('finish_visit','plan_return') then private.visit_result(result_id) else null end);
end; $$;
create or replace function public.create_job_work_with_plan(p_job_id uuid,p_request_id uuid,p_values jsonb,p_plan jsonb)
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
  if p_plan->>'coordinator_id' is distinct from vals->>'responsible_lead' then raise exception using errcode='22023',message='Active lead required'; end if;
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
create or replace function public.save_work_setup(p_work_id uuid,p_request_id uuid,p_patch jsonb,p_materials jsonb,p_plan jsonb,p_visits jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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
  if exists(select 1 from public.visits where work_item_id=w.id and state='planned' and start_date=(p_plan->>'start_date')::date and end_date=(p_plan->>'end_date')::date and coordinator_id is not distinct from (p_plan->>'coordinator_id')::uuid and slot=p_plan->>'slot' and start_time is not distinct from (p_plan->>'start_time')::time and end_time is not distinct from (p_plan->>'end_time')::time) then raise exception using errcode='22023',message='Edit existing work dates'; end if;
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
notify pgrst,'reload schema';

savepoint unassigned_checks;
-- Isolated test project only. Synthetic fixtures and every change roll back.
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_unassigned_results(ordinal integer generated always as identity,result text not null) on commit drop;
create temporary table eigsti_unassigned_ids(label text primary key,id uuid not null) on commit drop;
grant insert,select on pg_temp.eigsti_unassigned_results,pg_temp.eigsti_unassigned_ids to authenticated,anon;
grant usage on sequence pg_temp.eigsti_unassigned_results_ordinal_seq to authenticated,anon;
insert into auth.users(id,email) values
('11111111-1111-4111-8111-111111111111','quick-pm@example.invalid'),
('22222222-2222-4222-8222-222222222222','review-pm2@example.invalid'),
('33333333-3333-4333-8333-333333333333','quick-lead@example.invalid'),
('44444444-4444-4444-8444-444444444444','quick-other@example.invalid'),
('55555555-5555-4555-8555-555555555555','quick-helper@example.invalid'),
('77777777-7777-4777-8777-777777777777','quick-admin@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
('11111111-1111-4111-8111-111111111111','SYNTHETIC PM',array['pm'],true),
('22222222-2222-4222-8222-222222222222','SYNTHETIC PM2',array['pm'],true),
('33333333-3333-4333-8333-333333333333','SYNTHETIC Lead',array['lead'],true),
('44444444-4444-4444-8444-444444444444','SYNTHETIC Other lead',array['lead'],true),
('55555555-5555-4555-8555-555555555555','SYNTHETIC Helper',array['helper'],true),
('77777777-7777-4777-8777-777777777777','SYNTHETIC Admin',array['admin'],true);
create function pg_temp.unassigned_job(r uuid) returns jsonb language sql as $helper$
 select public.create_job_workspace(r,'SYNTHETIC Unassigned crew','3095550101','Fictional Unassigned Lane','{}','{}','null',jsonb_build_array(jsonb_build_object('values',jsonb_build_object('description','SYNTHETIC Install window','responsible_lead',null),'helpers',2,'plan',jsonb_build_object('start_date','2099-01-05','end_date','2099-01-05','slot','day','coordinator_id',null,'required_helpers',2,'certainty','tentative'),'materials',null,'days',0.5,'named_helpers',jsonb_build_array('55555555-5555-4555-8555-555555555555','44444444-4444-4444-8444-444444444444'))),'[]');
$helper$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_unassigned_results(result) values(lives_ok($q$select pg_temp.unassigned_job('abcdefab-cdef-4abc-8abc-000000000001')$q$,'Create full new job with date helpers and no lead'));
insert into pg_temp.eigsti_unassigned_ids values('job',(pg_temp.unassigned_job('abcdefab-cdef-4abc-8abc-000000000001')->>'id')::uuid);
reset role;
insert into pg_temp.eigsti_unassigned_ids select 'work',id from public.work_items where job_id=(select id from pg_temp.eigsti_unassigned_ids where label='job');
insert into pg_temp.eigsti_unassigned_ids select 'visit',id from public.visits where work_item_id=(select id from pg_temp.eigsti_unassigned_ids where label='work');
insert into pg_temp.eigsti_unassigned_results(result) values(ok((select coordinator_id is null and start_date='2099-01-05' and required_helpers=2 from public.visits where id=(select id from pg_temp.eigsti_unassigned_ids where label='visit')),'Date and spaces preserved with no lead'));
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from public.visit_participants where visit_id=(select id from pg_temp.eigsti_unassigned_ids where label='visit') and duty='helping'),2::bigint,'Both helpers remain assigned'));
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from public.visit_participants where visit_id=(select id from pg_temp.eigsti_unassigned_ids where label='visit') and duty='leading'),0::bigint,'No fake lead participant'));
insert into pg_temp.eigsti_unassigned_results(result) values(ok((select responsible_lead is null and estimated_days=0.5 from public.work_items where id=(select id from pg_temp.eigsti_unassigned_ids where label='work')),'Task ownership stays unassigned'));
set local role authenticated;
insert into pg_temp.eigsti_unassigned_results(result) values(lives_ok($q$select pg_temp.unassigned_job('abcdefab-cdef-4abc-8abc-000000000001')$q$,'Same creation retry safe'));
insert into pg_temp.eigsti_unassigned_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.list_schedule('2099-01-05','2099-01-05',false)) x where x->>'id'=(select id from pg_temp.eigsti_unassigned_ids where label='visit')::text and x->'coordinator_id'='null'::jsonb),'PM sees unassigned scheduled work'));
insert into pg_temp.eigsti_unassigned_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.visit_staff_options((select id from pg_temp.eigsti_unassigned_ids where label='visit'))) x where x->>'id'='33333333-3333-4333-8333-333333333333'),'PM can select lead as helper when coordinator is empty'));
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_unassigned_results(result) values(ok(exists(select 1 from jsonb_array_elements(public.list_schedule('2099-01-05','2099-01-05',false)) x where x->>'id'=(select id from pg_temp.eigsti_unassigned_ids where label='visit')::text),'Assigned helper sees scheduled work'));
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.staff_visit((select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000002',array[]::uuid[])$q$,'42501','Visit planning required','Helper cannot change staffing'));
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.work_progress_command((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),null,'abcdefab-cdef-4abc-8abc-000000000021','finish_visit','{}')$q$,'42501','Visit coordinator required','Legacy command cannot bypass unassigned lead permissions'));
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.save_visit((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000003','{"required_helpers":3}')$q$,'42501','Visit coordinator required','Helping lead cannot edit unassigned dates'));
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.staff_visit((select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000004',array[]::uuid[])$q$,'42501','Visit coordinator required','Null coordinator never grants staffing authority'));
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.save_visit_card((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000005','{}',array[]::uuid[])$q$,'42501','Visit coordinator required','Null coordinator never grants card authority'));
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.visit_staff_options((select id from pg_temp.eigsti_unassigned_ids where label='visit'))$q$,'42501','Visit coordinator required','Null coordinator never grants directory authority'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_unassigned_results(result) values(lives_ok($q$select public.save_visit((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000006','{"slot":"morning"}')$q$,'Unassigned timed crew reservation supported'));
reset role;
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select id from pg_temp.eigsti_unassigned_ids where label='visit')),2::bigint,'Only real named helpers are reserved'));
set local role authenticated;
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.create_staffed_work((select id from pg_temp.eigsti_unassigned_ids where label='job'),'abcdefab-cdef-4abc-8abc-000000000020','{"description":"SYNTHETIC Conflict","responsible_lead":null}','{"start_date":"2099-01-05","end_date":"2099-01-05","slot":"morning","coordinator_id":null,"required_helpers":1,"certainty":"tentative"}',1,null,null,'["55555555-5555-4555-8555-555555555555"]')$q$,'23P01','Staff scheduling conflict','Unassigned lead does not bypass helper time conflicts'));
reset role;
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from public.work_items where job_id=(select id from pg_temp.eigsti_unassigned_ids where label='job')),1::bigint,'Conflict rolls back new work'));
set local role authenticated;
insert into pg_temp.eigsti_unassigned_results(result) values(lives_ok($q$select public.save_work_setup_with_help((select id from pg_temp.eigsti_unassigned_ids where label='work'),'abcdefab-cdef-4abc-8abc-000000000007','{"responsible_lead":"33333333-3333-4333-8333-333333333333"}',null,null,jsonb_build_array(jsonb_build_object('id',(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'cancel',false,'patch',jsonb_build_object('coordinator_id','33333333-3333-4333-8333-333333333333'),'helpers',null)),null)$q$,'Assign lead later with same work and date'));
reset role;
insert into pg_temp.eigsti_unassigned_results(result) values(ok((select coordinator_id='33333333-3333-4333-8333-333333333333' from public.visits where id=(select id from pg_temp.eigsti_unassigned_ids where label='visit')),'Date now has chosen lead'));
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from public.visit_participants where visit_id=(select id from pg_temp.eigsti_unassigned_ids where label='visit') and duty='helping'),2::bigint,'Assigning lead keeps helpers'));
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select id from pg_temp.eigsti_unassigned_ids where label='visit')),3::bigint,'Lead added to explicit reservation'));
set local role authenticated;
insert into pg_temp.eigsti_unassigned_results(result) values(lives_ok($q$select public.save_visit((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000008','{"coordinator_id":null}')$q$,'PM can clear lead without losing planned work'));
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_unassigned_results(result) values(throws_ok($q$select public.save_visit((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000009','{"coordinator_id":"33333333-3333-4333-8333-333333333333"}')$q$,'42501','Visit coordinator required','Responsible lead cannot claim an unassigned scheduled entry'));
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_unassigned_results(result) values(lives_ok($q$select public.save_visit((select id from pg_temp.eigsti_unassigned_ids where label='work'),(select id from pg_temp.eigsti_unassigned_ids where label='visit'),'abcdefab-cdef-4abc-8abc-000000000010','{"state":"cancelled"}')$q$,'PM can remove unassigned scheduled date'));
reset role;
insert into pg_temp.eigsti_unassigned_results(result) values(is((select count(*) from private.visit_bookings where visit_id=(select id from pg_temp.eigsti_unassigned_ids where label='visit')),0::bigint,'Cancellation clears actual reservations'));
insert into pg_temp.eigsti_unassigned_results(result) values(ok(not has_table_privilege('authenticated','public.visits','INSERT'),'No direct schedule writes added'));
do $validation$ begin if exists(select 1 from pg_temp.eigsti_unassigned_results where result not like 'ok %') then raise exception 'Unassigned work checks failed'; end if; end; $validation$;
select result from pg_temp.eigsti_unassigned_results order by ordinal;
select * from finish();

rollback to savepoint unassigned_checks;
release savepoint unassigned_checks;
commit;
select 28::integer as checks,0::integer as failed,'0022 applied; synthetic fixtures removed'::text as result;
