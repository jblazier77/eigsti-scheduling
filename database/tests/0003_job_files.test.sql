-- Isolated test ONLY after migrations 0001/0002/0003. Synthetic metadata only.
-- Storage rows simulate API metadata, NOT binary uploads; all rows roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
create temporary table eigsti_file_results(ordinal integer primary key,result text not null) on commit drop;
grant insert,select on pg_temp.eigsti_file_results to authenticated,anon;
insert into auth.users(id,email) values
 ('11111111-1111-4111-8111-111111111111','file-test-1@example.invalid'),
 ('22222222-2222-4222-8222-222222222222','file-test-2@example.invalid'),
 ('33333333-3333-4333-8333-333333333333','file-test-3@example.invalid'),
 ('44444444-4444-4444-8444-444444444444','file-test-4@example.invalid'),
 ('55555555-5555-4555-8555-555555555555','file-test-5@example.invalid'),
 ('66666666-6666-4666-8666-666666666666','file-test-6@example.invalid'),
 ('77777777-7777-4777-8777-777777777777','file-test-7@example.invalid');
insert into public.app_users(id,display_name,roles,active) values
 ('11111111-1111-4111-8111-111111111111','SYNTHETIC File Tester 1',array['pm'],true),
 ('22222222-2222-4222-8222-222222222222','SYNTHETIC File Tester 2',array['pm'],true),
 ('33333333-3333-4333-8333-333333333333','SYNTHETIC File Tester 3',array['lead'],true),
 ('44444444-4444-4444-8444-444444444444','SYNTHETIC File Tester 4',array['helper'],true),
 ('55555555-5555-4555-8555-555555555555','SYNTHETIC File Tester 5',array['admin'],true),
 ('66666666-6666-4666-8666-666666666666','SYNTHETIC File Tester 6',array['pm'],false);
insert into public.jobs(id,customer_name,phone,phone_action,address,title,responsible_pm,created_by,updated_by) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC A','3095550101','+13095550101','Fictional A','Demo A','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC B','3095550102','+13095550102','Fictional B','Demo B','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222');
insert into public.work_items(job_id,description,responsible_lead,created_by,updated_by) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Whole job','33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into private.job_access(job_id,user_id,reason,created_by) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','44444444-4444-4444-8444-444444444444','helping_assignment','11111111-1111-4111-8111-111111111111');
insert into public.job_files(id,job_id,filename,mime_type,byte_size,status,created_by,updated_by) values
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Plan.pdf','application/pdf',100,'ready','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC Other.pdf','application/pdf',100,'ready','22222222-2222-4222-8222-222222222222','22222222-2222-4222-8222-222222222222'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Lead.HEIC','image/heic',100,'ready','33333333-3333-4333-8333-333333333333','33333333-3333-4333-8333-333333333333'),
 ('ffffffff-ffff-4fff-8fff-ffffffffffff','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','SYNTHETIC Pending.pdf','application/pdf',100,'pending','11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111');
insert into storage.objects(bucket_id,name,metadata)
 select 'eigsti-job-files',object_path,jsonb_build_object('size',byte_size,'mimetype',mime_type) from public.job_files where id in ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','dddddddd-dddd-4ddd-8ddd-dddddddddddd','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
