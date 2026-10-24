-- Apply once after 0015. Employee profile management; no Auth secrets or email integration.
begin;
create table private.employee_events(
 id uuid primary key default gen_random_uuid(),employee_id uuid not null references public.app_users(id),
 actor_id uuid not null references public.app_users(id),request_id uuid not null,
 before_state jsonb not null,after_state jsonb not null,created_at timestamptz not null default now()
);
alter table private.employee_events enable row level security;
revoke all on private.employee_events from public,anon,authenticated;
create function private.employee_result(p_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',u.id,'display_name',u.display_name,'roles',u.roles,'active',u.active,'updated_at',u.updated_at,
 'open_work',(select count(*) from public.work_items w join public.jobs j on j.id=w.job_id where w.responsible_lead=u.id and w.completion='open' and j.lifecycle='open'),
 'scheduled_work',(select count(*) from public.visits v join public.work_items w on w.id=v.work_item_id join public.jobs j on j.id=w.job_id where j.lifecycle='open' and v.state='planned' and v.end_date>=(now() at time zone 'America/Chicago')::date and (v.coordinator_id=u.id or exists(select 1 from public.visit_participants p where p.visit_id=v.id and p.user_id=u.id))))
 from public.app_users u where u.id=p_id;
$$;
create function public.list_employees() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not private.has_role('admin') then raise exception using errcode='42501',message='Administrator account required'; end if;
 if (select count(*) from public.app_users)>500 then raise exception using errcode='22023',message='Employee list limit reached'; end if;
 return coalesce((select jsonb_agg(private.employee_result(u.id) order by lower(u.display_name),u.id) from public.app_users u),'[]'::jsonb);
end; $$;
create function public.save_employee(p_id uuid,p_request_id uuid,p_expected timestamptz,p_values jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare u public.app_users%rowtype;prior private.command_requests%rowtype;payload jsonb;name_value text;roles_value text[];active_value boolean;before_data jsonb;
begin
 if not private.has_role('admin') then raise exception using errcode='42501',message='Administrator account required'; end if;
 if p_id is null or p_request_id is null or p_expected is null or p_values is null or jsonb_typeof(p_values)<>'object' or not(p_values ?& array['display_name','roles','active']) or (select count(*) from jsonb_object_keys(p_values))<>3 then raise exception using errcode='22023',message='Invalid employee details'; end if;
 if jsonb_typeof(p_values->'display_name')<>'string' or jsonb_typeof(p_values->'roles')<>'array' or jsonb_typeof(p_values->'active')<>'boolean' then raise exception using errcode='22023',message='Invalid employee details'; end if;
 name_value:=btrim(p_values->>'display_name');
 if length(name_value) not between 1 and 100 or name_value ~ '[[:cntrl:]]' or jsonb_array_length(p_values->'roles') not between 1 and 4 or exists(select 1 from jsonb_array_elements(p_values->'roles') r where jsonb_typeof(r)<>'string' or (r#>>'{}') not in ('admin','pm','lead','helper')) then raise exception using errcode='22023',message='Invalid employee details'; end if;
 select array_agg(r order by r) into roles_value from jsonb_array_elements_text(p_values->'roles') r;
 if cardinality(roles_value)<>(select count(distinct r) from unnest(roles_value) r) then raise exception using errcode='22023',message='Invalid employee details'; end if;
 active_value:=(p_values->>'active')::boolean;
 p_values:=jsonb_build_object('display_name',name_value,'roles',roles_value,'active',active_value);
 payload:=jsonb_build_object('id',p_id,'expected',p_expected,'values',p_values);
 -- Profile editors serialize, and actor/target rows lock in stable order. Scheduling
 -- takes this same mutex first, so role validation cannot race a new assignment.
 perform pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
 perform id from public.app_users where id in (auth.uid(),p_id) order by id for update;
 if not private.has_role('admin') then raise exception using errcode='42501',message='Administrator account required'; end if;
 select * into u from public.app_users where id=p_id;
 if not found then raise exception using errcode='P0002',message='Employee unavailable'; end if;
 select * into prior from private.command_requests where actor_id=auth.uid() and operation='save_employee' and request_id=p_request_id;
 if found then
  if prior.payload<>payload then raise exception using errcode='23505',message='Request payload changed'; end if;
  return private.employee_result(p_id);
 end if;
 -- An editor must remain an active admin. This also prevents concurrent editors
 -- from removing the final active admin: authority is rechecked under the mutex.
 if p_id=auth.uid() and (not active_value or not 'admin'=any(roles_value)) then raise exception using errcode='22023',message='You cannot deactivate yourself or remove your own Administrator role.'; end if;
 if u.updated_at<>p_expected then raise exception using errcode='22023',message='Employee changed. Refresh before saving again.'; end if;
 if active_value and not 'lead'=any(roles_value) and (exists(select 1 from public.work_items w join public.jobs j on j.id=w.job_id where w.responsible_lead=p_id and w.completion='open' and j.lifecycle='open') or exists(select 1 from public.visits v join public.work_items w on w.id=v.work_item_id join public.jobs j on j.id=w.job_id where j.lifecycle='open' and v.coordinator_id=p_id and v.state='planned' and v.end_date>=(now() at time zone 'America/Chicago')::date)) then raise exception using errcode='22023',message='Reassign open lead work and future coordination before removing the Lead role.'; end if;
 if active_value and not roles_value && array['lead','helper']::text[] and exists(select 1 from public.visit_participants p join public.visits v on v.id=p.visit_id join public.work_items w on w.id=v.work_item_id join public.jobs j on j.id=w.job_id where p.user_id=p_id and p.duty='helping' and j.lifecycle='open' and v.state='planned' and v.end_date>=(now() at time zone 'America/Chicago')::date) then raise exception using errcode='22023',message='Reassign future helping work or retain a Lead or Helper role.'; end if;
 before_data:=to_jsonb(u);
 update public.app_users set display_name=name_value,roles=roles_value,active=active_value,updated_at=clock_timestamp() where id=p_id returning * into u;
 insert into private.employee_events(employee_id,actor_id,request_id,before_state,after_state) values(p_id,auth.uid(),p_request_id,before_data,to_jsonb(u));
 insert into private.command_requests(actor_id,request_id,operation,payload,result_id) values(auth.uid(),p_request_id,'save_employee',payload,p_id);
 return private.employee_result(p_id);
end; $$;
revoke all on function private.employee_result(uuid) from public,anon,authenticated;
revoke all on function public.list_employees(),public.save_employee(uuid,uuid,timestamptz,jsonb) from public,anon,authenticated;
grant execute on function public.list_employees(),public.save_employee(uuid,uuid,timestamptz,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
