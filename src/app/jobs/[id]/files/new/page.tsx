import { randomUUID } from 'node:crypto';
import { notFound, redirect } from 'next/navigation';
import { requireSession } from '../../../../../lib/session';
import { uuidPattern } from '../../../../../domain/jobs.ts';
import { Shell } from '../../../../components/shell';
import { FileUpload } from '../../../../components/file-upload';

export const dynamic = 'force-dynamic';
export default async function NewFile({ params }: { params: Promise<{ id: string }> }) {
  const { actor, gateway } = await requireSession();
  if (!actor.roles.includes('pm') && !actor.roles.includes('lead')) redirect('/jobs');
  const { id } = await params;
  if (!uuidPattern.test(id)) notFound();
  const job = await gateway.getJob(id);
  if (!job) notFound();
  return <Shell title="Upload job file"><div className="form-intro"><h2>{job.title}</h2><p>Add a plan, document or site photo.</p></div><div className="card form-card"><FileUpload jobId={id} requestId={randomUUID()} /></div></Shell>;
}
