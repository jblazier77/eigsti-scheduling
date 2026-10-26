import {readFileSync,writeFileSync} from 'node:fs';
const root=new URL('../',import.meta.url),name='0019_first_save_helpers',read=p=>readFileSync(new URL(p,root),'utf8'),ddl=read('database/migrations/'+name+'.sql'),checks=read('database/tests/'+name+'.test.sql');
const count=(checks.match(/insert into pg_temp.eigsti_first_results\(result\)/g)||[]).length;
if(count<20||checks.includes('language sql as $select')||!/^begin;$/m.test(ddl)||!/commit;\s*$/.test(ddl)||!/rollback;\s*$/.test(checks))throw new Error('Unexpected first-save helper bundle');
const batch=`-- Apply ONCE after applied 0018. All fictional fixtures roll back before commit.
begin;
do $preflight$ begin
 if to_regprocedure('public.save_work_setup(uuid,uuid,jsonb,jsonb,jsonb,jsonb)') is null then raise exception 'First-save helpers require applied 0018.'; end if;
 if to_regprocedure('public.planning_staff(uuid)') is not null then raise exception '0019 may already be applied. Do not rerun; verify state.'; end if;
end; $preflight$;
`+ddl.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'')+'\nsavepoint first_helpers_checks;\n'+checks.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')+`
rollback to savepoint first_helpers_checks;
release savepoint first_helpers_checks;
commit;
select ${count}::integer as checks,0::integer as failed,'0019 applied; synthetic fixtures removed'::text as result;
`;
writeFileSync(new URL('database/batches/'+name+'.sql',root),batch);console.log('Prepared 0019 with '+count+' checks.');
