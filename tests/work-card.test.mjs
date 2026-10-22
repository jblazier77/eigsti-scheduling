import test from 'node:test';
import assert from 'node:assert/strict';
import { changedWorkCard, updateWorkCard, validateWorkChanges } from '../src/domain/work.ts';
import { WorkSession } from '../src/server/work.ts';

const jobId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const first = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const second = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const lead = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const pm = { id: jobId, active: true, roles: ['pm'] };
const rows = [
  { id: first, job_id: jobId, description: 'Cabinets', responsible_lead: lead, lead_name: 'Test Lead', completion: 'open' },
  { id: second, job_id: jobId, description: 'Countertops', responsible_lead: lead, lead_name: 'Test Lead', completion: 'open' }
];

test('card diff includes only changed fields and ignores completed portions', () => {
  assert.deepEqual(changedWorkCard(rows, { [first]: { description: ' New cabinets ', responsible_lead: lead }, [second]: { description: 'Countertops', responsible_lead: null } }), [
    { work_id: first, patch: { description: 'New cabinets' } }, { work_id: second, patch: { responsible_lead: null } }
  ]);
  assert.deepEqual(changedWorkCard([{ ...rows[0], completion: 'completed' }], { [first]: { description: 'Forged', responsible_lead: null } }), []);
});

test('batch validation normalizes ordering and rejects duplicate IDs, privilege fields and oversized drafts', () => {
  assert.deepEqual(validateWorkChanges([{ work_id: second.toUpperCase(), patch: { description: ' Trimmed ' } }, { work_id: first, patch: { responsible_lead: null } }]), [
    { work_id: first, patch: { responsible_lead: null } }, { work_id: second, patch: { description: 'Trimmed' } }
  ]);
  for (const value of [[], null, {}, [{ work_id: first, patch: {} }], [{ work_id: 'bad', patch: { description: 'New' } }], [{ work_id: first, patch: { completion: 'completed' } }], [{ work_id: first, patch: { description: 'New' }, actor_id: lead }], [{ work_id: first, patch: { description: 'New' } }, { work_id: first.toUpperCase(), patch: { responsible_lead: null } }]]) assert.throws(() => validateWorkChanges(value), { code: 'invalid_input' });
  const large = Array.from({ length: 30 }, (_, i) => ({ work_id: (i + 1).toString(16).padStart(8, '0') + '-aaaa-4aaa-8aaa-aaaaaaaaaaaa', patch: { description: 'x'.repeat(1000) } }));
  assert.throws(() => validateWorkChanges(large), { code: 'invalid_input' });
});

test('batch authorization and transport use one request with the job and retry identity', async () => {
  const calls = [];
  const gateway = new WorkSession({ url: 'https://synthetic-project.supabase.co', publishableKey: 'sb_publishable_test', environment: 'test' }, 'employee-token', async (url, init) => { calls.push({ url: String(url), init }); return Response.json({ id: jobId, work: rows }); });
  const changes = [{ work_id: first, patch: { description: 'New' } }];
  for (const actor of [null, { ...pm, active: false }, { ...pm, roles: ['helper'] }, { ...pm, roles: ['lead'] }, { ...pm, roles: ['admin'] }]) await assert.rejects(updateWorkCard(actor, jobId, lead, changes, gateway));
  assert.equal(calls.length, 0);
  assert.equal((await updateWorkCard(pm, jobId, lead, changes, gateway)).work.length, 2);
  assert.equal(calls.length, 1); assert(calls[0].url.endsWith('/rpc/update_job_work_batch'));
  assert.deepEqual(JSON.parse(calls[0].init.body), { p_job_id: jobId, p_request_id: lead, p_changes: changes });
  assert.equal(calls[0].init.headers.Authorization, 'Bearer employee-token');
});
