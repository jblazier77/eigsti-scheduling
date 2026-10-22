import { randomUUID } from 'node:crypto';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { requireSession } from '../../lib/session';
import { queueSession } from '../../lib/queue-session';
import { readQueue } from '../../domain/queues.ts';
import { uuidPattern } from '../../domain/jobs.ts';
import { AppError } from '../../domain/access.ts';
import { Shell } from '../components/shell';
import { QueueEditor } from '../components/queue-editor';

export const dynamic = 'force-dynamic';
export default async function QueuePage({ searchParams }: { searchParams: Promise<{ lead?: string }> }) {
  const { actor, gateway:jobsGateway } = await requireSession();
  const pm = actor.roles.includes('pm');
  if (!pm && !actor.roles.includes('lead')) redirect('/jobs');
  const query = await searchParams;
  if (!pm && query.lead && query.lead !== actor.id) redirect('/queue');
  const { gateway } = await queueSession();
  let leads, queue;
  try {
    leads = pm ? await gateway.listLeads() : [];
    const leadId = pm ? query.lead ?? leads[0]?.id : actor.id;
    if (leadId && uuidPattern.test(leadId)) queue = await readQueue(actor, leadId, gateway);
  } catch (error) {
    if (!(error instanceof AppError) || !['schema_pending', 'job_unavailable', 'invalid_input'].includes(error.code)) throw error;
    return <Shell title="Lead queue"><div className="card"><p>{error.message}</p><Link className="button" href="/jobs">Back to jobs</Link></div></Shell>;
  }
  const markers=await jobsGateway.jobMarkers(queue?.items.map(i=>i.job_id)??[]);
  return <Shell title={pm ? 'Lead queues' : 'My queue'}>
    {pm && <form action="/queue" className="queue-filter"><div><label htmlFor="queue-lead">Lead</label><select id="queue-lead" name="lead" defaultValue={queue?.lead_id ?? ''}>{leads.map(lead => <option key={lead.id} value={lead.id}>{lead.display_name}</option>)}</select></div><button className="button" disabled={!leads.length}>Show queue</button></form>}
    {queue ? <QueueEditor key={queue.lead_id} queue={queue} requestId={randomUUID()} markers={markers} /> : <div className="card"><h2>{leads.length ? 'Choose a lead' : 'No active leads yet'}</h2><p>Assign work portions to active lead accounts to start their queues.</p></div>}
  </Shell>;
}
