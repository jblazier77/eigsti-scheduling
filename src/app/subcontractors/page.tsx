import { randomUUID } from 'node:crypto';
import { redirect } from 'next/navigation';
import { requireSession } from '../../lib/session';
import { trades } from '../../domain/job-classification.ts';
import { Shell } from '../components/shell';
import { JobMarkers } from '../components/job-markers';
import { SubcontractorEditor } from '../components/subcontractor-editor';
export const dynamic='force-dynamic';
export default async function Subcontractors({searchParams}:{searchParams:Promise<{trade?:string}>}) {
  const {actor,gateway}=await requireSession();
  if(!actor.roles.some(r=>['pm','admin','lead'].includes(r)))redirect('/jobs');
  const manager=actor.roles.some(r=>r==='pm'||r==='admin'),query=await searchParams;
  const trade=trades.some(t=>t.id===query.trade)?query.trade:undefined;
  const rows=await gateway.listSubcontractors(trade);
  return <Shell title="Subcontractors"><form action="/subcontractors" className="queue-filter"><label>Trade<select name="trade" defaultValue={trade??''}><option value="">All trades</option>{trades.map(t=><option key={t.id} value={t.id}>{t.label}</option>)}</select></label><button className="button">Show contacts</button></form>
    {manager&&<details className="card"><summary className="button">+ Add subcontractor</summary><SubcontractorEditor requestId={randomUUID()}/></details>}
    {!rows.length&&<p>No subcontractors match this trade.</p>}
    {rows.map(s=><article key={s.id} className="card"><h2>{s.name}</h2><JobMarkers value={{trades:s.trades}} expanded/>{s.phone_action&&<p><a className="button" href={'tel:'+s.phone_action}>Call {s.phone}</a></p>}{s.email&&<p><a href={'mailto:'+encodeURIComponent(s.email)}>{s.email}</a></p>}{manager&&<details><summary className="button">Edit contact &amp; trades</summary><SubcontractorEditor original={s} requestId={randomUUID()}/></details>}</article>)}
    {rows.length===500&&<p className="muted">500 active contacts shown. Archive outdated contacts before adding another.</p>}
  </Shell>;
}
