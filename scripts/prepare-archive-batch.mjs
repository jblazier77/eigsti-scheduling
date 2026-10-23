import {readFileSync,writeFileSync} from 'node:fs';
const root=new URL('../',import.meta.url),read=p=>readFileSync(new URL(p,root),'utf8');
const name='0015_job_archive',ddl=read('database/migrations/'+name+'.sql'),checks=read('database/tests/'+name+'.test.sql');
const count=(checks.match(/insert into pg_temp.eigsti_archive_results\(result\)/g)||[]).length;
if(count<30||!/^begin;$/m.test(ddl)||!/commit;\s*$/.test(ddl)||!/rollback;\s*$/.test(checks))throw new Error('Unexpected archive checks or boundaries');
const batch=`-- ISOLATED TEST PROJECT ONLY. Apply 0015 once after applied 0014.
-- ${count} guarded checks; fixtures roll back before schema commit.
begin;
do $preflight$
begin
 if to_regprocedure('public.list_contact_commitments(date,date,boolean)') is null then raise exception 'Archive batch requires applied 0014.'; end if;
 if to_regprocedure('public.set_job_archive(uuid,uuid,text,text)') is not null or to_regclass('private.job_archive_events') is not null then raise exception '0015 may already be applied. Do not rerun; verify project state.'; end if;
end; $preflight$;
`+ddl.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'')+'\nsavepoint archive_fixture_checks;\n'+checks.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')+`
rollback to savepoint archive_fixture_checks;
release savepoint archive_fixture_checks;
commit;
select ${count}::integer as checks,0::integer as failed,'0015 applied; synthetic fixtures removed'::text as result;
`;
writeFileSync(new URL('database/batches/'+name+'.sql',root),batch);process.stdout.write('Prepared 0015 with '+count+' SQL checks.\n');
