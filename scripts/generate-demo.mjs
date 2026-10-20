import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export function buildDemo() {
  const users = [
    { id: 'admin-01', name: 'Demo Admin', roles: ['admin'], active: true },
    { id: 'pm-01', name: 'Demo PM One', roles: ['pm'], active: true },
    { id: 'pm-02', name: 'Demo PM Two', roles: ['pm'], active: true },
    ...Array.from({ length: 20 }, (_, i) => ({ id: `lead-${String(i + 1).padStart(2, '0')}`, name: `Demo Lead ${i + 1}`, roles: ['lead'], active: true })),
    { id: 'helper-01', name: 'Demo Helper', roles: ['helper'], active: true },
    { id: 'former-01', name: 'Demo Former Employee', roles: ['lead'], active: false }
  ];
  const jobs = Array.from({ length: 40 }, (_, i) => ({
    id: `job-${String(i + 1).padStart(2, '0')}`, customer: `SYNTHETIC Customer ${i + 1}`,
    phone: '202-555-0100', phoneAction: '+12025550100', address: `${100 + i} Fictional Demo Lane (synthetic; do not navigate)`,
    title: i < 10 ? `Window replacement ${i + 1}` : `House project ${i - 9}`,
    workType: i < 10 ? 'windows' : 'house', responsiblePm: i % 2 ? 'pm-02' : 'pm-01', lifecycle: 'open',
    scope: i < 10 ? 'Replace windows; confirm access before arrival.' : 'Addition work; separate framing and finish portions.',
    preparation: 'Synthetic fixture. Bring the listed job supplies.'
  }));
  const work = jobs.map((job, i) => ({ id: `work-${String(i + 1).padStart(2, '0')}`, jobId: job.id,
    description: i < 10 ? 'Window replacement' : 'Framing', leadId: i < 10 ? 'lead-01' : `lead-${String((i - 10) % 20 + 1).padStart(2, '0')}`,
    readiness: i === 2 ? 'waiting_unknown' : i === 3 ? 'waiting_date' : 'ready',
    waitDate: i === 3 ? '2027-03-09' : null, completion: 'open', remainingNote: '' }));
  work.push({ id: 'work-finish', jobId: 'job-11', description: 'Cabinet installation', leadId: 'lead-02', readiness: 'waiting_date', waitDate: '2027-03-09', completion: 'open', remainingNote: 'Cabinets expected in about 20 weeks; not confirmed delivered.' });
  const visits = [
    { id: 'visit-01', workId: 'work-01', startDate: '2026-10-20', endDate: '2026-10-20', slot: 'all_day', status: 'planned', certainty: 'confirmed', requiredHelpers: 1, participants: [{ userId: 'lead-01', role: 'leading' }, { userId: 'helper-01', role: 'helping' }] },
    { id: 'visit-02', workId: 'work-02', startDate: '2026-10-21', endDate: '2026-10-21', slot: 'morning', status: 'planned', certainty: 'tentative', requiredHelpers: 1, participants: [{ userId: 'lead-01', role: 'leading' }] },
    { id: 'visit-03', workId: 'work-11', startDate: '2026-10-22', endDate: '2026-10-22', slot: 'all_day', status: 'planned', certainty: 'confirmed', requiredHelpers: 1, participants: [{ userId: 'lead-01', role: 'leading' }, { userId: 'lead-02', role: 'helping' }] },
    { id: 'visit-04', workId: 'work-finish', startDate: '2027-03-10', endDate: '2027-03-10', slot: 'all_day', status: 'planned', certainty: 'tentative', requiredHelpers: 0, participants: [{ userId: 'lead-02', role: 'leading' }] }
  ];
  const commitments = [{ id: 'sub-01', jobId: 'job-11', trade: 'Demo Electrician', startDate: '2026-10-23', endDate: '2026-10-23', time: null, certainty: 'confirmed', needsAttendance: false, note: 'Time not set; does not reserve internal staff.' }];
  const queues = users.filter(u => u.roles.includes('lead') && u.active).map(u => ({ leadId: u.id, workIds: work.filter(w => w.leadId === u.id).map(w => w.id) }));
  return { synthetic: true, schemaVersion: 1, anchorDate: '2026-10-20', timezone: 'America/Chicago', users, jobs, work, visits, commitments, queues };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  mkdirSync('demo', { recursive: true });
  writeFileSync('demo/synthetic.json', JSON.stringify(buildDemo(), null, 2) + '\n');
  console.log('Generated synthetic fixture: 20 active leads, 30 active houses, 10 window jobs. No database connection.');
}
