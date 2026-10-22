import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { stripTypeScriptTypes } from 'node:module';
import { AppError } from '../src/domain/access.ts';
import * as contacts from '../src/domain/contacts.ts';

const jobId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const contactId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

// Execute the real Server Action with framework/session effects replaced;
// the redirect must terminate success rather than returning a stale edit page.
function actions({ roles = ['pm'], fail = false } = {}) {
  const calls = [];
  class Gateway {
    async getActor() { return { id: jobId, active: true, roles }; }
    async createContact(actualJob, requestId, values) {
      calls.push(['create', actualJob, requestId, values]);
      if (fail) throw new AppError('not_allowed', 403, 'Job access revoked.');
      return { id: contactId };
    }
    async archiveContact(actualJob, actualContact) {
      calls.push(['archive', actualJob, actualContact]);
      if (fail) throw new AppError('connection_failed', 503, 'Removal not confirmed.');
      return { id: actualContact };
    }
  }
  const exports = {};
  const dependencies = {
    'next/cache': { revalidatePath: path => calls.push(['revalidate', path]) },
    'next/navigation': { RedirectType: { replace: 'replace' }, redirect: (path, type) => { calls.push(['redirect', path, type]); throw new Error('FRAMEWORK_REDIRECT'); } },
    '../lib/supabase-server': { authClient: async () => ({ auth: { getSession: async () => ({ data: { session: { access_token: 'test-token' } } }) } }) },
    '../lib/config': { appConfig: () => ({}) },
    '../server/supabase.ts': { SupabaseSession: Gateway },
    '../domain/access.ts': { AppError, requirePm: actor => { if (!actor.active || !actor.roles.includes('pm')) throw new AppError('not_allowed', 403, 'PM account required.'); } },
    '../domain/contacts.ts': contacts
  };
  const source = readFileSync(new URL('../src/app/contact-actions.ts', import.meta.url), 'utf8');
  const compiled = stripTypeScriptTypes(source)
    .replace(/^import \{([^}]+)\} from '([^']+)';$/gm, 'const {$1} = require(\'$2\');')
    .replace(/export async function (\w+)/g, 'exports.$1 = async function $1');
  runInNewContext(compiled, { exports, require: name => { assert(name in dependencies, 'Unexpected dependency: ' + name); return dependencies[name]; } });
  const form = new FormData(); form.set('jobId', jobId); form.set('contactId', contactId);
  return { action: exports.archiveContactAction, createAction: exports.createContactAction, calls, form };
}

test('successful removal invalidates job data then redirects directly away from archived edit page', async () => {
  const { action, calls, form } = actions();
  await assert.rejects(action({ message: '' }, form), /FRAMEWORK_REDIRECT/);
  assert.deepEqual(calls, [
    ['archive', jobId, contactId],
    ['revalidate', '/jobs/' + jobId],
    ['revalidate', '/jobs/' + jobId + '/contacts'],
    ['redirect', '/jobs/' + jobId, 'replace']
  ]);
});

test('unconfirmed removal retains an error state without invalidating or redirecting', async () => {
  const { action, calls, form } = actions({ fail: true });
  const result = await action({ message: '' }, form);
  assert.equal(result.uncertain, true);
  assert.equal(result.message, 'Removal not confirmed.');
  assert.deepEqual(calls, [['archive', jobId, contactId]]);
});

test('helper cannot trigger a removal or successful navigation by forging the Server Action form', async () => {
  const { action, calls, form } = actions({ roles: ['helper'] });
  const result = await action({ message: '' }, form);
  assert.equal(result.message, 'PM account required.');
  assert.equal(result.uncertain, false);
  assert.deepEqual(calls, []);
});

test('lead contact creation reaches job-scoped gateway and returns confirmed navigation only after success', async () => {
  const f = actions({ roles: ['lead'] });
  const values = { ...contacts.emptyContact, name: 'SYNTHETIC Site Contact' };
  f.form.set('requestId', contactId); f.form.set('values', JSON.stringify(values));
  assert.equal((await f.createAction({ message: '' }, f.form)).jobId, jobId);
  assert.deepEqual(f.calls, [['create', jobId, contactId, values], ['revalidate', '/jobs/' + jobId], ['revalidate', '/jobs/' + jobId + '/contacts']]);
});

test('helper contact forgery is stopped before transport and revoked lead access never reports a saved result', async () => {
  for (const roles of [['helper'], ['lead']]) {
    const f = actions({ roles, fail: true });
    f.form.set('requestId', contactId); f.form.set('values', JSON.stringify({ ...contacts.emptyContact, name: 'Test' }));
    const result = await f.createAction({ message: '' }, f.form);
    assert.equal(result.jobId, undefined); assert.equal(result.uncertain, false);
    assert(!f.calls.some(call => call[0] === 'revalidate'));
    assert.equal(f.calls.length, roles[0] === 'helper' ? 0 : 1);
  }
});
