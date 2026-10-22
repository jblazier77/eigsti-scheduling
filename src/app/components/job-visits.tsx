import { randomUUID } from 'node:crypto';
import { visitSession } from '../../lib/visit-session';
import { AppError } from '../../domain/access.ts';
import { VisitEditor } from './visit-editor';
import { InlineVisit } from './inline-visit';
export async function JobVisits({ jobId, isOpen }: { jobId: string; isOpen: boolean }) {
  const { actor, gateway } = await visitSession();
  const pm = actor.roles.includes('pm');
  try {
    const visits = await gateway.jobVisits(jobId);
    const work = isOpen && (pm || actor.roles.includes('lead')) ? (await gateway.listWork(jobId)).filter(w => w.completion === 'open' && (pm || w.responsible_lead === actor.id)) : [];
    const leads = work.length && pm ? await gateway.listLeads() : [];
    return <section className="card"><h2>Scheduled visits</h2>
      {!visits.length && <p>No visits planned yet.</p>}
      {visits.map(visit => <article id={'visit-' + visit.id} key={visit.id} className="visit-summary"><InlineVisit visit={visit} editable={isOpen && (pm || actor.roles.includes('lead') && visit.coordinator_id === actor.id)} /></article>)}
      {!!work.length && <details><summary className="button">Plan a visit</summary><VisitEditor work={work} leads={leads} pm={pm} actorId={actor.id} requestId={randomUUID()} /></details>}
    </section>;
  } catch (error) { if (error instanceof AppError && error.code === 'schema_pending') return <section className="card"><h2>Scheduled visits</h2><p>Scheduling is temporarily unavailable.</p></section>; throw error; }
}