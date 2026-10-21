import Link from 'next/link';
import { workSession } from '../../lib/work-session';
import { AppError } from '../../domain/access.ts';

export async function JobWork({ jobId, isOpen }: { jobId: string; isOpen: boolean }) {
  const { gateway, actor } = await workSession();
  let work;
  try { work = await gateway.listWork(jobId); }
  catch (error) {
    if (!(error instanceof AppError) || error.code !== 'schema_pending') throw error;
    return <section className="card"><h3>Work and leads</h3><p className="muted">Work assignments are temporarily unavailable. Please try again later.</p></section>;
  }
  const canEdit = actor.roles.includes('pm') && isOpen;
  return <section className="card"><div className="section-heading"><h3>Work and leads</h3>{canEdit && <Link className="button" href={'/jobs/' + jobId + '/work/new'}>Add work portion</Link>}</div>
    {work.map(item => <article className="contact-entry" key={item.id}><h3>{item.description}</h3><p>{item.lead_name || 'Lead not assigned yet'}{item.completion === 'completed' && <span className="badge">Completed</span>}</p>{canEdit && item.completion === 'open' && <Link className="button" href={'/jobs/' + jobId + '/work/' + item.id + '/edit'}>Edit work and lead<span className="sr-only"> for {item.description}</span></Link>}</article>)}
    <p className="muted">Use one entry for a simple job. When splitting a job, rename “Whole job” to the first portion, then add the other portions that need separate leads.</p>
  </section>;
}
