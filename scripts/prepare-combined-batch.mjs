import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
const root=new URL('../',import.meta.url),read=p=>readFileSync(new URL(p,root),'utf8');
const migrations=['0010_completion_and_returns','0011_job_tags_and_trades'];
let batch=`-- COMBINED TEST-PROJECT UPDATE. Requires applied 0001-0009 and UNAPPLIED 0010/0011.
-- Run ONCE. All DDL and 111 checks commit together; synthetic fixtures are removed.
begin;
do $preflight$
begin
 if to_regclass('public.work_follow_ups') is not null or to_regclass('public.subcontractors') is not null then
  raise exception 'Combined update stopped: 0010 or 0011 may already be applied. Do not rerun; verify project state.';
 end if;
 if to_regprocedure('public.save_visit_card(uuid,uuid,uuid,jsonb,uuid[])') is null then
  raise exception 'Combined update requires the applied 0009 visit-card checkpoint.';
 end if;
end; $preflight$;
`;
for(const name of migrations){
 const sql=read('database/migrations/'+name+'.sql');
 if(!/^begin;$/m.test(sql)||!/commit;\s*$/.test(sql))throw new Error('Unexpected migration boundaries: '+name);
 batch+='\n-- Migration '+name+'\n'+sql.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'');
}
for(const [i,name]of migrations.entries()){
 const sql=read('database/tests/'+name+'.test.sql');
 const count=(sql.match(/insert into pg_temp.eigsti_(?:visit|tag)_results\(result\)/g)||[]).length;
 if(count!==(i===0?60:51)||!/rollback;\s*$/.test(sql))throw new Error('Unexpected check count or boundary: '+name);
 batch+=`\nsavepoint eigsti_combined_checks_${i};\n`+sql.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')+`\nrollback to savepoint eigsti_combined_checks_${i};\nrelease savepoint eigsti_combined_checks_${i};\n`;
}
batch+="\ncommit;\nselect 111::integer as checks,0::integer as failed,'0010 and 0011 applied; synthetic fixtures removed'::text as result;\n";
mkdirSync(new URL('database/batches/',root),{recursive:true});
writeFileSync(new URL('database/batches/0010_0011_combined.sql',root),batch);
process.stdout.write('Prepared combined 0010/0011 update with 111 checks.\n');
