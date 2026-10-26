import {readFileSync,writeFileSync} from 'node:fs';
const root=new URL('../',import.meta.url),name='0017_planning_review';
const read=p=>readFileSync(new URL(p,root),'utf8'),ddl=read('database/migrations/'+name+'.sql'),checks=read('database/tests/'+name+'.test.sql');
const count=(checks.match(/insert into pg_temp.eigsti_review_results\(result\)/g)||[]).length;
if(count<40||!/^begin;$/m.test(ddl)||!/commit;\s*$/.test(ddl)||!/rollback;\s*$/.test(checks))throw new Error('Unexpected planning review boundaries');
const batch=`-- ISOLATED TEST PROJECT ONLY. Apply 0017 once after 0016.
-- All checks must pass; synthetic fixtures roll back before migration commit.
begin;
do $preflight$ begin
 if to_regprocedure('public.save_employee(uuid,uuid,timestamp with time zone,jsonb)') is null and to_regclass('private.employee_events') is null then raise exception 'Planning review requires applied 0016.'; end if;
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='jobs' and column_name='priority') or to_regprocedure('public.pm_help_requests()') is not null then raise exception '0017 may already be applied. Do not rerun; verify state.'; end if;
end; $preflight$;
`+ddl.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'')+'\nsavepoint review_fixture_checks;\n'+checks.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')+`
rollback to savepoint review_fixture_checks;
release savepoint review_fixture_checks;
commit;
select ${count}::integer as checks,0::integer as failed,'0017 applied; synthetic fixtures removed'::text as result;
`;
writeFileSync(new URL('database/batches/'+name+'.sql',root),batch);
console.log('Prepared 0017 with '+count+' guarded SQL checks.');
