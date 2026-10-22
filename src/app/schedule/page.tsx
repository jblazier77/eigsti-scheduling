import Link from 'next/link';
import { redirect } from 'next/navigation';
import { requireSession } from '../../lib/session';
import { visitSession } from '../../lib/visit-session';
import { addDays, companyToday, dateLabel, monday, validDate, visitOnDay } from '../../domain/visits.ts';
import { Shell } from '../components/shell';
import { InlineVisit } from '../components/inline-visit';
import { JobMarkers } from '../components/job-markers';
export const dynamic = 'force-dynamic';
export default async function SchedulePage({ searchParams }: { searchParams: Promise<{ day?: string; view?: string; scope?: string }> }) {
  const { actor, gateway:jobsGateway } = await requireSession();
  const pm = actor.roles.includes('pm');
  if (!pm && !actor.roles.some(r => r === 'lead' || r === 'helper')) redirect('/jobs');
  const query = await searchParams; const day = validDate(query.day) ? query.day : companyToday();
  const week = query.view === 'week', start = week ? monday(day) : day, end = week ? addDays(start, 4) : day;
  const scope = pm && query.scope === 'all' ? 'all' : 'mine';
  const { gateway } = await visitSession(); const visits = await gateway.schedule(start, end, scope === 'all');
  const markers=await jobsGateway.jobMarkers(visits.map(v=>v.job_id));
  const days = week ? Array.from({ length: 5 }, (_, i) => addDays(start, i)) : [day];
  const url = (date: string, view = week ? 'week' : 'day') => '/schedule?' + new URLSearchParams({ day: date, view, scope });
  return <Shell title={pm ? 'Job schedule' : 'My schedule'}>
    <form action="/schedule" className="queue-filter"><label>Day<input type="date" name="day" defaultValue={day} required /></label><input type="hidden" name="view" value={week ? 'week' : 'day'} />{pm && <label>Jobs<select name="scope" defaultValue={scope}><option value="mine">My jobs</option><option value="all">All jobs</option></select></label>}<button className="button">Show schedule</button></form>
    <nav className="schedule-nav" aria-label="Schedule views"><Link className="button" href={url(addDays(day, week ? -7 : -1))}>Previous</Link><Link className="button" href={url(companyToday())}>Today</Link><Link className="button" href={url(addDays(day, week ? 7 : 1))}>Next</Link><Link className="button" aria-current={!week ? 'page' : undefined} href={url(day, 'day')}>Day list</Link><Link className="button" aria-current={week ? 'page' : undefined} href={url(day, 'week')}>Week calendar</Link></nav>
    <details className="schedule-notes"><summary>Schedule notes</summary><p className="muted">Central time. Weekdays 7:00 AM-3:30 PM. Dates alone allow several jobs per day; optional time blocks reserve named people.</p></details>
    <div className={week ? 'schedule-week' : 'schedule-day'}>{days.map(date => <section className="schedule-column" key={date}><h2>{dateLabel(date)}</h2>{!visits.some(v => visitOnDay(v, date)) && <p>No jobs scheduled.</p>}{visits.filter(v => visitOnDay(v, date)).sort((a, b) => (a.slot === 'afternoon' ? '12:00' : a.start_time ?? '07:00').localeCompare(b.slot === 'afternoon' ? '12:00' : b.start_time ?? '07:00')).map(v => <article className="card" key={v.id}><JobMarkers value={markers[v.job_id]??{}}/><InlineVisit visit={v} showJob editable={pm || actor.roles.includes('lead') && v.coordinator_id === actor.id} /><p><Link href={'/jobs/' + v.job_id}>Open job</Link></p></article>)}</section>)}</div>
  </Shell>;
}

