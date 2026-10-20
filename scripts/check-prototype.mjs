// Structural smoke check, not browser/phone or authorization verification.
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { buildDemo } from './generate-demo.mjs';

const elements = new Map();
const listeners = new Map();
const element = selector => {
  if (!elements.has(selector)) elements.set(selector, { innerHTML: '', textContent: '', addEventListener() {} });
  return elements.get(selector);
};
const context = vm.createContext({
  document: { querySelector: element, addEventListener: (event, fn) => listeners.set(event, fn) },
  window: { scrollTo() {} }, crypto: { randomUUID },
  fetch: async () => ({ ok: true, json: async () => buildDemo() }),
  FormData: class { constructor(form) { return Object.entries(form.values); } }
});
const html = readFileSync('prototype/index.html', 'utf8');
await vm.runInContext(html.match(/<script>([\s\S]*?)<\/script>/)[1], context);
const run = code => vm.runInContext(code, context);
assert(element('#view').innerHTML.includes('Upcoming work'));
for (const role of ['lead', 'pm', 'helper', 'admin']) {
  run(`role=${JSON.stringify(role)}; page=role==='admin'?'admin':role==='pm'?'jobs':'week';render();`);
  assert(element('#view').innerHTML.length > 100);
}
run("role='helper';currentJob='job-01';page='job';render();");
assert(!element('#view').innerHTML.includes('data-action="plan"'));
assert(!element('#view').innerHTML.includes('data-action="sub"'));
run("role='lead';currentJob='job-01';page='plan';render();");
assert(element('#view').innerHTML.includes('Add to demo week'));
const submit = (id, values) => listeners.get('submit')({ preventDefault() {}, target: { id, values } });
const previousVisits = run('data.visits.length');
submit('plan', { date: '2026-10-26', slot: 'morning' });
assert.equal(run('data.visits.length'), previousVisits + 1);
run("currentJob='job-01';page='done';render();");
listeners.get('click')({ target: { closest: () => ({ dataset: { action: 'return', id: 'job-01' } }) } });
assert.equal(run("work('work-01').completion"), 'open');
assert.equal(run("job('job-01').lifecycle"), 'open');
assert.match(run("work('work-01').remainingNote"), /Return needed/);
run("role='pm';page='new';render();");
submit('new-job', { customer: 'Synthetic New Customer', phone: '202-555-0101', address: 'Fictional Demo Place' });
run("currentJob=data.jobs.at(-1).id;page='plan';render();");
assert(element('#view').innerHTML.includes('Assign a responsible lead'));
run("currentJob='job-01';page='sub';render();");
submit('sub', { date: '2026-10-23', trade: 'Demo Electrician', certainty: 'confirmed' });
assert.equal(run('data.commitments.at(-1).time'), null);
assert.equal(run('data.visits.length'), previousVisits + 1);
console.log('Prototype syntax and DOM-stub smoke checks passed: role renders, helper controls, plan, return, new job, unassigned planning, no-time sub commitment. Browser/mobile checks remain pending.');
