import {readFileSync,writeFileSync} from 'node:fs';
const root=new URL('../',import.meta.url),name='0018_unified_work_editor';
const read=p=>readFileSync(new URL(p,root),'utf8'),ddl=read('database/migrations/'+name+'.sql'),checks=read('database/tests/'+name+'.test.sql');
const count=(checks.match(/insert into pg_temp.eigsti_setup_results\(result\)/g)||[]).length;
if(checks.includes('language sql as $select')||!/^create function pg_temp\.setup\([^\n]+language sql as \$helper\$[^\n]+;\$helper\$;$/m.test(checks)||!/^create function pg_temp\.setup_dates\([^\n]+language sql as \$helper\$[^\n]+;\$helper\$;$/m.test(checks))throw new Error('Invalid SQL helper delimiters');
if(count<20||!/^begin;$/m.test(ddl)||!/commit;\s*$/.test(ddl)||!/rollback;\s*$/.test(checks))throw new Error('Unexpected unified work boundaries');
const batch=`-- Apply ONCE after 0017 in the fictional-data project. Synthetic fixtures roll back.
begin;
do $preflight$ begin
 if to_regprocedure('public.save_work_details(uuid,uuid,jsonb)') is null then raise exception 'Unified work editor requires applied 0017.'; end if;
 if to_regprocedure('public.save_work_setup(uuid,uuid,jsonb,jsonb,jsonb,jsonb)') is not null then raise exception '0018 may already be applied. Do not rerun; verify state.'; end if;
end; $preflight$;
`+ddl.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'')+'\nsavepoint setup_fixture_checks;\n'+checks.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')+`
rollback to savepoint setup_fixture_checks;
release savepoint setup_fixture_checks;
commit;
select ${count}::integer as checks,0::integer as failed,'0018 applied; synthetic fixtures removed'::text as result;
`;
writeFileSync(new URL('database/batches/'+name+'.sql',root),batch);console.log('Prepared 0018 with '+count+' guarded SQL checks.');
