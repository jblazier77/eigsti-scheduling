import { randomUUID } from 'node:crypto';
import { notFound, redirect } from 'next/navigation';
import { requireSession } from '../../../../../lib/session';
import { uuidPattern } from '../../../../../domain/jobs.ts';
import { Shell } from '../../../../components/shell';
import { ContactForm } from '../../../../components/contact-form';

export const dynamic = 'force-dynamic';
export default async function NewContact({ params }: { params: Promise<{ id: string }> }) {
  const { actor, gateway } = await requireSession();
  if (!actor.roles.includes('pm') && !actor.roles.includes('lead')) redirect('/jobs');
  const { id } = await params;
  if (!uuidPattern.test(id)) notFound();
  const job = await gateway.getJob(id);
  if (!job) notFound();
  return <Shell title="Add job contact"><div className="form-intro"><h2>{job.title}</h2><p>Add someone the crew may need to reach for this job. Only a name is required.</p></div><div className="card form-card"><ContactForm jobId={id} requestId={randomUUID()} /></div></Shell>;
}
