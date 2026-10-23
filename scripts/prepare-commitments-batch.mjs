import {readFileSync,writeFileSync} from 'node:fs';
const root=new URL('../',import.meta.url),read=p=>readFileSync(new URL(p,root),'utf8');
const name='0014_subcontractor_commitments',ddl=read('database/migrations/'+name+'.sql'),checks=read('database/tests/'+name+'.test.sql');
const count=(checks.match(/insert into pg_temp.eigsti_commitment_results\(result\)/g)||[]).length;
if(count<45||!/^begin;$/m.test(ddl)||!/commit;\s*$/.test(ddl)||!/rollback;\s*$/.test(checks))throw new Error('Unexpected commitment checks or boundaries');
const batch=`-- ISOLATED TEST PROJECT ONLY. Apply 0014 once after applied 0013.
-- ${count} checks; synthetic fixtures roll back before commit. Never rerun older bundles.
begin;
do $preflight$
begin
 if to_regprocedure('public.create_quick_work(uuid,uuid,jsonb,jsonb,integer,jsonb)') is null then raise exception 'Commitments batch requires applied 0013.'; end if;
 if to_regclass('public.contact_commitments') is not null or to_regprocedure('public.list_contact_commitments(date,date,boolean)') is not null then raise exception '0014 may already be applied. Do not rerun; verify project state.'; end if;
end; $preflight$;
`+ddl.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'')+'\nsavepoint commitment_fixture_checks;\n'+checks.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')+`
rollback to savepoint commitment_fixture_checks;
release savepoint commitment_fixture_checks;
commit;
select ${count}::integer as checks,0::integer as failed,'0014 applied; synthetic fixtures removed'::text as result;
`;
writeFileSync(new URL('database/batches/'+name+'.sql',root),batch);process.stdout.write('Prepared 0014 with '+count+' SQL checks.\n');
