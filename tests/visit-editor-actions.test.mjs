import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
import { randomUUID } from 'node:crypto';
import * as visits from '../src/domain/visits.ts';
import { AppError } from '../src/domain/access.ts';
const id = '33333333-3333-4333-8333-333333333333';
function fixture({ role = 'lead', coordinator = id, state = 'planned' } = {}) {
  const calls = [], exports = {};
  const dependencies = {
    'node:crypto': { randomUUID },
    '../lib/visit-session': { visitSession: async () => ({ actor: { id, active: true, roles: [role] }, gateway: {
      getVisit: async visitId => { calls.push('visit'); return { id: visitId, coordinator_id: coordinator, state }; },
      staffOptions: async () => { calls.push('staff'); return [{ id, name: 'Test Person', busy: false }]; },
      listLeads: async () => { calls.push('leads'); return [{ id, display_name: 'Test Lead' }]; }
    } }) }, '../domain/visits.ts': visits, '../domain/access.ts': { AppError }
  };
  const source = stripTypeScriptTypes(readFileSync(new URL('../src/app/visit-editor-actions.ts', import.meta.url), 'utf8')).replace(/^import \{([^}]+)\} from '([^']+)';$/gm, 'const {$1} = require(\'$2\');').replace(/export async function (\w+)/g, 'exports.$1 = async function $1');
  runInNewContext(source, { exports, require: name => dependencies[name] });
  return { calls, run: visitId => exports.loadVisitEditorAction(visitId ?? id) };
}
test('inline editor loads only authorized live data, with independent fresh request identities', async () => {
  const lead = fixture(); const result = await lead.run(); assert.equal(result.data.actorId, id);
  assert.deepEqual(lead.calls, ['visit', 'staff']); assert.equal(result.data.leads.length, 0);
  assert.equal(new Set(Object.values(result.data.requests)).size, 3);
  const next = await lead.run(); assert.notEqual(result.data.requests.dates, next.data.requests.dates);
  const pm = fixture({ role: 'pm' }); assert.equal((await pm.run()).data.pm, true); assert.ok(pm.calls.includes('leads'));
});
test('helper, unrelated lead, stale cancelled visit and malformed ID cannot load staffing directory', async () => {
  for (const options of [{ role: 'helper' }, { role: 'admin' }, { coordinator: '44444444-4444-4444-8444-444444444444' }, { state: 'cancelled' }]) {
    const f = fixture(options); const result = await f.run(); assert.equal(result.data, undefined); assert.ok(result.message); assert.equal(f.calls.includes('staff'), false); assert.equal(f.calls.includes('leads'), false);
  }
  const invalid = fixture(); assert.equal((await invalid.run('bad')).data, undefined); assert.equal(invalid.calls.length, 0);
});
