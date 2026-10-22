-- Apply once after 0001-0006 in isolated test. Backfills existing ownership;
-- creates no employee/customer fixtures and reserves no dates or helpers.
begin;

create table private.lead_queues (
  lead_id uuid primary key references public.app_users(id) on delete restrict,
  work_ids uuid[] not null default array[]::uuid[],
  revision bigint not null default 0 check(revision>=0)
);
create table private.lead_queue_events (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.app_users(id) on delete restrict,
  actor_id uuid references public.app_users(id) on delete restrict,
  revision bigint not null,
  operation text not null check(operation in ('membership','reorder')),
  work_ids uuid[] not null,
  request_id uuid,
  created_at timestamptz not null default now(),
  unique(lead_id,revision)
);
alter table private.lead_queues enable row level security;
alter table private.lead_queue_events enable row level security;
revoke all on private.lead_queues,private.lead_queue_events from public,anon,authenticated;
create index work_open_lead on public.work_items(responsible_lead,created_at,id) where completion='open';

-- Small-company correctness boundary: all membership/reorder mutations acquire
-- this same transaction lock before a queue row. Read RPCs do not take it.
-- Queue saves never lock jobs/work, so existing job->work->queue writes cannot
-- deadlock with an order save. Cross-lead membership changes serialize here.
create function private.sync_lead_queue(p_lead_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_state private.lead_queues%rowtype; v_order uuid[]; v_actor uuid;
begin
  if p_lead_id is null then return; end if;
  perform pg_advisory_xact_lock(hashtextextended('eigsti:lead-queue-membership',0));
  insert into private.lead_queues(lead_id) values(p_lead_id) on conflict do nothing;
  select * into strict v_state from private.lead_queues where lead_id=p_lead_id for update;
  -- Preserve surviving order, append newly owned open work deterministically.
  v_order := array(
    select w.id from unnest(v_state.work_ids) with ordinality e(work_id,position)
    join public.work_items w on w.id=e.work_id
    join public.jobs j on j.id=w.job_id
    where w.responsible_lead=p_lead_id and w.completion='open' and j.lifecycle='open'
    order by e.position
  ) || array(
    select w.id from public.work_items w join public.jobs j on j.id=w.job_id
    where w.responsible_lead=p_lead_id and w.completion='open' and j.lifecycle='open'
      and not(w.id=any(v_state.work_ids)) order by w.created_at,w.id
  );
  if v_order is distinct from v_state.work_ids then
    update private.lead_queues set work_ids=v_order,revision=revision+1 where lead_id=p_lead_id returning * into v_state;
    select id into v_actor from public.app_users where id=auth.uid();
    insert into private.lead_queue_events(lead_id,actor_id,revision,operation,work_ids)
      values(p_lead_id,v_actor,v_state.revision,'membership',v_order);
  end if;
end;
$$;

create function private.work_queue_membership()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_lead uuid;
begin
  if tg_op='UPDATE' and new.responsible_lead is not distinct from old.responsible_lead
    and new.completion is not distinct from old.completion and new.job_id=old.job_id then return null; end if;
  for v_lead in select distinct lead_id from unnest(
    case when tg_op='INSERT' then array[new.responsible_lead] else array[old.responsible_lead,new.responsible_lead] end
  ) lead_id where lead_id is not null order by lead_id loop
    perform private.sync_lead_queue(v_lead);
  end loop;
  return null;
end;
$$;
create trigger work_queue_membership after insert or update of responsible_lead,completion,job_id
  on public.work_items for each row execute function private.work_queue_membership();

create function private.job_queue_membership()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_lead uuid;
begin
  if new.lifecycle=old.lifecycle then return null; end if;
  for v_lead in select distinct responsible_lead from public.work_items
    where job_id=new.id and responsible_lead is not null order by responsible_lead loop
    perform private.sync_lead_queue(v_lead);
  end loop;
  return null;
end;
$$;
create trigger job_queue_membership after update of lifecycle on public.jobs
  for each row execute function private.job_queue_membership();

-- Both RPCs enforce the target queue scope before reading any queue contents.
create function private.lead_queue_result(p_lead_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_name text; v_order uuid[]; v_revision bigint; v_items jsonb;
begin
  if not (private.has_role('pm') or (private.has_role('lead') and auth.uid()=p_lead_id)) then
    raise exception using errcode='42501',message='PM or own lead queue required';
  end if;
  select display_name into v_name from public.app_users where id=p_lead_id and active and 'lead'=any(roles);
  if not found then raise exception using errcode='P0002',message='Active lead unavailable'; end if;
  select work_ids,revision into v_order,v_revision from private.lead_queues where lead_id=p_lead_id;
  v_order := coalesce(v_order,array[]::uuid[]); v_revision := coalesce(v_revision,0);
  if cardinality(v_order)>500 then raise exception using errcode='22023',message='Queue limit exceeded'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',w.id,'job_id',w.job_id,'description',w.description,'job_title',j.title,
    'customer_name',j.customer_name,'readiness',w.readiness,'waiting_until',w.waiting_until
  ) order by e.position),'[]'::jsonb) into v_items
  from unnest(v_order) with ordinality e(work_id,position)
    join public.work_items w on w.id=e.work_id join public.jobs j on j.id=w.job_id
  where w.responsible_lead=p_lead_id and w.completion='open' and j.lifecycle='open';
  return jsonb_build_object('lead_id',p_lead_id,'lead_name',v_name,'revision',v_revision,'items',v_items);
