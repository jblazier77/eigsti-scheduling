import { randomUUID } from 'node:crypto';
import { notFound, redirect } from 'next/navigation';
import { requireSession } from '../../../../../lib/session';
import { workSession } from '../../../../../lib/work-session';
import { uuidPattern } from '../../../../../domain/jobs.ts';
import { Shell } from '../../../../components/shell';
import { WorkForm } from '../../../../components/work-form';

export const dynamic = 'force-dynamic';
export default async function NewWork({ params }: { params: Promise<{ id: string }> }) {
  const { actor } = await requireSession();
  if (!actor.roles.includes('pm')) redirect('/jobs');
  const { id } = await params;
  if (!uuidPattern.test(id)) notFound();
  const { gateway } = await workSession(true);
  const job = await gateway.getJob(id);
  if (!job || job.lifecycle !== 'open') notFound();
  const leads = await gateway.listLeads();
  return <Shell title="Add work"><div className="form-intro"><p>{job.title}</p><p>Add work now or later. Dates and staffing can be planned whenever needed.</p></div><section className="card form-card"><WorkForm jobId={id} requestId={randomUUID()} original={{ description: '', responsible_lead: null }} leads={leads} /></section></Shell>;
}

