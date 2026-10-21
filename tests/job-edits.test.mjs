import test from 'node:test';
import assert from 'node:assert/strict';
import { changedJobFields, validateJobPatch, updateJob } from '../src/domain/job-edits.ts';
import { SupabaseSession } from '../src/server/supabase.ts';

const id = '11111111-1111-4111-8111-111111111111';
const pm = { id, active: true, roles: ['pm'] };
const original = { title: 'Kitchen renovation', customer_name: 'Test Customer', phone: '309-555-0101', address: '123 Example Lane', scope: 'Old scope', access_notes: 'Park by garage' };

test('saving scope sends no stale contact fields; optional notes can be cleared', () => {
  const patch = changedJobFields(original, { ...original, scope: 'New scope\nSecond line', access_notes: '' });
  assert.deepEqual(validateJobPatch(patch), { scope: 'New scope\nSecond line', access_notes: '' });
  const concurrent = { ...original, phone: '309-555-0102', address: '456 Example Lane' };
  assert.deepEqual({ ...concurrent, ...patch }, { ...concurrent, scope: 'New scope\nSecond line', access_notes: '' });
  assert.deepEqual(changedJobFields(original, { ...original, address: '  Changed address  ' }), { address: 'Changed address' });
  assert.deepEqual(changedJobFields(original, original), {});
});

test('patch validation rejects privilege/lifecycle fields, malformed text, empty required fields and bad phones', () => {
  for (const patch of [null, [], {}, { roles: ['pm'] }, { responsible_pm: id }, { lifecycle: 'closed' }, { phone_action: '+13095550101' }, { title: '' }, { address: ' \t' }, { scope: null }, { scope: 'x'.repeat(5001) }, { access_notes: 'x'.repeat(2001) }, { scope: 'unsafe\u0000text' }, { title: 'line\nbreak' }, { phone: '555' }, { phone: '3095550101;extension' }]) {
    assert.throws(() => validateJobPatch(patch), { code: 'invalid_input' });
  }
  assert.deepEqual(validateJobPatch({ phone: ' (309) 555-0101 ', scope: '', title: ' Custom title ' }), { phone: '(309) 555-0101', scope: '', title: 'Custom title' });
});

test('update denies non-PMs and disabled accounts before writing; active PMs can update', async () => {
  const writes = [];
  const gateway = { updateJob: async (jobId, patch) => { writes.push({ jobId, patch }); return { id: jobId }; } };
  for (const actor of [null, { ...pm, active: false }, ...['helper', 'lead', 'admin'].map(role => ({ ...pm, roles: [role] }))]) {
    await assert.rejects(updateJob(actor, id, { scope: 'Changed' }, gateway));
  }
  await assert.rejects(updateJob(pm, 'bad-id', { scope: 'Changed' }, gateway), { code: 'invalid_input' });
  assert.equal(writes.length, 0);
  await updateJob(pm, id, { scope: 'Changed' }, gateway);
  assert.deepEqual(writes, [{ jobId: id, patch: { scope: 'Changed' } }]);
});

test('update uses the employee token and narrow RPC payload; unavailable jobs return controlled errors', async () => {
  const config = { url: 'https://synthetic-project.supabase.co', publishableKey: 'sb_publishable_test', environment: 'test' };
  let call;
  const session = new SupabaseSession(config, 'employee-token', async (url, init) => {
    call = { url, init };
    return Response.json({ id });
  });
  await session.updateJob(id, { scope: 'Scope only' });
  assert(call.url.endsWith('/rest/v1/rpc/update_job'));
  assert.equal(call.init.headers.Authorization, 'Bearer employee-token');
  assert.deepEqual(JSON.parse(call.init.body), { p_job_id: id, p_patch: { scope: 'Scope only' } });
  const missing = new SupabaseSession(config, 'employee-token', async () => Response.json({ code: 'P0002', message: 'private SQL detail' }, { status: 400 }));
  await assert.rejects(missing.updateJob(id, { scope: '' }), { code: 'job_unavailable', message: 'This job is unavailable.' });
});
