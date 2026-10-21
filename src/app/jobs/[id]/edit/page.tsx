import { notFound, redirect } from 'next/navigation';
import { requireSession } from '../../../../lib/session';
import { uuidPattern } from '../../../../domain/jobs.ts';
import { Shell } from '../../../components/shell';
import { EditJobForm } from '../../../components/edit-job-form';

export const dynamic = 'force-dynamic';
export default async function EditJob({ params }: { params: Promise<{ id: string }> }) {
  const { actor, gateway } = await requireSession();
  if (!actor.roles.includes('pm')) redirect('/jobs');
  const { id } = await params;
  if (!uuidPattern.test(id)) notFound();
  const job = await gateway.getJob(id);
  if (!job) notFound();
  const { title, customer_name, phone, address, scope, access_notes } = job;
  return <Shell title="Edit job"><div className="form-intro"><h2>Job details</h2><p>Update the customer details, scope and instructions for the crew.</p></div>
    <div className="card form-card"><EditJobForm jobId={id} original={{ title, customer_name, phone, address, scope, access_notes }} /></div></Shell>;
}
