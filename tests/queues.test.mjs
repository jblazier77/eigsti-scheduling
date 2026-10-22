import test from 'node:test';
import assert from 'node:assert/strict';
import { moveQueueItem, readQueue, saveQueue, validateQueueOrder } from '../src/domain/queues.ts';
import { QueueSession } from '../src/server/queues.ts';

const leadId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const workId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const requestId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const lead = { id: leadId, roles: ['lead'], active: true };

test('up/down moves preserve distinct work IDs, complete membership and boundary order', () => {
  const original = [leadId, other, workId];
  assert.deepEqual(moveQueueItem(original, other, -1), [other, leadId, workId]);
  assert.deepEqual(moveQueueItem(original, other, 1), [leadId, workId, other]);
  assert.deepEqual(moveQueueItem(original, leadId, -1), original);
  assert.deepEqual(moveQueueItem(original, workId, 1), original);
  assert.deepEqual(original, [leadId, other, workId]);
  assert.deepEqual(validateQueueOrder([]), []);
  assert.deepEqual(validateQueueOrder([other.toUpperCase(), workId]), [other, workId]);
  for (const ids of [null, {}, [other, other.toUpperCase()], ['bad'], Array(501).fill(workId)]) assert.throws(() => validateQueueOrder(ids), { code: 'invalid_input' });
});

test('only an active PM or target lead reaches queue transport; no implicit admin or helper privilege', async () => {
  const calls = [];
  const gateway = { getQueue: async (...args) => calls.push(['read', ...args]), saveQueue: async (...args) => calls.push(['save', ...args]) };
  for (const actor of [null, { ...lead, active: false }, { ...lead, roles: ['helper'] }, { ...lead, roles: ['admin'] }, { ...lead, id: other }]) {
    await assert.rejects(readQueue(actor, leadId, gateway));
    await assert.rejects(saveQueue(actor, leadId, requestId, [workId], gateway));
  }
  assert.equal(calls.length, 0);
  await saveQueue(lead, leadId, requestId, [workId], gateway);
  await saveQueue({ ...lead, id: other, roles: ['pm'] }, leadId, requestId, [workId], gateway);
  assert.deepEqual(calls, [['save', leadId, requestId, [workId]], ['save', leadId, requestId, [workId]]]);
});

test('queue RPC sends the exact order/target/retry identity and exposes controlled membership conflicts', async () => {
  const calls = [];
  const config = { url: 'https://synthetic-project.supabase.co', publishableKey: 'sb_publishable_test', environment: 'test' };
  const gateway = new QueueSession(config, 'employee-token', async (url, init) => { calls.push({ url: String(url), init }); return Response.json({ lead_id: leadId, revision: 4, items: [] }); });
  await gateway.getQueue(leadId); await gateway.saveQueue(leadId, requestId, [workId, other]);
  assert.deepEqual(JSON.parse(calls[1].init.body), { p_lead_id: leadId, p_request_id: requestId, p_work_ids: [workId, other] });
  for (const call of calls) { assert.equal(call.init.headers.Authorization, 'Bearer employee-token'); assert.equal(call.init.cache, 'no-store'); }
  const changed = new QueueSession(config, 'employee-token', async () => Response.json({ code: '22023', message: 'Queue membership changed' }, { status: 400 }));
  await assert.rejects(changed.saveQueue(leadId, requestId, [workId]), { code: 'queue_membership_changed', status: 409 });
});
