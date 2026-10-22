import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
test('consolidated SQL has one commit after all 60 checks and fixture rollback, with exact migration/test bodies',()=>{
 const migration=read('database/migrations/0010_completion_and_returns.sql');
 const tests=read('database/tests/0010_completion_and_returns.test.sql');
 const batch=read('database/batches/0010_completion_and_returns.sql');
 assert.equal((batch.match(/^begin;$/gm)||[]).length,1);assert.equal((batch.match(/^commit;$/gm)||[]).length,1);
 assert.ok(batch.includes(migration.replace(/commit;\s*$/,'')));
 assert.ok(batch.includes(tests.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')));
 assert.equal((tests.match(/insert into pg_temp.eigsti_visit_results\(result\)/g)||[]).length,60);
 const guard=batch.indexOf('Incomplete completion checks: expected 60'),cleanup=batch.indexOf('rollback to savepoint eigsti_completion_acceptance;'),commit=batch.lastIndexOf('\ncommit;');
 assert.ok(guard>0&&cleanup>guard&&commit>cleanup);assert.ok(batch.lastIndexOf('select 60::integer as checks')>commit);
});
