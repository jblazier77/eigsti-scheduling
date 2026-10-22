import Link from 'next/link';
import { notFound } from 'next/navigation';
import { requireSession } from '../../../lib/session';
import { uuidPattern } from '../../../domain/jobs.ts';
import { Shell } from '../../components/shell';
import { JobContacts } from '../../components/job-contacts';
import { JobFiles } from '../../components/job-files';
import { JobWork } from '../../components/job-work';

export const dynamic = 'force-dynamic';
export default async function JobDetail({ params }: { params: Promise<{ id: string }> }) {
  const { actor, gateway } = await requireSession();
  const { id } = await params;
  if (!uuidPattern.test(id)) notFound();
  // RLS applies to this ID lookup as well; hidden/absent jobs share the same 404.
  const job = await gateway.getJob(id);
  if (!job) notFound();
  return <Shell title="Job details">
    <div className="toolbar detail-toolbar"><Link className="back-link" href="/jobs">Back to jobs</Link>
      {actor.roles.includes('pm') && <Link className="button" href={'/jobs/' + id + '/edit'}>Edit job details</Link>}</div>
    <section className="detail-heading"><span className="badge">{job.lifecycle === 'open' ? 'Open job' : 'Closed job'}</span><h2>{job.title}</h2><p>{job.customer_name}</p></section>
    <div className="card"><h3>Where we're working</h3><p className="address">{job.address}</p><a className="button full" href={'https://www.google.com/maps/dir/?api=1&destination=' + encodeURIComponent(job.address)} target="_blank" rel="noreferrer">Open directions</a></div>
    <div className="card"><h3>Customer contact</h3><p>{job.customer_name}<br /><span className="muted">{job.phone}</span></p><div className="two-actions"><a className="button primary" href={'tel:' + job.phone_action}>Call customer</a><a className="button" href={'sms:' + job.phone_action}>Text customer</a></div></div>
    <div className="card"><h3>Scope</h3><p className="preserve-lines">{job.scope || 'No scope added yet.'}</p></div>
    {job.access_notes && <div className="card"><h3>Access and preparation</h3><p className="preserve-lines">{job.access_notes}</p></div>}
    <JobWork jobId={id} isOpen={job.lifecycle === 'open'} />
    <JobContacts jobId={id} isPm={actor.roles.includes('pm')} canAdd={actor.roles.includes('pm') || actor.roles.includes('lead')} gateway={gateway} />
    <JobFiles jobId={id} />
  </Shell>;
}
