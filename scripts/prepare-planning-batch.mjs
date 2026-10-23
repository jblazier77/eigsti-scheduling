import {readFileSync,writeFileSync} from 'node:fs';
const root=new URL('../',import.meta.url),read=path=>readFileSync(new URL(path,root),'utf8');
const name='0012_work_planning_and_materials';
const ddl=read('database/migrations/'+name+'.sql'),tests=read('database/tests/'+name+'.test.sql');
const count=(tests.match(/insert into pg_temp.eigsti_planning_results\(result\)/g)||[]).length;
if(count<40||!/^begin;$/m.test(ddl)||!/commit;\s*$/.test(ddl)||!/rollback;\s*$/.test(tests))throw new Error('Invalid planning batch boundaries or checks');
const preflight=`-- TEST PROJECT ONLY: apply once after applied 0011. Never rerun 0010/0011.
-- DDL and ${count} checks commit together. Synthetic fixtures roll back before commit.
begin;
do $preflight$
begin
 if to_regprocedure('public.save_subcontractor(uuid,uuid,jsonb)') is null or to_regprocedure('public.save_visit_card(uuid,uuid,uuid,jsonb,uuid[])') is null then raise exception 'Planning batch requires applied 0011 and 0009.'; end if;
 if to_regprocedure('public.create_job_work_with_plan(uuid,uuid,jsonb,jsonb)') is not null or exists(select 1 from information_schema.columns where table_schema='public' and table_name='work_items' and column_name='material_status') then raise exception '0012 may already be applied. Do not rerun; verify project state.'; end if;
end; $preflight$;
`;
const batch=preflight+ddl.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'')+'\nsavepoint planning_fixture_checks;\n'+tests.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')+`\nrollback to savepoint planning_fixture_checks;
release savepoint planning_fixture_checks;
commit;
select ${count}::integer as checks,0::integer as failed,'0012 applied; synthetic fixtures removed'::text as result;
`;
writeFileSync(new URL('database/batches/'+name+'.sql',root),batch);
process.stdout.write('Prepared 0012 with '+count+' SQL checks.\n');
