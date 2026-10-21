import test from 'node:test';
import assert from 'node:assert/strict';
import { changeOwnPassword, validatePasswordChange } from '../src/server/password-change.ts';

const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const otherId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const config = { url: 'https://synthetic-project.supabase.co', publishableKey: 'sb_publishable_test', environment: 'test' };
const current = 'old test password';
const password = 'new test password';

function fixture({ active = true, revoked = false, wrong = false, mismatch = false, updateError = false, updateStatus = 400, logoutError = false, role = 'helper' } = {}) {
  const calls = [];
  let reads = 0;
  const user = { id, email: 'helper.test@example.com', aud: 'authenticated', role: 'authenticated', app_metadata: {}, user_metadata: {}, created_at: '2026-10-21T00:00:00Z' };
  const transport = async (url, init = {}) => {
    const path = new URL(String(url)).pathname;
    calls.push({ path, init });
    if (path === '/rest/v1/app_users') return Response.json([{ id, active: active && !(revoked && ++reads > 1), roles: [role] }]);
    if (path === '/auth/v1/token') {
      if (wrong) return Response.json({ code: 'invalid_credentials', msg: 'Invalid login credentials' }, { status: 400 });
      return Response.json({ user: { ...user, id: mismatch ? otherId : id }, access_token: 'temporary-token', refresh_token: 'temporary-refresh', expires_in: 3600, token_type: 'bearer' });
    }
    if (path === '/auth/v1/logout') return logoutError ? Response.json({ msg: 'Unavailable' }, { status: 400 }) : new Response(null, { status: 204 });
    if (path === '/auth/v1/user' && init.method === 'PUT') {
      if (updateError) return Response.json({ code: updateStatus >= 500 ? 'unexpected_failure' : 'weak_password', msg: 'Internal details must not be shown' }, { status: updateStatus, headers: { 'x-supabase-api-version': '2024-01-01' } });
      return Response.json(user);
    }
    if (path === '/auth/v1/user') return Response.json(user);
    throw new Error('Unexpected request: ' + path);
  };
  return { calls, transport, run: () => changeOwnPassword(config, 'existing-token', current, password, password, transport) };
}

test('new passwords must match, differ, and fit byte limits without trimming spaces', () => {
  assert.equal(validatePasswordChange(current, ' pass phrase ', ' pass phrase ').password, ' pass phrase ');
  for (const input of [[null, password, password], [current, 'too short', 'too short'], [current, password, 'mismatch'], [current, current, current], [current, 'é'.repeat(37), 'é'.repeat(37)], [current, 'a'.repeat(73), 'a'.repeat(73)]]) assert.throws(() => validatePasswordChange(...input), { code: 'invalid_input' });
  assert.equal(validatePasswordChange(current, 'é'.repeat(36), 'é'.repeat(36)).password.length, 36);
});

test('active roles can change only their own password after fresh credential and live membership checks', async () => {
  for (const role of ['helper', 'lead', 'pm', 'admin']) {
    const f = fixture({ role });
    assert.equal(await f.run(), undefined);
    const login = f.calls.find(c => c.path.endsWith('/token'));
    assert.deepEqual(JSON.parse(login.init.body), { email: 'helper.test@example.com', password: current, gotrue_meta_security: {} });
    const update = f.calls.find(c => c.init.method === 'PUT');
    assert.deepEqual(JSON.parse(update.init.body), { password, current_password: current, code_challenge: null, code_challenge_method: null });
    assert.equal(new Headers(update.init.headers).get('authorization'), 'Bearer temporary-token');
    assert.equal(f.calls.filter(c => c.path === '/rest/v1/app_users').length, 2);
    assert(f.calls.some(c => c.path === '/auth/v1/logout'));
    for (const call of f.calls) assert.equal(call.init.cache, 'no-store');
  }
});

test('inactive, revoked, wrong-password and identity-swapped requests never update a password', async () => {
  for (const options of [{ active: false }, { revoked: true }, { wrong: true }, { mismatch: true }]) {
    const f = fixture(options);
    await assert.rejects(f.run());
    assert(!f.calls.some(c => c.init.method === 'PUT'));
    if (options.revoked || options.mismatch) assert(f.calls.some(c => c.path === '/auth/v1/logout'));
  }
});

test('provider rejection is controlled; ambiguous write failure asks to check sign-in and always cleans up', async () => {
  const rejected = fixture({ updateError: true });
  await assert.rejects(rejected.run(), { code: 'invalid_input' });
  assert(rejected.calls.some(c => c.path === '/auth/v1/logout'));
  const uncertain = fixture({ updateError: true, updateStatus: 503 });
  await assert.rejects(uncertain.run(), { code: 'password_change_uncertain' });
  assert(uncertain.calls.some(c => c.path === '/auth/v1/logout'));
  await fixture({ logoutError: true }).run(); // Cleanup does not hide a successful change.
});
