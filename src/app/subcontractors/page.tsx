import {redirect} from 'next/navigation';
import {requireSession} from '../../lib/session';
import {trades} from '../../domain/job-classification.ts';
import {Shell} from '../components/shell';
import {SubcontractorList} from '../components/subcontractor-list';
export const dynamic='force-dynamic';
export default async function Subcontractors({searchParams}:{searchParams:Promise<{trade?:string}>}){
 const {actor,gateway}=await requireSession();if(!actor.roles.some(r=>['pm','admin','lead'].includes(r)))redirect('/jobs');
 const manager=actor.roles.some(r=>r==='pm'||r==='admin'),query=await searchParams;
 const trade=trades.some(t=>t.id===query.trade)?query.trade:undefined,rows=await gateway.listSubcontractors(trade);
 return <Shell title="Subcontractors"><form action="/subcontractors" className="queue-filter"><label>Trade<select name="trade" defaultValue={trade??''}><option value="">All trades</option>{trades.map(t=><option key={t.id} value={t.id}>{t.label}</option>)}</select></label><button className="button">Show</button></form><SubcontractorList rows={rows} manager={manager}/>{rows.length===500&&<p className="muted">500 active contacts shown. Archive outdated contacts before adding another.</p>}</Shell>;
}
