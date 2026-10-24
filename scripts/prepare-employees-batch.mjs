import {readFileSync,writeFileSync} from 'node:fs';
const root=new URL('../',import.meta.url),read=p=>readFileSync(new URL(p,root),'utf8');
const name='0016_employee_management',ddl=read('database/migrations/'+name+'.sql'),checks=read('database/tests/'+name+'.test.sql');
const count=(checks.match(/insert into pg_temp.eigsti_employee_results\(result\)/g)||[]).length;
if(count<30||!/^begin;$/m.test(ddl)||!/commit;\s*$/.test(ddl)||!/rollback;\s*$/.test(checks))throw new Error('Unexpected archive checks or boundaries');
const batch=`-- ISOLATED TEST PROJECT ONLY. Apply 0016 once after applied 0015.
-- ${count} guarded checks; fixtures roll back before schema commit.
begin;
do $preflight$
begin
 if to_regprocedure('public.set_job_archive(uuid,uuid,text,text)') is null then raise exception 'Employee batch requires applied 0015.'; end if;
 if to_regprocedure('public.save_employee(uuid,uuid,timestamptz,jsonb)') is not null or to_regclass('private.employee_events') is not null then raise exception '0016 may already be applied. Do not rerun; verify project state.'; end if;
end; $preflight$;
`+ddl.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'')+'\nsavepoint employee_fixture_checks;\n'+checks.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')+`
rollback to savepoint employee_fixture_checks;
release savepoint employee_fixture_checks;
commit;
select ${count}::integer as checks,0::integer as failed,'0016 applied; synthetic fixtures removed'::text as result;
`;
writeFileSync(new URL('database/batches/'+name+'.sql',root),batch);process.stdout.write('Prepared 0016 with '+count+' SQL checks.\n');
