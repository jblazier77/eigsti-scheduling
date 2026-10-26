import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { requireSession } from '../../../lib/session';
import { Shell } from '../../components/shell';
import {NewJobWorkspace} from '../../components/new-job-workspace';
import {workSession} from '../../../lib/work-session';
export const dynamic='force-dynamic';
export default async function NewJob({searchParams}:{searchParams:Promise<{filler?:string}>}) {
  const {actor}=await requireSession();if(!actor.roles.includes('pm'))redirect('/jobs');
  const filler=(await searchParams).filler==='1';
  const {gateway}=await workSession();const [leads,staff]=await Promise.all([gateway.listLeads(),gateway.planningStaff(null)]);
  return <Shell title={filler?'New filler job':'New job'}><Link className="back-link" href="/jobs">Back to jobs</Link><NewJobWorkspace requestId={randomUUID()} leads={leads} staff={staff} filler={filler}/></Shell>;
}
