import test from 'node:test';
import assert from 'node:assert/strict';
import { createContact, updateContact, archiveContact, validateContact, changedContactFields, emptyContact } from '../src/domain/contacts.ts';
import { SupabaseSession } from '../src/server/supabase.ts';

const jobId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const contactId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const requestId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const pm = { id: jobId, active: true, roles: ['pm'] };
const values = { ...emptyContact, name: '  Test Spouse  ', phone: '(309) 555-0103', relationship: 'Spouse', notes: 'Line one\nLine two' };
const config = { url: 'https://synthetic-project.supabase.co', publishableKey: 'sb_publishable_test', environment: 'test' };

test('contact validation requires only a name and retains multiline notes and readable phone', () => {
  assert.deepEqual(validateContact({ ...emptyContact, name: 'Test Contact' }), { ...emptyContact, name: 'Test Contact' });
  assert.deepEqual(validateContact(values), { ...values, name: 'Test Spouse' });
  for (const patch of [{ name: '' }, { name: 'x'.repeat(101) }, { phone: '555' }, { email: 'not-email' }, { notes: 'x'.repeat(1001) }, { name: 'Two\nlines' }, { notes: 'control\u0001' }, { email: 'x@example.com\r\nbcc:bad' }, { created_by: jobId }, { job_id: jobId }, { archived_at: 'now' }, { roles: ['pm'] }]) {
    assert.throws(() => validateContact({ ...values, ...patch }), { code: 'invalid_input' });
  }
  for (const invalid of [null, [], {}, { name: 'Missing fields' }]) assert.throws(() => validateContact(invalid), { code: 'invalid_input' });
});

test('contact patches clear optional fields while omitting stale phone and relationship values', () => {
  const original = { ...values, name: 'Test Spouse', email: 'test@example.com' };
  const patch = changedContactFields(original, { ...original, notes: 'New note', email: '' });
  assert.deepEqual(validateContact(patch, true), { email: '', notes: 'New note' });
  assert(!Object.hasOwn(patch, 'phone'));
  assert.deepEqual(validateContact({ phone: '', email: '', notes: '' }, true), { phone: '', email: '', notes: '' });
  assert.throws(() => validateContact({}, true), { code: 'invalid_input' });
});

test('all contact commands deny helper, lead, admin-only, anonymous and inactive actors before writing', async () => {
  let writes = 0;
  const gateway = { createContact: async () => { writes++; }, updateContact: async () => { writes++; }, archiveContact: async () => { writes++; } };
  for (const actor of [null, { ...pm, active: false }, ...['helper', 'lead', 'admin'].map(role => ({ ...pm, roles: [role] }))]) {
    await assert.rejects(createContact(actor, jobId, requestId, values, gateway));
    await assert.rejects(updateContact(actor, jobId, contactId, { notes: 'Forged' }, gateway));
    await assert.rejects(archiveContact(actor, jobId, contactId, gateway));
  }
  assert.equal(writes, 0);
});

test('active PM commands validate IDs, pass stable create retry identity and send only changed fields', async () => {
  const calls = [];
  const gateway = {
    createContact: async (...args) => { calls.push(['create', ...args]); return { id: contactId }; },
    updateContact: async (...args) => { calls.push(['update', ...args]); return { id: contactId }; },
    archiveContact: async (...args) => { calls.push(['archive', ...args]); return { id: contactId }; }
  };
  await assert.rejects(createContact(pm, jobId, 'bad', values, gateway), { code: 'invalid_input' });
  await assert.rejects(updateContact(pm, 'bad', contactId, { notes: '' }, gateway), { code: 'invalid_input' });
  await assert.rejects(archiveContact(pm, jobId, 'bad', gateway), { code: 'invalid_input' });
  assert.equal(calls.length, 0);
  await createContact(pm, jobId, requestId, values, gateway);
  await createContact(pm, jobId, requestId, values, gateway);
  await updateContact(pm, jobId, contactId, { notes: 'Only this note' }, gateway);
  await archiveContact(pm, jobId, contactId, gateway);
  assert.deepEqual(calls[0], calls[1]);
  assert.deepEqual(calls[2], ['update', jobId, contactId, { notes: 'Only this note' }]);
  assert.deepEqual(calls[3], ['archive', jobId, contactId]);
});

test('contact transport scopes reads and writes to job plus contact and preserves employee identity', async () => {
  const calls = [];
  const gateway = new SupabaseSession(config, 'employee-token', async (url, init) => {
    calls.push({ url, init });
    return Response.json(url.includes('/rpc/') ? { id: contactId } : []);
  });
  await gateway.listContacts(jobId);
  assert.equal(await gateway.getContact(jobId, contactId), null);
  await gateway.createContact(jobId, requestId, values);
  await gateway.updateContact(jobId, contactId, { phone: '' });
  await gateway.archiveContact(jobId, contactId);
  for (const call of calls) assert.equal(call.init.headers.Authorization, 'Bearer employee-token');
  const detail = new URL(calls[1].url);
  assert.equal(detail.searchParams.get('job_id'), 'eq.' + jobId);
  assert.equal(detail.searchParams.get('id'), 'eq.' + contactId);
  assert.equal(detail.searchParams.get('archived_at'), 'is.null');
  assert.deepEqual(JSON.parse(calls[2].init.body), { p_job_id: jobId, p_request_id: requestId, p_values: values });
  assert.deepEqual(JSON.parse(calls[3].init.body), { p_job_id: jobId, p_contact_id: contactId, p_patch: { phone: '' } });
  assert.deepEqual(JSON.parse(calls[4].init.body), { p_job_id: jobId, p_contact_id: contactId });
});

test('missing contact schema and interrupted writes are not reported as empty contacts or successful saves', async () => {
  const missing = new SupabaseSession(config, 'employee-token', async () => Response.json({ code: 'PGRST205', message: 'private SQL detail' }, { status: 404 }));
  await assert.rejects(missing.listContacts(jobId), { code: 'schema_pending' });
  const interrupted = new SupabaseSession(config, 'employee-token', async () => { throw new Error('private connection detail'); });
  await assert.rejects(interrupted.createContact(jobId, requestId, values), { code: 'connection_failed' });
});
