import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { requireSession } from '../../../lib/session';
import { Shell } from '../../components/shell';
import { NewJobForm } from '../../components/forms';

export const dynamic = 'force-dynamic';
export default async function NewJob() {
  const { actor } = await requireSession();
  if (!actor.roles.includes('pm')) redirect('/jobs');
  return <Shell title="New job"><Link className="back-link" href="/jobs">← Back to jobs</Link><div className="form-intro"><p className="eyebrow">START WITH THE BASICS</p><h2>Three details. Ready to go.</h2><p>Everything stays with the job as your team’s work moves forward.</p></div><div className="card form-card"><NewJobForm requestId={randomUUID()} /></div></Shell>;
}
