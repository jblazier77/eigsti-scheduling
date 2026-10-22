import Link from 'next/link';
import { workSession } from '../../lib/work-session';
import { AppError } from '../../domain/access.ts';
import type { LeadOption } from '../../domain/work.ts';
import { InlineWorkEditor } from './work-form';

export async function JobWork({ jobId, isOpen }: { jobId: string; isOpen: boolean }) {
  const { gateway, actor } = await workSession();
  const canEdit = actor.roles.includes('pm') && isOpen;
  let work;
  let leads: LeadOption[] = [];
  try {
    work = await gateway.listWork(jobId);
    if (canEdit) leads = await gateway.listLeads();
  }
  catch (error) {
    if (!(error instanceof AppError) || error.code !== 'schema_pending') throw error;
    return <section className="card"><h3>Work and leads</h3><p className="muted">Work assignments are temporarily unavailable. Please try again later.</p></section>;
  }
  return <section className="card"><div className="section-heading"><h3>Work and leads</h3>{canEdit && <Link className="button" href={'/jobs/' + jobId + '/work/new'}>Add work portion</Link>}</div>
    {work.map(item => <article className="contact-entry" key={item.id}>{canEdit && item.completion === 'open'
      ? <InlineWorkEditor jobId={jobId} workId={item.id} original={{ description: item.description, responsible_lead: item.responsible_lead }} originalLeadName={item.lead_name} leads={leads} />
      : <><h3>{item.description}</h3><p>{item.lead_name || 'Lead not assigned yet'}{item.completion === 'completed' && <span className="badge">Completed</span>}</p></>}</article>)}
    <p className="muted">Use one entry for a simple job. When splitting a job, rename “Whole job” to the first portion, then add the other portions that need separate leads.</p>
  </section>;
}
