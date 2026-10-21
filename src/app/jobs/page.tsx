import Link from 'next/link';
import { listJobs } from '../../domain/jobs.ts';
import { requireSession } from '../../lib/session';
import { Shell } from '../components/shell';

export const dynamic = 'force-dynamic';
export default async function Jobs({ searchParams }: { searchParams: Promise<{ scope?: string; offset?: string }> }) {
  const { actor, gateway } = await requireSession();
  const query = await searchParams;
  const pm = actor.roles.includes('pm');
  const scope = pm && query.scope === 'all' ? 'all' : 'mine';
  const offset = /^\d+$/.test(query.offset ?? '') ? Math.min(Number(query.offset), 100000) : 0;
  const jobs = await listJobs(actor, { scope, offset: String(offset) }, gateway);
  return <Shell title={pm && scope === 'all' ? 'All Jobs' : 'My Jobs'}>
    <div className="toolbar">{pm && <div className="segmented" aria-label="Job filter"><Link className={scope === 'mine' ? 'selected' : ''} aria-current={scope === 'mine' ? 'page' : undefined} href="/jobs">My Jobs</Link><Link className={scope === 'all' ? 'selected' : ''} aria-current={scope === 'all' ? 'page' : undefined} href="/jobs?scope=all">All Jobs</Link></div>}{pm && <Link className="button primary" href="/jobs/new">+ New job</Link>}</div>
    <div className="section-heading"><h2>{pm ? 'Jobs to keep moving' : 'Your assigned jobs'}</h2><span className="muted">{jobs.length}{jobs.length === 50 ? '+' : ''} shown</span></div>
    {jobs.length === 0 ? <div className="card empty"><div className="empty-mark" aria-hidden="true">↗</div><h2>No jobs here yet</h2><p>{pm ? 'Create a job with a customer name, phone number and address.' : 'Your assigned jobs will appear here when your PM adds you.'}</p>{pm && <Link className="button primary" href="/jobs/new">Create the first job</Link>}</div> : <div className="job-grid">{jobs.map(job => <Link key={job.id} className="job-card" href={'/jobs/' + job.id}><div className="job-top"><span className="badge">{job.lifecycle === 'open' ? 'Open job' : 'Closed job'}</span><span aria-hidden="true">↗</span></div><h2>{job.title}</h2><p>{job.customer_name}</p><p className="muted">{job.address}</p><div className="card-link">Open job details <span aria-hidden="true">→</span></div></Link>)}</div>}
    <div className="pagination">{offset > 0 && <Link className="button" href={`/jobs?scope=${scope}&offset=${Math.max(0, offset - 50)}`}>Previous</Link>}{jobs.length === 50 && <Link className="button" href={`/jobs?scope=${scope}&offset=${offset + 50}`}>Next jobs</Link>}</div>
  </Shell>;
}
