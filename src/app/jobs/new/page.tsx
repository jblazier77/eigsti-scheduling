import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { requireSession } from '../../../lib/session';
import { Shell } from '../../components/shell';
import { NewJobForm } from '../../components/forms';
export const dynamic='force-dynamic';
export default async function NewJob({searchParams}:{searchParams:Promise<{filler?:string}>}) {
  const {actor}=await requireSession();if(!actor.roles.includes('pm'))redirect('/jobs');
  const filler=(await searchParams).filler==='1';
  return <Shell title={filler?'New filler job':'New job'}><Link className="back-link" href="/jobs">Back to jobs</Link><div className="form-intro"><h2>Start with the basics</h2><p>Add the customer, phone and location. Dates are optional and can be planned later.</p></div><div className="card form-card"><NewJobForm requestId={randomUUID()} filler={filler}/></div></Shell>;
}
