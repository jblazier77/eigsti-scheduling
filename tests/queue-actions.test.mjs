import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
import { AppError } from '../src/domain/access.ts';
import * as queues from '../src/domain/queues.ts';

const leadId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const workId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const requestId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
function fixture({ role = 'lead', fail = null } = {}) {
  const calls = [];
  const queue = { lead_id: leadId, lead_name: 'Test Lead', revision: 2, items: [] };
  const dependencies = {
    'next/cache': { revalidatePath: path => calls.push(['refresh', path]) },
    '../lib/queue-session': { queueSession: async () => ({ actor: { id: leadId, active: true, roles: [role] }, gateway: {
      saveQueue: async (...args) => { calls.push(['save', ...args]); if (fail) throw new AppError(fail, 409, 'Not confirmed.'); return queue; }
    } }) },
    '../domain/queues.ts': queues,
    '../domain/access.ts': { AppError }
  };
  const exports = {};
  const source = stripTypeScriptTypes(readFileSync(new URL('../src/app/queue-actions.ts', import.meta.url), 'utf8'))
    .replace(/^import \{([^}]+)\} from '([^']+)';$/gm, 'const {$1} = require(\'$2\');')
    .replace(/export async function (\w+)/g, 'exports.$1 = async function $1');
  runInNewContext(source, { exports, require: name => { assert(name in dependencies); return dependencies[name]; } });
  const form = new FormData(); form.set('leadId', leadId); form.set('requestId', requestId); form.set('order', JSON.stringify([workId]));
  return { calls, form, run: () => exports.saveQueueAction({ message: '' }, form) };
}

test('queue action refreshes only after one successful scoped save; helpers and invalid inputs never write', async () => {
  const f = fixture(); assert.equal((await f.run()).queue.revision, 2);
  assert.deepEqual(JSON.parse(JSON.stringify(f.calls)), [['save', leadId, requestId, [workId]], ['refresh', '/queue']]);
  const helper = fixture({ role: 'helper' }); assert.equal((await helper.run()).queue, undefined); assert.equal(helper.calls.length, 0);
  const invalid = fixture(); invalid.form.set('order', 'not-json'); assert.equal((await invalid.run()).queue, undefined); assert.equal(invalid.calls.length, 0);
});

test('membership changes require reload; interrupted saves retain uncertain retry without a success refresh', async () => {
  for (const code of ['queue_membership_changed', 'connection_failed']) {
    const f = fixture({ fail: code }); const result = await f.run();
    assert.equal(result.queue, undefined); assert.equal(result.membershipChanged, code === 'queue_membership_changed');
    assert.equal(result.uncertain, code === 'connection_failed'); assert.equal(f.calls.length, 1);
  }
});
