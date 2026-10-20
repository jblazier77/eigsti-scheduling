import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { buildDemo } from '../scripts/generate-demo.mjs';

const data = buildDemo();
test('checked-in fixture is deterministic and synthetic', () => {
  assert.equal(data.synthetic, true);
  assert.deepEqual(JSON.parse(readFileSync('demo/synthetic.json', 'utf8')), data);
  assert.equal(data.users.filter(u => u.active && u.roles.includes('lead')).length, 20);
  assert.equal(data.jobs.filter(j => j.workType === 'house' && j.lifecycle === 'open').length, 30);
  assert.equal(data.queues.find(q => q.leadId === 'lead-01').workIds.slice(0, 10).length, 10);
});
test('fixture IDs and foreign relationships are coherent', () => {
  for (const table of ['users', 'jobs', 'work', 'visits', 'commitments']) {
    assert.equal(new Set(data[table].map(r => r.id)).size, data[table].length);
  }
  const users = new Map(data.users.map(u => [u.id, u]));
  const jobs = new Set(data.jobs.map(j => j.id));
  const work = new Map(data.work.map(w => [w.id, w]));
  for (const w of data.work) { assert(jobs.has(w.jobId)); assert(users.get(w.leadId)?.active); }
  for (const v of data.visits) {
    assert(work.has(v.workId)); assert(v.endDate >= v.startDate);
    assert.equal(v.participants.filter(p => p.role === 'leading').length, 1);
    assert.equal(new Set(v.participants.map(p => p.userId)).size, v.participants.length);
    for (const p of v.participants) assert(users.get(p.userId)?.active);
  }
  for (const c of data.commitments) assert(jobs.has(c.jobId));
  for (const q of data.queues) {
    assert.equal(new Set(q.workIds).size, q.workIds.length);
    for (const id of q.workIds) assert.equal(work.get(id)?.leadId, q.leadId);
  }
});
test('fixture represents separate portions, shared lead/help and unresolved help', () => {
  const portions = data.work.filter(w => w.jobId === 'job-11');
  assert.equal(new Set(portions.map(w => w.leadId)).size, 2);
  assert(data.visits.some(v => v.participants.some(p => p.userId === 'lead-02' && p.role === 'helping')));
  assert(data.visits.some(v => v.requiredHelpers > v.participants.filter(p => p.role === 'helping').length));
  assert(data.work.some(w => w.readiness === 'waiting_unknown' && w.waitDate === null));
  assert.equal(data.commitments[0].time, null);
  assert.equal(data.commitments[0].needsAttendance, false);
});
