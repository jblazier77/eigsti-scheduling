import { notFound, redirect } from 'next/navigation';
import { requireSession } from '../../../../../../lib/session';
import { workSession } from '../../../../../../lib/work-session';
import { uuidPattern } from '../../../../../../domain/jobs.ts';
import { Shell } from '../../../../../components/shell';
import { WorkForm } from '../../../../../components/work-form';

export const dynamic = 'force-dynamic';
export default async function EditWork({ params }: { params: Promise<{ id: string; workId: string }> }) {
  const { actor } = await requireSession();
  if (!actor.roles.includes('pm')) redirect('/jobs');
  const { id, workId } = await params;
  if (!uuidPattern.test(id) || !uuidPattern.test(workId)) notFound();
  const { gateway } = await workSession(true);
  const job = await gateway.getJob(id);
  if (!job || job.lifecycle !== 'open') notFound();
  const work = (await gateway.listWork(id)).find(work => work.id === workId);
  if (!work || work.completion !== 'open') notFound();
  const leads = await gateway.listLeads();
  return <Shell title="Edit work and lead"><div className="form-intro"><p>{job.title}</p></div><section className="card form-card"><WorkForm jobId={id} workId={workId} original={{ description: work.description, responsible_lead: work.responsible_lead }} originalLeadName={work.lead_name} leads={leads} /></section></Shell>;
}
