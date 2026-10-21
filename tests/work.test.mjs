import test from 'node:test';
import assert from 'node:assert/strict';
import { changedWorkFields, createWork, updateWork, validateWork } from '../src/domain/work.ts';
import { WorkSession } from '../src/server/work.ts';

const jobId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const workId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const leadId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const requestId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const pm = { id: jobId, active: true, roles: ['pm'] };

test('work patches keep ownership separate from description and allow clearing only the lead', () => {
  const original = { description: 'Whole job', responsible_lead: leadId };
  assert.deepEqual(changedWorkFields(original, { ...original, description: ' Framing ' }), { description: 'Framing' });
  assert.deepEqual(changedWorkFields(original, { ...original, responsible_lead: null }), { responsible_lead: null });
  assert.deepEqual(validateWork({ description: ' Whole job ', responsible_lead: null }), { description: 'Whole job', responsible_lead: null });
  for (const input of [{ description: '' }, { description: 'x'.repeat(1001) }, { description: 'a\nb' }, { responsible_lead: '' }, { responsible_lead: 'bad' }, { completion: 'completed' }, { created_by: pm.id }, {}, []]) assert.throws(() => validateWork(input, true), { code: 'invalid_input' });
  assert.throws(() => validateWork({ responsible_lead: null }), { code: 'invalid_input' });
});

test('only active PMs reach work commands and forged IDs or fields never reach transport', async () => {
  const calls = [];
  const gateway = { createWork: async (...args) => { calls.push(['create', ...args]); return { id: workId }; }, updateWork: async (...args) => { calls.push(['update', ...args]); return { id: workId }; } };
  for (const actor of [null, { ...pm, active: false }, { ...pm, roles: ['lead'] }, { ...pm, roles: ['helper'] }, { ...pm, roles: ['admin'] }]) {
    await assert.rejects(createWork(actor, jobId, requestId, { description: 'Whole job', responsible_lead: leadId }, gateway));
    await assert.rejects(updateWork(actor, jobId, workId, { responsible_lead: leadId }, gateway));
  }
  await assert.rejects(updateWork(pm, jobId, 'forged', { description: 'Work' }, gateway));
  await assert.rejects(updateWork(pm, jobId, workId, { responsible_pm: leadId }, gateway));
  assert.equal(calls.length, 0);
  await createWork(pm, jobId, requestId, { description: ' Framing ', responsible_lead: leadId }, gateway);
  await updateWork(pm, jobId, workId, { responsible_lead: null }, gateway);
  assert.deepEqual(calls, [['create', jobId, requestId, { description: 'Framing', responsible_lead: leadId }], ['update', jobId, workId, { responsible_lead: null }]]);
});

test('work transport scopes every command and read while preserving employee identity and narrow payloads', async () => {
  const calls = [];
  const gateway = new WorkSession({ url: 'https://synthetic-project.supabase.co', publishableKey: 'sb_publishable_test', environment: 'test' }, 'employee-token', async (url, init) => { calls.push({ url: String(url), init }); return Response.json([]); });
  await gateway.listWork(jobId); await gateway.listLeads();
  await gateway.createWork(jobId, requestId, { description: 'Framing', responsible_lead: leadId });
  await gateway.updateWork(jobId, workId, { responsible_lead: null });
  assert.deepEqual(JSON.parse(calls[0].init.body), { p_job_id: jobId });
  assert(calls[1].url.endsWith('/rpc/list_assignable_leads'));
  assert.deepEqual(JSON.parse(calls[2].init.body), { p_job_id: jobId, p_request_id: requestId, p_values: { description: 'Framing', responsible_lead: leadId } });
  assert.deepEqual(JSON.parse(calls[3].init.body), { p_job_id: jobId, p_work_id: workId, p_patch: { responsible_lead: null } });
  for (const call of calls) { assert.equal(call.init.cache, 'no-store'); assert.equal(call.init.headers.Authorization, 'Bearer employee-token'); }
});