insert into pg_temp.eigsti_file_results values(1,is((select public from storage.buckets where id='eigsti-job-files'),false,'File bucket is private'));
insert into pg_temp.eigsti_file_results values(2,is((select file_size_limit from storage.buckets where id='eigsti-job-files'),10485760::bigint,'Storage bucket enforces 10 MiB'));
insert into pg_temp.eigsti_file_results values(3,ok((select allowed_mime_types @> array['image/heic','image/heif','application/pdf'] from storage.buckets where id='eigsti-job-files'),'Bucket permits iPhone originals and PDFs'));
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_file_results values(4,is((select count(*) from public.job_files),2::bigint,'Helper sees only ready assigned-job file metadata'));
insert into pg_temp.eigsti_file_results values(5,is((select count(*) from storage.objects where bucket_id='eigsti-job-files'),2::bigint,'Helper storage access follows ready assigned files'));
insert into pg_temp.eigsti_file_results values(6,is((select count(*) from storage.objects where bucket_id='eigsti-job-files' and name=('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' || '/' || 'dddddddd-dddd-4ddd-8ddd-dddddddddddd')),0::bigint,'Other job object path hidden'));
insert into pg_temp.eigsti_file_results values(7,is(private.can_upload_job_file(('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' || '/' || 'ffffffff-ffff-4fff-8fff-ffffffffffff')),false,'Helper cannot upload to pending path'));
insert into pg_temp.eigsti_file_results values(8,throws_ok($$select public.begin_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','99999999-9999-4999-8999-999999999999','Test.pdf','application/pdf',100)$$,'42501','File write access required','Helper reserve denied'));
insert into pg_temp.eigsti_file_results values(9,throws_ok($$select public.finish_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff')$$,'42501','File write access required','Helper finish denied'));
insert into pg_temp.eigsti_file_results values(10,throws_ok($$select public.archive_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc')$$,'42501','File write access required','Helper archive denied'));
insert into pg_temp.eigsti_file_results values(11,throws_ok($$update public.job_files set status='ready' where id='ffffffff-ffff-4fff-8fff-ffffffffffff'$$,'42501',null,'Raw metadata publish denied'));
insert into pg_temp.eigsti_file_results values(12,throws_ok($$insert into storage.objects(bucket_id,name) values('eigsti-job-files',('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' || '/' || 'ffffffff-ffff-4fff-8fff-ffffffffffff'))$$,'42501',null,'Helper direct object insert denied'));
reset role;
update public.jobs set lifecycle='closed' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_file_results values(13,is((select count(*) from public.job_files),0::bigint,'Closure removes helper file metadata access'));
insert into pg_temp.eigsti_file_results values(14,is((select count(*) from storage.objects where bucket_id='eigsti-job-files'),0::bigint,'Closure removes helper object reads'));
reset role;
update public.jobs set lifecycle='open' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
update private.job_access set revoked_at=now() where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_file_results values(15,is((select count(*) from storage.objects where bucket_id='eigsti-job-files'),0::bigint,'Revoked assignment removes storage reads'));
reset role;
update private.job_access set revoked_at=null where job_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_file_results values(16,is((select count(*) from public.job_files),2::bigint,'Assigned lead sees ready job files'));
insert into pg_temp.eigsti_file_results values(17,throws_ok($$select public.begin_job_file('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','99999999-9999-4999-8999-999999999999','Test.pdf','application/pdf',100)$$,'42501','File write access required','Lead cannot reserve on unrelated job'));
insert into pg_temp.eigsti_file_results values(18,throws_ok($$select public.archive_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc')$$,'42501','Only your own uploads can be removed','Lead cannot remove PM upload'));
insert into pg_temp.eigsti_file_results values(19,throws_ok($$select public.finish_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','ffffffff-ffff-4fff-8fff-ffffffffffff')$$,'42501','Upload owner required','Lead cannot publish someone else pending upload'));
insert into pg_temp.eigsti_file_results values(20,lives_ok($$select public.begin_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','99999999-9999-4999-8999-999999999999','SYNTHETIC New.HEIC','image/heic',234)$$,'Assigned lead reserves iPhone photo'));
insert into pg_temp.eigsti_file_results values(21,is((select count(*) from public.job_files where filename='SYNTHETIC New.HEIC' and status='pending'),1::bigint,'Reservation creates one pending row'));
insert into pg_temp.eigsti_file_results values(22,lives_ok($$select public.begin_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','99999999-9999-4999-8999-999999999999','SYNTHETIC New.HEIC','image/heic',234)$$,'Reservation retry succeeds'));
insert into pg_temp.eigsti_file_results values(23,is((select count(*) from public.job_files where filename='SYNTHETIC New.HEIC'),1::bigint,'Retry creates no duplicate metadata'));
insert into pg_temp.eigsti_file_results values(24,is((select count(*) from public.audit_events where request_id='99999999-9999-4999-8999-999999999999'),1::bigint,'Retry creates no duplicate begin audit'));
insert into pg_temp.eigsti_file_results values(25,throws_ok($$select public.begin_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','99999999-9999-4999-8999-999999999999','Changed.HEIC','image/heic',234)$$,'23505','Request payload changed','Retry cannot change file identity'));
insert into pg_temp.eigsti_file_results values(26,throws_ok($$select public.finish_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',(select id from public.job_files where filename='SYNTHETIC New.HEIC'))$$,'55000','Upload not complete','Missing bytes cannot publish file'));
insert into pg_temp.eigsti_file_results values(27,lives_ok($$insert into storage.objects(bucket_id,name,metadata) select 'eigsti-job-files',object_path,'{"size":99,"mimetype":"image/heic"}'::jsonb from public.job_files where filename='SYNTHETIC New.HEIC'$$,'Uploader can insert only its reserved path'));
insert into pg_temp.eigsti_file_results values(28,throws_ok($$select public.finish_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',(select id from public.job_files where filename='SYNTHETIC New.HEIC'))$$,'22023','Uploaded file does not match','Stored byte size checked independently'));
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_file_results values(29,is((select count(*) from public.job_files),2::bigint,'Pending upload remains hidden from helper'));
insert into pg_temp.eigsti_file_results values(30,is((select count(*) from storage.objects where bucket_id='eigsti-job-files'),2::bigint,'Pending object remains hidden from helper'));
reset role;
update storage.objects set metadata='{"size":234,"mimetype":"application/pdf"}'::jsonb where bucket_id='eigsti-job-files' and name=(select object_path from public.job_files where filename='SYNTHETIC New.HEIC');
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_file_results values(31,throws_ok($$select public.finish_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',(select id from public.job_files where filename='SYNTHETIC New.HEIC'))$$,'22023','Uploaded file does not match','Stored MIME checked independently'));
reset role;
update storage.objects set metadata='{"size":234,"mimetype":"image/heic"}'::jsonb where bucket_id='eigsti-job-files' and name=(select object_path from public.job_files where filename='SYNTHETIC New.HEIC');
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_file_results values(32,lives_ok($$select public.finish_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',(select id from public.job_files where filename='SYNTHETIC New.HEIC'))$$,'Matching stored metadata can publish'));
insert into pg_temp.eigsti_file_results values(33,lives_ok($$select public.finish_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',(select id from public.job_files where filename='SYNTHETIC New.HEIC'))$$,'Finish retry succeeds'));
insert into pg_temp.eigsti_file_results values(34,is((select count(*) from public.audit_events where operation='finish_job_file'),1::bigint,'Finish retry has one history event'));
set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
insert into pg_temp.eigsti_file_results values(35,is((select count(*) from public.job_files),3::bigint,'Helper can read newly ready assigned file'));
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_file_results values(36,is(private.can_upload_job_file((select object_path from public.job_files where filename='SYNTHETIC New.HEIC')),false,'Ready object cannot be uploaded again'));
with changed as (
  update storage.objects set metadata='{}' where bucket_id='eigsti-job-files'
    and name=('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' || '/' || 'cccccccc-cccc-4ccc-8ccc-cccccccccccc') returning id
)
insert into pg_temp.eigsti_file_results
  select 37,is(count(*),0::bigint,'Storage overwrite is blocked') from changed;
insert into pg_temp.eigsti_file_results values(38,lives_ok($$select public.archive_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee')$$,'Lead can remove own upload'));
insert into pg_temp.eigsti_file_results values(39,is((select count(*) from public.job_files where id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),0::bigint,'Archived metadata hidden'));
insert into pg_temp.eigsti_file_results values(40,is((select count(*) from storage.objects where bucket_id='eigsti-job-files' and name=('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' || '/' || 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee')),0::bigint,'Archived object reads denied'));
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_file_results values(41,is((select count(*) from public.job_files),4::bigint,'PM sees all ready plus own pending files'));
insert into pg_temp.eigsti_file_results values(42,throws_ok($$select public.begin_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',null,'Test.pdf','application/pdf',100)$$,'22023','Invalid file details','Request ID required'));
insert into pg_temp.eigsti_file_results values(43,throws_ok($$select public.begin_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','99999999-9999-4999-8999-999999999999','Test.pdf','application/pdf',10485761)$$,'22023','Invalid file details','Oversized file rejected'));
insert into pg_temp.eigsti_file_results values(44,throws_ok($$select public.begin_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','99999999-9999-4999-8999-999999999999','../Test.pdf','application/pdf',100)$$,'22023','Invalid file details','Path traversal filename rejected'));
insert into pg_temp.eigsti_file_results values(45,throws_ok($$select public.begin_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','99999999-9999-4999-8999-999999999999','script.svg','image/svg+xml',100)$$,'22023','Invalid file type','Executable SVG format rejected'));
insert into pg_temp.eigsti_file_results values(46,throws_ok($$select public.begin_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','99999999-9999-4999-8999-999999999999','photo.jpg','text/html',100)$$,'22023','Invalid file type','Filename and MIME mismatch rejected'));
insert into pg_temp.eigsti_file_results values(47,throws_ok($$select public.archive_job_file('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','cccccccc-cccc-4ccc-8ccc-cccccccccccc')$$,'P0002','File unavailable','Forged job-file relation rejected'));
insert into pg_temp.eigsti_file_results values(48,throws_ok($$select public.finish_job_file('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','ffffffff-ffff-4fff-8fff-ffffffffffff')$$,'P0002','File unavailable','Forged parent cannot publish'));
insert into pg_temp.eigsti_file_results values(49,lives_ok($$select public.archive_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc')$$,'PM archives any job file'));
insert into pg_temp.eigsti_file_results values(50,lives_ok($$select public.archive_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc')$$,'Archive retry succeeds'));
insert into pg_temp.eigsti_file_results values(51,is((select count(*) from public.audit_events where operation='archive_job_file' and changed_fields @> array['file:' || 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'::text]),1::bigint,'Archive replay has one event'));
insert into pg_temp.eigsti_file_results values(52,is((select count(*) from storage.objects where bucket_id='eigsti-job-files' and name=('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' || '/' || 'cccccccc-cccc-4ccc-8ccc-cccccccccccc')),0::bigint,'Archived file cannot be read by PM'));
reset role;
insert into pg_temp.eigsti_file_results values(53,is((select count(*) from storage.objects where bucket_id='eigsti-job-files' and name=('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' || '/' || 'cccccccc-cccc-4ccc-8ccc-cccccccccccc')),1::bigint,'Archive retains original object metadata for recovery'));
insert into pg_temp.eigsti_file_results values(54,is((select count(*) from public.job_files where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc' and status='archived'),1::bigint,'Archive retains file identity and history'));
set local role authenticated;
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
insert into pg_temp.eigsti_file_results values(55,is((select count(*) from public.job_files),0::bigint,'Admin-only reads no operational files'));
insert into pg_temp.eigsti_file_results values(56,throws_ok($$select public.begin_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','99999999-9999-4999-8999-999999999999','Test.pdf','application/pdf',100)$$,'42501','File write access required','Admin-only cannot reserve file'));
set local role authenticated;
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
insert into pg_temp.eigsti_file_results values(57,is((select count(*) from public.job_files),0::bigint,'Uninvited identity reads no file metadata'));
set local role authenticated;
select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
insert into pg_temp.eigsti_file_results values(58,is((select count(*) from storage.objects where bucket_id='eigsti-job-files'),0::bigint,'Inactive PM reads no file objects'));
reset role;
update public.app_users set active=false where id='33333333-3333-4333-8333-333333333333';
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
insert into pg_temp.eigsti_file_results values(59,throws_ok($$select public.archive_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee')$$,'42501','File write access required','Live lead deactivation removes writes'));
insert into pg_temp.eigsti_file_results values(60,is((select count(*) from storage.objects where bucket_id='eigsti-job-files'),0::bigint,'Live lead deactivation removes storage reads'));
reset role;
set local role anon;
insert into pg_temp.eigsti_file_results values(61,throws_ok($$select * from public.job_files$$,'42501',null,'Anonymous metadata denied'));
insert into pg_temp.eigsti_file_results values(62,is((select count(*) from storage.objects where bucket_id='eigsti-job-files'),0::bigint,'Anonymous bucket reads denied'));
insert into pg_temp.eigsti_file_results values(63,throws_ok($$select public.begin_job_file('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','99999999-9999-4999-8999-999999999999','Test.pdf','application/pdf',100)$$,'42501',null,'Anonymous file RPC denied'));
reset role;
insert into public.job_files(job_id,filename,mime_type,byte_size,created_by,updated_by)
  select 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','SYNTHETIC Limit ' || n || '.pdf','application/pdf',1,'11111111-1111-4111-8111-111111111111','11111111-1111-4111-8111-111111111111' from generate_series(1,99) n;
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into pg_temp.eigsti_file_results values(64,throws_ok($$select public.begin_job_file('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','99999999-9999-4999-8999-999999999998','Overflow.pdf','application/pdf',1)$$,'22023','File limit reached','Pending plus ready file limit enforced'));
insert into pg_temp.eigsti_file_results values(65,is((select count(*) from public.job_files where job_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),100::bigint,'Visible file count remains bounded'));
insert into pg_temp.eigsti_file_results values(66,is((select count(*) from public.audit_events where request_id='99999999-9999-4999-8999-999999999998'),0::bigint,'Rejected reservation leaves no audit event'));
reset role;
do $validation$
declare v_failures text;
begin
  if (select count(*) from pg_temp.eigsti_file_results)<>66 then raise exception 'Incomplete file suite: expected 66 checks'; end if;
  select string_agg(result,E'\n' order by ordinal) into v_failures from pg_temp.eigsti_file_results where result not like 'ok %';
  if v_failures is not null then raise exception 'File tests failed: %',v_failures; end if;
end;
$validation$;
select * from finish();
select count(*) as checks,count(*) filter(where result not like 'ok %') as failed from pg_temp.eigsti_file_results;
rollback;
