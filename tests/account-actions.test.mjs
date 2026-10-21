import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
import { AppError } from '../src/domain/access.ts';

function fixture({ session = true, fail = false } = {}) {
  const calls = [];
  const prefix = 'sb-test-project-auth-token';
  const dependencies = {
    'next/navigation': { redirect: path => { calls.push(['redirect', path]); throw new Error('FRAMEWORK_REDIRECT'); } },
    'next/headers': { cookies: async () => ({ getAll: () => [{ name: prefix }, { name: prefix + '.0' }, { name: prefix + '.1' }, { name: 'other-cookie' }], delete: name => calls.push(['delete', name]) }) },
    '../lib/config': { appConfig: () => ({}) },
    '../lib/supabase-server': { authClient: async () => ({ auth: {
      getSession: async () => ({ data: { session: session ? { access_token: 'existing-token' } : null } }),
      signOut: async () => { calls.push(['logout']); throw new Error('Offline cleanup'); }
    } }) },
    '../domain/access.ts': { AppError },
    '../server/password-change.ts': { changeOwnPassword: async (_config, ...args) => { calls.push(['change', ...args]); if (fail) throw new AppError('password_change_uncertain', 503, 'Check your new password.'); } }
  };
  const exports = {};
  const source = stripTypeScriptTypes(readFileSync(new URL('../src/app/account-actions.ts', import.meta.url), 'utf8'))
    .replace(/^import \{([^}]+)\} from '([^']+)';$/gm, 'const {$1} = require(\'$2\');')
    .replace(/export async function (\w+)/g, 'exports.$1 = async function $1');
  runInNewContext(source, { exports, process: { env: { EIGSTI_EXPECTED_PROJECT_REF: 'test-project' } }, require: name => { assert(name in dependencies); return dependencies[name]; } });
  const form = new FormData();
  form.set('currentPassword', 'old test password'); form.set('newPassword', 'new test password'); form.set('confirmPassword', 'new test password');
  return { calls, run: () => exports.changePasswordAction({ message: '' }, form) };
}

test('confirmed change clears only project cookies even if logout fails, then redirects outside catch', async () => {
  const f = fixture();
  await assert.rejects(f.run(), /FRAMEWORK_REDIRECT/);
  assert.deepEqual(f.calls, [
    ['change', 'existing-token', 'old test password', 'new test password', 'new test password'],
    ['logout'], ['delete', 'sb-test-project-auth-token'], ['delete', 'sb-test-project-auth-token.0'], ['delete', 'sb-test-project-auth-token.1'],
    ['redirect', '/login?reason=password-changed']
  ]);
});

test('expired session never changes credentials; uncertain result returns no submitted passwords or tokens', async () => {
  const expired = fixture({ session: false });
  assert.match((await expired.run()).message, /expired/);
  assert.deepEqual(expired.calls, []);
  const uncertain = fixture({ fail: true });
  const result = await uncertain.run();
  assert.equal(result.uncertain, true);
  assert.equal(result.message, 'Check your new password.');
  assert.deepEqual(Object.keys(result).sort(), ['message', 'uncertain']);
  assert(!uncertain.calls.some(c => ['logout', 'delete', 'redirect'].includes(c[0])));
});
