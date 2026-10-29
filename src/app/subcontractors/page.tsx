import {redirect} from 'next/navigation';
import {requireSession} from '../../lib/session';
import {trades} from '../../domain/job-classification.ts';
import {Shell} from '../components/shell';
import {SubcontractorList} from '../components/subcontractor-list';
export const dynamic='force-dynamic';
export default async function Subcontractors({searchParams}:{searchParams:Promise<{trade?:string;type?:string}>}){
 const {actor,gateway}=await requireSession();if(!actor.roles.some(r=>['pm','admin','lead'].includes(r)))redirect('/jobs');
 const manager=actor.roles.some(r=>r==='pm'||r==='admin'),query=await searchParams;
 const trade=trades.some(t=>t.id===query.trade)?query.trade:undefined,all=await gateway.listSubcontractors(trade),rows=all.filter(r=>!['vendor','subcontractor'].includes(query.type??'')||(r.contact_types??['subcontractor']).includes(query.type as 'vendor'|'subcontractor'));
 return <Shell title="Company contacts"><form action="/subcontractors" className="queue-filter"><label>Type<select name="type" defaultValue={query.type??''}><option value="">All contacts</option><option value="vendor">Vendors</option><option value="subcontractor">Subcontractors</option></select></label><label>Trade<select name="trade" defaultValue={trade??''}><option value="">All trades</option>{trades.map(t=><option key={t.id} value={t.id}>{t.label}</option>)}</select></label><button className="button">Show</button></form><SubcontractorList rows={rows} manager={manager}/>{rows.length===500&&<p className="muted">500 active contacts shown. Archive outdated contacts before adding another.</p>}</Shell>;
}