end;
$$;
create function public.get_lead_queue(p_lead_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select private.lead_queue_result(p_lead_id);
$$;

create function public.save_lead_queue(p_lead_id uuid,p_request_id uuid,p_work_ids uuid[])
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_payload jsonb; v_prior private.command_requests%rowtype; v_expected uuid[];
  v_sorted uuid[]; v_state private.lead_queues%rowtype;
begin
  perform private.lead_queue_result(p_lead_id);
  if p_request_id is null or p_work_ids is null then raise exception using errcode='22023',message='Invalid queue order'; end if;
  if cardinality(p_work_ids)>500 or array_ndims(p_work_ids)>1 then raise exception using errcode='22023',message='Invalid queue order'; end if;
  if array_position(p_work_ids,null) is not null
    or (select count(distinct id) from unnest(p_work_ids) id)<>cardinality(p_work_ids) then
    raise exception using errcode='22023',message='Invalid queue order';
  end if;
  v_payload := jsonb_build_object('lead_id',p_lead_id,'work_ids',p_work_ids);
  perform pg_advisory_xact_lock(hashtextextended('eigsti:lead-queue-membership',0));
  -- Recheck after waiting; live roles are never taken from token claims.
  perform private.lead_queue_result(p_lead_id);
  select * into v_prior from private.command_requests where actor_id=auth.uid() and operation='save_lead_queue' and request_id=p_request_id;
  if found then
    if v_prior.payload<>v_payload then raise exception using errcode='23505',message='Request payload changed'; end if;
    return private.lead_queue_result(p_lead_id);
  end if;
  insert into private.lead_queues(lead_id) values(p_lead_id) on conflict do nothing;
  select * into strict v_state from private.lead_queues where lead_id=p_lead_id for update;
  select coalesce(array_agg(w.id order by w.id),array[]::uuid[]) into v_expected
    from public.work_items w join public.jobs j on j.id=w.job_id
    where w.responsible_lead=p_lead_id and w.completion='open' and j.lifecycle='open';
  select coalesce(array_agg(id order by id),array[]::uuid[]) into v_sorted from unnest(p_work_ids) id;
  if v_sorted is distinct from v_expected then raise exception using errcode='22023',message='Queue membership changed'; end if;
  if p_work_ids is distinct from v_state.work_ids then
    update private.lead_queues set work_ids=p_work_ids,revision=revision+1 where lead_id=p_lead_id returning * into v_state;
    insert into private.lead_queue_events(lead_id,actor_id,revision,operation,work_ids,request_id)
      values(p_lead_id,auth.uid(),v_state.revision,'reorder',p_work_ids,p_request_id);
  end if;
  insert into private.command_requests(actor_id,request_id,operation,payload,result_id)
    values(auth.uid(),p_request_id,'save_lead_queue',v_payload,p_lead_id);
  return private.lead_queue_result(p_lead_id);
end;
$$;

-- Build queue membership for existing assigned work without changing ownership.
do $backfill$
declare v_lead uuid;
begin
  for v_lead in select distinct responsible_lead from public.work_items
    where responsible_lead is not null order by responsible_lead loop
    perform private.sync_lead_queue(v_lead);
  end loop;
end;
$backfill$;

revoke all on function private.sync_lead_queue(uuid),private.work_queue_membership(),private.job_queue_membership(),private.lead_queue_result(uuid) from public,anon,authenticated;
revoke all on function public.get_lead_queue(uuid),public.save_lead_queue(uuid,uuid,uuid[]) from public,anon,authenticated;
grant execute on function public.get_lead_queue(uuid),public.save_lead_queue(uuid,uuid,uuid[]) to authenticated;
notify pgrst,'reload schema';
commit;
