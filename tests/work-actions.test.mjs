import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
import { AppError } from '../src/domain/access.ts';
import * as work from '../src/domain/work.ts';

const jobId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const requestId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const workId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
function actions({ roles = ['pm'], fail = false } = {}) {
  const calls = [];
  const dependencies = {
    'next/cache': { revalidatePath: path => calls.push(['refresh', path]) },
    '../lib/work-session': { workSession: async () => ({ actor: { id: jobId, roles, active: true }, gateway: {
      createWork: async (...args) => { calls.push(['create', ...args]); if (fail) throw new AppError('connection_failed', 503, 'Unconfirmed.'); return { id: workId }; },
      updateWork: async (...args) => { calls.push(['update', ...args]); return { id: workId }; }
    } }) },
    '../domain/work.ts': work,
    '../domain/access.ts': { AppError }
  };
  const exports = {};
  const compiled = stripTypeScriptTypes(readFileSync(new URL('../src/app/work-actions.ts', import.meta.url), 'utf8'))
    .replace(/^import \{([^}]+)\} from '([^']+)';$/gm, 'const {$1} = require(\'$2\');')
    .replace(/export async function (\w+)/g, 'exports.$1 = async function $1');
  runInNewContext(compiled, { exports, require: name => { assert(name in dependencies); return dependencies[name]; } });
  const form = new FormData(); form.set('jobId', jobId); form.set('requestId', requestId); form.set('workId', workId);
  form.set('values', JSON.stringify({ description: 'Framing', responsible_lead: null }));
  return { calls, form, ...exports };
}

test('work creation preserves retry identity; uncertain results do not invalidate data or claim success', async () => {
  const f = actions();
  assert.equal((await f.createWorkAction({ message: '' }, f.form)).jobId, jobId);
  assert.deepEqual(f.calls, [['create', jobId, requestId, { description: 'Framing', responsible_lead: null }], ['refresh', '/jobs'], ['refresh', '/jobs/' + jobId]]);
  const failed = actions({ fail: true });
  const result = await failed.createWorkAction({ message: '' }, failed.form);
  assert.equal(result.uncertain, true); assert.equal(result.jobId, undefined);
  assert.equal(failed.calls.length, 1);
});

test('work actions reject helper forgery and malformed payload; updates contain only changed fields', async () => {
  const helper = actions({ roles: ['helper'] });
  await helper.updateWorkAction({ message: '' }, helper.form);
  assert.equal(helper.calls.length, 0);
  const f = actions(); f.form.set('values', '{invalid');
  assert.equal((await f.createWorkAction({ message: '' }, f.form)).jobId, undefined); assert.equal(f.calls.length, 0);
  f.form.set('values', JSON.stringify({ responsible_lead: null }));
  await f.updateWorkAction({ message: '' }, f.form);
  assert.deepEqual(f.calls[0], ['update', jobId, workId, { responsible_lead: null }]);
});
