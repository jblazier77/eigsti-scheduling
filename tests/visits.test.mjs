import {readFileSync} from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { validateVisit, visitPatch, companyToday, monday, addDays, visitOnDay, slotLabel, requirePlanner } from '../src/domain/visits.ts';
import { VisitSession } from '../src/server/visits.ts';
const lead = '33333333-3333-4333-8333-333333333333';
const work = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const request = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const base = { start_date: '2026-10-26', end_date: '2026-10-26', slot: 'day', coordinator_id: lead, required_helpers: '0', certainty: 'tentative' };
test('date-only visit needs no time; explicit reservations validate independently', () => {
  const day = validateVisit(base); assert.equal(day.slot, 'day'); assert.equal(day.start_time, null); assert.equal(slotLabel(day), 'No time set');
  assert.equal(validateVisit({ ...base, slot: 'timed', start_time: '07:00', end_time: '15:30' }).end_time, '15:30');
  for (const patch of [{ start_date: '2026-02-30' }, { end_date: '2026-10-25' }, { end_date: '2026-12-01' }, { required_helpers: '2.5' }, { required_helpers: '21' }, { coordinator_id: 'bad' }, { slot: 'timed' }, { slot: 'timed', start_time: '06:59', end_time: '10:00' }, { slot: 'timed', start_time: '10:00', end_time: '10:00' }, { slot: 'timed', start_time: '10:67', end_time: '12:00' }, { slot: 'timed', start_time: '10:00', end_time: '16:00' }, { slot: 'timed', start_time: '10:00', end_time: '12:00', end_date: '2026-10-27' }]) assert.throws(() => validateVisit({ ...base, ...patch }));
});
test('local calendar arithmetic preserves dates through DST, leap day, and year boundaries', () => {
  assert.equal(companyToday(new Date('2026-11-02T04:30:00Z')), '2026-11-01');
  assert.equal(monday('2026-11-01'), '2026-10-26'); assert.equal(addDays('2026-10-30', 3), '2026-11-02');
  assert.equal(addDays('2028-02-28', 1), '2028-02-29'); assert.equal(addDays('2026-12-31', 1), '2027-01-01');
  const visit = { start_date: '2026-10-30', end_date: '2026-11-03' };
  assert.equal(visitOnDay(visit, '2026-10-31'), true); assert.equal(visitOnDay(visit, '2026-11-02'), true); assert.equal(visitOnDay(visit, '2026-11-04'), false);
});
test('narrow visit patches preserve unrelated dates/staffing and normalize returned seconds', () => {
  const before = validateVisit(base);
  assert.deepEqual(visitPatch(before, { ...before, certainty: 'confirmed' }), { certainty: 'confirmed' });
  assert.deepEqual(visitPatch({ ...before, slot: 'timed', start_time: '10:00:00', end_time: '12:00:00' }, { ...before, slot: 'timed', start_time: '10:00', end_time: '12:00' }), {});
  assert.deepEqual(visitPatch({ ...before, slot: 'timed', start_time: '10:00', end_time: '12:00' }, { ...before, slot: 'day' }), { slot: 'day', start_time: null, end_time: null });
});
test('helpers, admin-only, anonymous and inactive accounts cannot invoke planner domain', () => {
  for (const roles of [['helper'], ['admin'], []]) assert.throws(() => requirePlanner({ id: lead, active: true, roles }));
  assert.throws(() => requirePlanner(null)); assert.throws(() => requirePlanner({ id: lead, active: false, roles: ['pm'] }));
  for (const roles of [['pm'], ['lead'], ['admin', 'pm']]) assert.doesNotThrow(() => requirePlanner({ id: lead, active: true, roles }));
});
test('visit transport sends scoped atomic commands and maps overlap as definite failure', async () => {
  const calls = [];
  const session = new VisitSession({ url: 'https://example.supabase.co', publishableKey: 'sb_publishable_test', environment: 'test' }, 'employee-token', async (url, options) => {
    calls.push({ url, options, body: JSON.parse(options.body) }); return Response.json({ id: work });
  });
  await session.saveVisit(work, null, request, validateVisit(base));
  await session.staffVisit(work, request, [lead]);
  assert.equal(calls[0].options.headers.Authorization, 'Bearer employee-token'); assert.equal(calls[0].options.cache, 'no-store');
  assert.deepEqual(calls[0].body, { p_work_id: work, p_visit_id: null, p_request_id: request, p_patch: validateVisit(base) });
  assert.deepEqual(calls[1].body, { p_visit_id: work, p_request_id: request, p_helpers: [lead] });
  const conflicting = new VisitSession({ url: 'https://example.supabase.co', publishableKey: 'sb_publishable_test', environment: 'test' }, 'employee-token', async () => Response.json({ code: '23P01' }, { status: 400 }));
  await assert.rejects(conflicting.staffVisit(work, request, [lead]), error => error.code === 'staff_conflict' && error.status === 409);
});

test('Saturday work is valid with no lead and optional times while Sunday remains excluded',()=>{
 const sat={...base,start_date:'2026-10-31',end_date:'2026-10-31',coordinator_id:null};assert.equal(validateVisit(sat).coordinator_id,null);assert.equal(validateVisit({...sat,slot:'timed',start_time:'08:00',end_time:'12:00'}).slot,'timed');assert.throws(()=>validateVisit({...sat,start_date:'2026-11-01',end_date:'2026-11-01'}));
 const range={start_date:'2026-10-30',end_date:'2026-11-02'};assert.equal(visitOnDay(range,'2026-10-31'),true);assert.equal(visitOnDay(range,'2026-11-01'),false);assert.equal(visitOnDay(range,'2026-11-02'),true);
});
test('Saturday batch changes only workday validation and reservations with guarded fixture cleanup',()=>{
 const ddl=readFileSync(new URL('../database/migrations/0023_saturday_work.sql',import.meta.url),'utf8'),checks=readFileSync(new URL('../database/tests/0023_saturday_work.test.sql',import.meta.url),'utf8'),batch=readFileSync(new URL('../database/batches/0023_saturday_work.sql',import.meta.url),'utf8');assert(batch.includes(ddl.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'')));assert(batch.includes(checks.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')));assert.equal((checks.match(/insert into pg_temp.eigsti_saturday_results\(result\)/g)||[]).length,16);assert.equal((batch.match(/^commit;$/gm)||[]).length,1);assert(batch.indexOf('rollback to savepoint saturday_checks')<batch.lastIndexOf('\ncommit;'));assert(ddl.includes('extract(isodow from d)<7'));assert(ddl.includes('existing multi-day explicit reservations'));assert(!ddl.includes('grant '));
});
