-- Apply once after 0021. PM may schedule work before choosing a lead.
begin;
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
commit;
