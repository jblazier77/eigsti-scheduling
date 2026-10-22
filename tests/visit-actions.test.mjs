import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
import * as visits from '../src/domain/visits.ts';
import { AppError } from '../src/domain/access.ts';
const id = '33333333-3333-4333-8333-333333333333';
function fixture(role = 'lead', failure) {
  const calls = [], exports = {};
  const saved = { id, job_id: id };
  const dependencies = {
    'next/cache': { revalidatePath: path => calls.push(['refresh', path]) },
    '../lib/visit-session': { visitSession: async () => ({ actor: { id, active: true, roles: [role] }, gateway: {
      saveVisit: async (...args) => { calls.push(['save', ...args]); if (failure) throw new AppError(failure, 409, 'Not confirmed'); return saved; },
      staffVisit: async (...args) => { calls.push(['staff', ...args]); if (failure) throw new AppError(failure, 409, 'Not confirmed'); return saved; }
      ,saveVisitCard: async (...args) => { calls.push(['card', ...args]); if (failure) throw new AppError(failure,409,'Not confirmed'); return saved; }
    } }) }, '../domain/visits.ts': visits, '../domain/access.ts': { AppError }
  };
  const source = stripTypeScriptTypes(readFileSync(new URL('../src/app/visit-actions.ts', import.meta.url), 'utf8')).replace(/^import \{([^}]+)\} from '([^']+)';$/gm, 'const {$1} = require(\'$2\');').replace(/export async function (\w+)/g, 'exports.$1 = async function $1');
  runInNewContext(source, { exports, require: name => dependencies[name] });
  const form = new FormData();
  for (const [key, value] of Object.entries({ operation: 'save', workId: id, requestId: id, start_date: '2026-10-26', end_date: '2026-10-26', slot: 'day', coordinator_id: id, required_helpers: '1', certainty: 'tentative' })) form.set(key, value);
  return { form, calls, run: () => exports.saveVisitAction({ message: '' }, form) };
}
test('visit actions authenticate, send only selected changes and refresh after confirmed success', async () => {
  const f = fixture(); f.form.set('visitId', id); f.form.set('fields', '["certainty"]'); f.form.set('certainty', 'confirmed');
  assert.equal((await f.run()).visit.id, id);
  assert.deepEqual(JSON.parse(JSON.stringify(f.calls[0])), ['save', id, id, id, { certainty: 'confirmed' }]); assert.equal(f.calls.length, 3);
  const helper = fixture('helper'); assert.equal((await helper.run()).visit, undefined); assert.equal(helper.calls.length, 0);
  const invalid = fixture(); invalid.form.set('slot', 'unknown'); assert.equal((await invalid.run()).visit, undefined); assert.equal(invalid.calls.length, 0);
});
test('combined visit action makes one atomic RPC with narrow fields and optional roster', async () => {
  const f=fixture('pm'); f.form.set('operation','card'); f.form.set('visitId',id); f.form.set('fields','["required_helpers"]'); f.form.set('helpersMode','changed'); f.form.append('helper',id);
  assert.equal((await f.run()).visit.id,id);
  assert.deepEqual(JSON.parse(JSON.stringify(f.calls)),[['card',id,id,id,{required_helpers:1},[id]],['refresh','/schedule'],['refresh','/jobs/'+id]]);
  const narrow=fixture('pm'); narrow.form.set('operation','card'); narrow.form.set('visitId',id); narrow.form.set('fields','["certainty"]'); narrow.form.set('helpersMode','unchanged');
  await narrow.run(); assert.equal(narrow.calls[0][5],null);
  const helper=fixture('helper'); helper.form.set('operation','card'); assert.equal((await helper.run()).visit,undefined); assert.equal(helper.calls.length,0);
});
test('combined save conflict and lost response never refresh; retry repeats whole payload', async () => {
  for (const failure of ['staff_conflict','connection_failed']) {
    const f=fixture('pm',failure); f.form.set('operation','card'); f.form.set('visitId',id); f.form.set('fields','["required_helpers"]'); f.form.set('helpersMode','changed'); f.form.append('helper',id);
    const result=await f.run(); assert.equal(result.visit,undefined); assert.equal(result.uncertain,failure==='connection_failed'); assert.equal(f.calls.length,1);
    await f.run(); assert.deepEqual(f.calls[0],f.calls[1]);
  }
});
test('staff conflicts never revalidate; lost responses retain stable retry identity', async () => {
  for (const failure of ['staff_conflict', 'connection_failed']) {
    const f = fixture('pm', failure); f.form.set('operation', 'staff'); f.form.set('visitId', id); f.form.append('helper', id);
    const result = await f.run(); assert.equal(result.uncertain, failure === 'connection_failed'); assert.equal(result.visit, undefined); assert.equal(f.calls.length, 1);
    await f.run(); assert.deepEqual(f.calls[0], f.calls[1]);
  }
});
