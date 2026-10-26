-- Apply once after 0022. Monday-Saturday crew work; Sunday remains excluded.
begin;
select pg_advisory_xact_lock(hashtextextended('eigsti:scheduling',0));
do $constraint$ declare names text[]; begin
 select array_agg(conname) into names from pg_constraint where conrelid='public.visits'::regclass and contype='c' and pg_get_constraintdef(oid) ilike '%isodow%';
 if coalesce(cardinality(names),0)<>1 then raise exception 'Expected one workday constraint; verify database state'; end if;
 execute format('alter table public.visits drop constraint %I',names[1]);
end; $constraint$;
alter table public.visits add constraint visits_monday_saturday_check check(extract(isodow from start_date)<7 and extract(isodow from end_date)<7);
create or replace function private.rebuild_visit(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare v public.visits%rowtype; v_user uuid; v_job uuid;
begin
 select * into strict v from public.visits where id=p_id;
 select job_id into v_job from public.work_items where id=v.work_item_id;
 for v_user in select user_id from public.visit_participants where visit_id=p_id order by user_id loop
  perform pg_advisory_xact_lock(hashtextextended('eigsti:calendar:'||v_user::text,0));
 end loop;
 delete from private.visit_bookings where visit_id=p_id;
 if v.state='planned' then
  if exists(select 1 from public.visit_participants p join public.app_users u on u.id=p.user_id
   where p.visit_id=p_id and (not u.active or (p.duty='leading' and not 'lead'=any(u.roles)) or (p.duty='helping' and not u.roles && array['lead','helper']::text[])))
  then raise exception using errcode='22023',message='Active staff required'; end if;
  insert into private.visit_bookings(visit_id,user_id,starts_at,ends_at)
  select v.id,p.user_id,
   (d::date+case v.slot when 'afternoon' then time '12:00' when 'timed' then v.start_time else time '07:00' end) at time zone 'America/Chicago',
   (d::date+case v.slot when 'morning' then time '12:00' when 'timed' then v.end_time else time '15:30' end) at time zone 'America/Chicago'
  from public.visit_participants p cross join generate_series(0,v.end_date-v.start_date) n
  cross join lateral (select v.start_date+n as d) days
  where p.visit_id=v.id and v.slot<>'day' and extract(isodow from d)<7;
  if exists(select 1 from private.visit_bookings a join private.visit_bookings b on b.user_id=a.user_id and b.visit_id<>a.visit_id
   and a.starts_at<b.ends_at and b.starts_at<a.ends_at where a.visit_id=p_id)
  then raise exception using errcode='23P01',message='Staff scheduling conflict'; end if;
 end if;
 -- Named participants retain shared job information while a noncancelled visit exists.
 -- Cancellation/removal revokes only this entitlement, never work ownership.
 update private.job_access set revoked_at=clock_timestamp() where job_id=v_job and reason='helping_assignment' and revoked_at is null;
 insert into private.job_access(job_id,user_id,reason,created_by)
 select distinct v_job,p.user_id,'helping_assignment',auth.uid() from public.visit_participants p
 join public.visits x on x.id=p.visit_id join public.work_items w on w.id=x.work_item_id
 where w.job_id=v_job and x.state<>'cancelled'
 on conflict(job_id,user_id,reason) do update set revoked_at=null;
end; $$;
-- Keep existing multi-day explicit reservations consistent with the expanded workweek.
-- Add only Saturday booking rows; do not rewrite access, participants or history.
insert into private.visit_bookings(visit_id,user_id,starts_at,ends_at)
select v.id,p.user_id,
 (d::date+case v.slot when 'afternoon' then time '12:00' when 'timed' then v.start_time else time '07:00' end) at time zone 'America/Chicago',
 (d::date+case v.slot when 'morning' then time '12:00' when 'timed' then v.end_time else time '15:30' end) at time zone 'America/Chicago'
from public.visits v join public.visit_participants p on p.visit_id=v.id
cross join lateral generate_series(0,v.end_date-v.start_date) n
cross join lateral (select v.start_date+n as d) days
where v.state='planned' and v.slot<>'day' and extract(isodow from d)=6
on conflict(visit_id,user_id,starts_at) do nothing;
do $conflicts$ begin
 if exists(select 1 from private.visit_bookings a join private.visit_bookings b on b.user_id=a.user_id and b.visit_id<>a.visit_id and a.starts_at<b.ends_at and b.starts_at<a.ends_at where extract(isodow from a.starts_at at time zone 'America/Chicago')=6) then raise exception 'Saturday reservations overlap; review existing plans before applying'; end if;
end; $conflicts$;
notify pgrst,'reload schema';
commit;
