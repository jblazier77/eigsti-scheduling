import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
test('combined update applies ordered exact DDL once and commits only after both guarded suites remove fixtures',()=>{
 const batch=read('database/batches/0010_0011_combined.sql');
 assert.equal((batch.match(/^begin;$/gm)||[]).length,1);assert.equal((batch.match(/^commit;$/gm)||[]).length,1);
 assert.ok(batch.indexOf('Combined update stopped:')<batch.indexOf('create table public.work_follow_ups'));
 let previous=0;
 for(const[i,name]of ['0010_completion_and_returns','0011_job_tags_and_trades'].entries()){
  const ddl=read('database/migrations/'+name+'.sql').replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'');
  const pos=batch.indexOf(ddl);assert.ok(pos>previous);previous=pos;
  const sql=read('database/tests/'+name+'.test.sql'),body=sql.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'');assert.ok(batch.includes(body));
  const guard=batch.indexOf(i?'Incomplete tag checks: expected 51':'Incomplete completion checks: expected 60');
  const cleanup=batch.indexOf('rollback to savepoint eigsti_combined_checks_'+i+';');assert.ok(cleanup>guard);assert.ok(batch.lastIndexOf('\ncommit;')>cleanup);
 }
 assert.equal((batch.match(/insert into pg_temp.eigsti_(?:visit|tag)_results\(result\)/g)||[]).length,111);
 assert.ok(batch.endsWith("select 111::integer as checks,0::integer as failed,'0010 and 0011 applied; synthetic fixtures removed'::text as result;\n"));
});
