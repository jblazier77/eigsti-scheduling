-- Isolated test project first; apply once after 0001 and 0002.
-- No customer fixtures, paid services or administrative key required.
begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('eigsti-job-files','eigsti-job-files',false,10485760,array['application/pdf','image/jpeg','image/png','image/webp','image/heic','image/heif']);

create table public.job_files (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete restrict,
  filename text not null check(length(filename) between 1 and 180),
  mime_type text not null check(mime_type in ('application/pdf','image/jpeg','image/png','image/webp','image/heic','image/heif')),
  byte_size bigint not null check(byte_size between 1 and 10485760),
  object_path text generated always as (job_id::text || '/' || id::text) stored unique,
  status text not null default 'pending' check(status in ('pending','ready','archived')),
  created_by uuid not null references public.app_users(id) on delete restrict,
  updated_by uuid not null references public.app_users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index job_files_active_job on public.job_files(job_id,created_at,id) where status <> 'archived';

create function private.can_write_job_file(p_job_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.jobs j where j.id=p_job_id) and
    (private.has_role('pm') or (private.has_role('lead') and private.can_read_job(p_job_id)));
$$;
create function private.can_read_job_file(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.job_files f where f.object_path=p_path and (
    (f.status='ready' and private.can_read_job(f.job_id)) or
    (f.status='pending' and f.created_by=auth.uid() and private.can_write_job_file(f.job_id))));
$$;
create function private.can_upload_job_file(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.job_files f where f.object_path=p_path and f.status='pending'
    and f.created_by=auth.uid() and private.can_write_job_file(f.job_id));
$$;

alter table public.job_files enable row level security;
revoke all on public.job_files from public,anon,authenticated;
grant select on public.job_files to authenticated;
create policy authorized_file_metadata on public.job_files for select to authenticated using (
  (status='ready' and private.can_read_job(job_id)) or
  (status='pending' and created_by=auth.uid() and private.can_write_job_file(job_id)));

-- Restrictive policies also fence off pre-existing broad storage policies.
create policy eigsti_file_read on storage.objects for select to authenticated
  using(bucket_id='eigsti-job-files' and private.can_read_job_file(name));
create policy eigsti_file_insert on storage.objects for insert to authenticated
  with check(bucket_id='eigsti-job-files' and private.can_upload_job_file(name));
create policy eigsti_file_read_boundary on storage.objects as restrictive for select to authenticated
  using(bucket_id<>'eigsti-job-files' or private.can_read_job_file(name));
create policy eigsti_file_insert_boundary on storage.objects as restrictive for insert to authenticated
  with check(bucket_id<>'eigsti-job-files' or private.can_upload_job_file(name));
create policy eigsti_file_anon_boundary on storage.objects as restrictive for all to anon
  using(bucket_id<>'eigsti-job-files') with check(bucket_id<>'eigsti-job-files');
create policy eigsti_file_no_overwrite on storage.objects as restrictive for update to public
  using(bucket_id<>'eigsti-job-files') with check(bucket_id<>'eigsti-job-files');
create policy eigsti_file_no_delete on storage.objects as restrictive for delete to public
  using(bucket_id<>'eigsti-job-files');

create function public.begin_job_file(p_job_id uuid,p_request_id uuid,p_filename text,p_mime text,p_size bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_actor uuid := auth.uid(); v_payload jsonb; v_prior private.command_requests%rowtype; v_file public.job_files%rowtype; v_extension text; v_expected text;
begin
  if not private.can_write_job_file(p_job_id) then raise exception using errcode='42501',message='File write access required'; end if;
  if p_request_id is null or p_filename is null or length(p_filename) not between 1 and 180 or btrim(p_filename)='' or
    p_filename ~ '[[:cntrl:]/\\]' or left(btrim(p_filename),1)='.' or p_size is null or p_size not between 1 and 10485760 then
    raise exception using errcode='22023',message='Invalid file details';
  end if;
  v_extension := lower(substring(btrim(p_filename) from '\.([^.]+)$'));
  v_expected := case v_extension when 'pdf' then 'application/pdf' when 'jpg' then 'image/jpeg' when 'jpeg' then 'image/jpeg'
    when 'png' then 'image/png' when 'webp' then 'image/webp' when 'heic' then 'image/heic' when 'heif' then 'image/heif' else null end;
  if v_expected is null or p_mime is distinct from v_expected then raise exception using errcode='22023',message='Invalid file type'; end if;
  v_payload := jsonb_build_object('job_id',p_job_id,'filename',btrim(p_filename),'mime',p_mime,'size',p_size);
  perform pg_advisory_xact_lock(hashtextextended(v_actor::text || ':begin_job_file:' || p_request_id::text,0));
  select * into v_prior from private.command_requests where actor_id=v_actor and operation='begin_job_file' and request_id=p_request_id;
  if found then
    if v_prior.payload <> v_payload then raise exception using errcode='23505',message='Request payload changed'; end if;
    return jsonb_build_object('id',v_prior.result_id);
  end if;
  perform 1 from public.jobs where id=p_job_id for update;
  if (select count(*) from public.job_files where job_id=p_job_id and status<>'archived') >= 100 then
    raise exception using errcode='22023',message='File limit reached';
  end if;
  insert into public.job_files(job_id,filename,mime_type,byte_size,created_by,updated_by)
    values(p_job_id,btrim(p_filename),p_mime,p_size,v_actor,v_actor) returning * into v_file;
  insert into public.audit_events(job_id,actor_id,operation,changed_fields,request_id)
    values(p_job_id,v_actor,'begin_job_file',array['file:' || v_file.id::text,'pending'],p_request_id);
  insert into private.command_requests(actor_id,request_id,operation,payload,result_id)
    values(v_actor,p_request_id,'begin_job_file',v_payload,v_file.id);
  return jsonb_build_object('id',v_file.id);
end;
$$;

create function public.finish_job_file(p_job_id uuid,p_file_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_file public.job_files%rowtype; v_metadata jsonb;
begin
  if not private.can_write_job_file(p_job_id) then raise exception using errcode='42501',message='File write access required'; end if;
  select * into v_file from public.job_files where id=p_file_id and job_id=p_job_id for update;
  if not found or v_file.status='archived' then raise exception using errcode='P0002',message='File unavailable'; end if;
  if v_file.status='ready' then return jsonb_build_object('id',v_file.id); end if;
  if v_file.created_by <> auth.uid() then raise exception using errcode='42501',message='Upload owner required'; end if;
  select metadata into v_metadata from storage.objects where bucket_id='eigsti-job-files' and name=v_file.object_path;
  if not found then raise exception using errcode='55000',message='Upload not complete'; end if;
  if (v_metadata->>'size') is null or (v_metadata->>'size') !~ '^[0-9]+$' then
    raise exception using errcode='22023',message='Uploaded file does not match';
  end if;
  if (v_metadata->>'size')::numeric <> v_file.byte_size or (v_metadata->>'mimetype') is distinct from v_file.mime_type then
    raise exception using errcode='22023',message='Uploaded file does not match';
  end if;
  update public.job_files set status='ready',updated_at=clock_timestamp(),updated_by=auth.uid() where id=v_file.id;
  insert into public.audit_events(job_id,actor_id,operation,changed_fields)
    values(p_job_id,auth.uid(),'finish_job_file',array['file:' || v_file.id::text,'ready']);
  return jsonb_build_object('id',v_file.id);
end;
$$;

create function public.archive_job_file(p_job_id uuid,p_file_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_file public.job_files%rowtype;
begin
  if not private.can_write_job_file(p_job_id) then raise exception using errcode='42501',message='File write access required'; end if;
  select * into v_file from public.job_files where id=p_file_id and job_id=p_job_id for update;
  if not found then raise exception using errcode='P0002',message='File unavailable'; end if;
  if not private.has_role('pm') and v_file.created_by<>auth.uid() then raise exception using errcode='42501',message='Only your own uploads can be removed'; end if;
  if v_file.status<>'archived' then
    update public.job_files set status='archived',updated_at=clock_timestamp(),updated_by=auth.uid() where id=v_file.id;
    insert into public.audit_events(job_id,actor_id,operation,changed_fields)
      values(p_job_id,auth.uid(),'archive_job_file',array['file:' || v_file.id::text,'archived']);
  end if;
  return jsonb_build_object('id',v_file.id);
end;
$$;

revoke all on function private.can_write_job_file(uuid),private.can_read_job_file(text),private.can_upload_job_file(text) from public,anon,authenticated;
grant execute on function private.can_write_job_file(uuid),private.can_read_job_file(text),private.can_upload_job_file(text) to authenticated;
revoke all on function public.begin_job_file(uuid,uuid,text,text,bigint),public.finish_job_file(uuid,uuid),public.archive_job_file(uuid,uuid) from public,anon,authenticated;
grant execute on function public.begin_job_file(uuid,uuid,text,text,bigint),public.finish_job_file(uuid,uuid),public.archive_job_file(uuid,uuid) to authenticated;
comment on table public.job_files is 'Private original photos/PDFs. Pending upload then metadata-checked publication; soft archive retains bytes/history. No direct object overwrite/delete. Not content scanning.';
notify pgrst,'reload schema';
commit;
