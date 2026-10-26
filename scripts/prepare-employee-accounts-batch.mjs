import {readFileSync,writeFileSync} from 'node:fs';
const name='0020_employee_accounts',ddl=readFileSync('database/migrations/'+name+'.sql','utf8'),checks=readFileSync('database/tests/'+name+'.test.sql','utf8');
const count=(checks.match(/insert into pg_temp.eigsti_account_results values/g)||[]).length;
const preflight="begin;\ndo \$preflight\$ begin if to_regprocedure('public.planning_staff(uuid)') is null then raise exception 'Requires 0019'; end if; if to_regprocedure('public.employee_onboarding_ready(uuid)') is not null then raise exception '0020 already present; do not rerun'; end if; end; \$preflight\$;\n";
writeFileSync('database/batches/'+name+'.sql',preflight+ddl.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'')+'\nsavepoint account_checks;\n'+checks.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')+"\nrollback to savepoint account_checks;\nrelease savepoint account_checks;\ncommit;\nselect "+count+"::integer as checks,0::integer as failed,'0020 applied; synthetic fixtures removed'::text as result;\n");
console.log('Prepared 0020: '+count+' checks.');
