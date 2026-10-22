import type { Actor } from './access.ts';
import type { WorkProgress } from './progress.ts';
import type { Visit } from './visits.ts';

// Presentation only: every input was already authorized by the job-scoped RPCs.
// Helpers' planned participation matters even when another person owns the work.
export function groupJobWork(actor:Actor,work:WorkProgress[],visits:Visit[]) {
  const byWork=new Map<string,Visit[]>();
  for(const visit of visits){const list=byWork.get(visit.work_item_id)??[];list.push(visit);byWork.set(visit.work_item_id,list);}
  for(const list of byWork.values())list.sort((a,b)=>a.start_date.localeCompare(b.start_date)||a.id.localeCompare(b.id));
  const active=work.filter(w=>w.completion==='open'||w.returns.some(r=>r.state==='open')||(byWork.get(w.id)??[]).some(v=>v.state==='planned'));
  const mine=(w:WorkProgress)=>actor.roles.includes('pm')||w.responsible_lead===actor.id||(byWork.get(w.id)??[]).some(v=>v.state==='planned'&&(v.coordinator_id===actor.id||v.participants.some(p=>p.id===actor.id)));
  return{primary:active.filter(mine),other:active.filter(w=>!mine(w)),completed:work.filter(w=>!active.includes(w)),byWork};
}
