import { randomUUID } from 'node:crypto';
import { workSession } from '../../lib/work-session';
import { AppError } from '../../domain/access.ts';
import type { LeadOption } from '../../domain/work.ts';
import { WorkCardEditor } from './work-card-editor';

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
  return <section className="card">{canEdit
    ? <WorkCardEditor jobId={jobId} work={work} leads={leads} requestId={randomUUID()} />
    : <><h3>Work and leads</h3>{work.map(item => <article className="contact-entry" key={item.id}><h3>{item.description}</h3><p>{item.lead_name || 'Lead not assigned yet'}{item.completion === 'completed' && <span className="badge">Completed</span>}</p></article>)}</>}
    <p className="muted">Use one entry for a simple job. When splitting a job, rename “Whole job” to the first portion, then add the other portions that need separate leads.</p>
  </section>;
}
