-- READ ONLY. Run as the project owner in SQL Editor after 0001-0016.
-- No migrations, grants, fixtures or customer information are written or returned.
-- This checks installed capabilities; it does not certify migration checksums,
-- restore success, Auth login, concurrent races, offsite backups or pilot approval.
begin read only;
with required_functions(signature) as (values
 ('public.create_quick_work(uuid,uuid,jsonb,jsonb,integer,jsonb)'),
 ('public.save_visit_card(uuid,uuid,uuid,jsonb,uuid[])'),
 ('public.list_schedule(date,date,boolean)'),
 ('public.list_contact_commitments(date,date,boolean)'),
 ('public.save_contact_commitment(uuid,uuid,uuid,uuid,jsonb,boolean)'),
 ('public.set_job_archive(uuid,uuid,text,text)'),
 ('public.list_employees()'),
 ('public.save_employee(uuid,uuid,timestamp with time zone,jsonb)')
), required_tables(name) as (values
 ('app_users'),('jobs'),('work_items'),('job_contacts'),('job_files'),
 ('visits'),('visit_participants'),('subcontractors')
), checks(label,passed) as (
 select 'Latest pilot functions exist',bool_and(to_regprocedure(signature) is not null) from required_functions
 union all select 'Anonymous cannot execute pilot commands',bool_and(case when to_regprocedure(signature) is null then false else not has_function_privilege('anon',to_regprocedure(signature),'EXECUTE') end) from required_functions
 union all select 'Required tables exist with row security enabled',count(c.oid)=8 and bool_and(coalesce(c.relrowsecurity,false)) from required_tables t left join pg_class c on c.relname=t.name and c.relnamespace='public'::regnamespace
 union all select 'Authenticated clients cannot directly mutate required tables',bool_and(case when to_regclass('public.'||name) is null then false else not has_table_privilege('authenticated',to_regclass('public.'||name),'INSERT,UPDATE,DELETE,TRUNCATE') end) from required_tables
 union all select 'Private file bucket is private and bounded',exists(select 1 from storage.buckets where id='eigsti-job-files' and not public and file_size_limit=10485760)
 union all select 'At least one active administrator',exists(select 1 from public.app_users where active and 'admin'=any(roles))
 union all select 'At least one active project manager',exists(select 1 from public.app_users where active and 'pm'=any(roles))
 union all select 'Every ready file has storage metadata with matching size',not exists(select 1 from public.job_files f left join storage.objects o on o.bucket_id='eigsti-job-files' and o.name=f.object_path where f.status='ready' and (o.id is null or (o.metadata->>'size') is null or (o.metadata->>'size')::bigint<>f.byte_size))
 union all select 'App user identities exist in Auth',not exists(select 1 from public.app_users u left join auth.users a on a.id=u.id where a.id is null)
 union all select 'Storage overwrite/deletion restrictive fences exist',count(*)=2 from pg_policies where schemaname='storage' and tablename='objects' and policyname in ('eigsti_file_no_overwrite','eigsti_file_no_delete') and permissive='RESTRICTIVE'
)
select label,case when passed then 'PASS' else 'REVIEW REQUIRED' end as result from checks order by label;
rollback;
