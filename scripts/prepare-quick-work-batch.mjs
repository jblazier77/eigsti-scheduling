import {readFileSync,writeFileSync} from 'node:fs';
const root=new URL('../',import.meta.url),read=p=>readFileSync(new URL(p,root),'utf8');
const name='0013_quick_work',ddl=read('database/migrations/'+name+'.sql'),checks=read('database/tests/'+name+'.test.sql');
const count=(checks.match(/insert into pg_temp.eigsti_quick_results\(result\)/g)||[]).length;
if(count!==33||!/^begin;$/m.test(ddl)||!/commit;\s*$/.test(ddl)||!/rollback;\s*$/.test(checks))throw new Error('Unexpected quick-work checks or boundaries');
const batch=`-- ISOLATED TEST PROJECT ONLY. Apply 0013 once after applied 0012.
-- 33 checks; synthetic fixtures roll back before commit. Never rerun older bundles.
begin;
do $preflight$
begin
 if to_regprocedure('public.create_job_work_with_plan(uuid,uuid,jsonb,jsonb)') is null or to_regprocedure('public.save_work_materials(uuid,uuid,jsonb)') is null then raise exception 'Quick-work batch requires applied 0012.'; end if;
 if to_regprocedure('public.create_quick_work(uuid,uuid,jsonb,jsonb,integer,jsonb)') is not null or exists(select 1 from information_schema.columns where table_schema='public' and table_name='work_items' and column_name='default_helpers') then raise exception '0013 may already be applied. Do not rerun; verify project state.'; end if;
end; $preflight$;
`+ddl.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'')+'\nsavepoint quick_work_fixture_checks;\n'+checks.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')+`
rollback to savepoint quick_work_fixture_checks;
release savepoint quick_work_fixture_checks;
commit;
select ${count}::integer as checks,0::integer as failed,'0013 applied; synthetic fixtures removed'::text as result;
`;
writeFileSync(new URL('database/batches/'+name+'.sql',root),batch);process.stdout.write('Prepared 0013 with '+count+' SQL checks.\n');
