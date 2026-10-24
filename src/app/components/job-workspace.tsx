import { randomUUID } from 'node:crypto';
import { visitSession } from '../../lib/visit-session';
import { groupJobWork } from '../../domain/job-work-layout.ts';
import type { WorkProgress } from '../../domain/progress.ts';
import type { Actor } from '../../domain/access.ts';
import type { LeadOption } from '../../domain/work.ts';
import type { Visit } from '../../domain/visits.ts';
import { dateLabel } from '../../domain/visits.ts';
import { InlineVisit } from './inline-visit';
import { VisitEditor } from './visit-editor';
import { WorkTools } from './work-tools';
import { WorkMaterials } from './work-materials';
import { materialLabels,type WorkStatus } from '../../domain/planning-updates.ts';

export async function JobWorkspace({jobId,isOpen,children}:{jobId:string;isOpen:boolean;children?:React.ReactNode}) {
  const {actor,gateway}=await visitSession(),pm=actor.roles.includes('pm');
  const [work,visits,editableWork,status]=await Promise.all([gateway.jobProgress(jobId),gateway.jobVisits(jobId),gateway.listWork(jobId),gateway.workStatus(jobId)]);
  const leads=pm&&isOpen?await gateway.listLeads():[];
  const grouped=groupJobWork(actor,work,visits);
  const card=(w:WorkProgress)=> <WorkSection key={w.id} work={w} visits={grouped.byWork.get(w.id)??[]} actor={actor} leads={leads} isOpen={isOpen} status={status.find(s=>s.id===w.id)}/>;
  const historicalVisits=visits.filter(v=>v.state!=='planned');
  return <>
    <section className="job-workspace"><WorkTools jobId={jobId} work={editableWork} leads={leads} editable={pm&&isOpen} count={grouped.primary.length} title={pm?'Project work':'My work'}/>
      {!grouped.primary.length&&<p className="muted">{pm?'No work added yet.':'No work or scheduled assignments for you on this job.'}</p>}
      {grouped.primary.map(card)}
    </section>
    {!!grouped.other.length&&<details className="support-section other-work"><summary>Other project work <span className="muted">{grouped.other.length}</span></summary>{grouped.other.map(w=><details className="other-work-entry" key={w.id}><summary>{w.description}<span className="muted">{w.lead_name??'Unassigned'}</span></summary>{card(w)}</details>)}</details>}
    {children}
    {(grouped.completed.length>0||historicalVisits.length>0)&&<details className="support-section"><summary>Work history <span className="muted">{grouped.completed.length} items / {historicalVisits.length} scheduled entries</span></summary>
      {grouped.completed.map(card)}
      {historicalVisits.map(v=><article id={'visit-'+v.id} key={v.id} className="visit-summary"><InlineVisit visit={v} editable={false}/></article>)}
      {!grouped.completed.length&&!historicalVisits.length&&<p className="muted">No work history yet.</p>}
    </details>}
  </>;
}
function WorkSection({work:w,visits,actor,leads,isOpen,status}:{work:WorkProgress;visits:Visit[];actor:Actor;leads:LeadOption[];isOpen:boolean;status?:WorkStatus}) {
  const pm=actor.roles.includes('pm'),manage=isOpen&&(pm||actor.roles.includes('lead')&&w.responsible_lead===actor.id);
  const planned=visits.filter(v=>v.state==='planned');
  // Earlier follow-up records remain readable as notes on their original work.
  // New additions use the one ordinary Add work flow, never a second work type.
  const notes=w.returns.map(r=>({id:r.id,note:r.note,owner:r.owner_name,date:r.due_date}));
  if(w.remaining_note&&!notes.some(n=>n.note.trim()===w.remaining_note.trim()))notes.unshift({id:'remaining',note:w.remaining_note,owner:'',date:null});
  return <article className="card unified-work" id={'work-'+w.id}>
    <div className="section-heading work-card-heading"><div><h3>{w.description}</h3><p className="muted work-owner">{w.lead_name??'No lead assigned'}</p></div><span className={'badge '+(status?.readiness!=='ready'&&status?'waiting-badge':'')}>{w.completion==='completed'?'Completed':status?.material_status&&['need_to_order','ordered','in_stock'].includes(status.material_status)?materialLabels[status.material_status]:status?.readiness==='ready'?'Ready':status?.waiting_until?'Expected '+dateLabel(status.waiting_until):status?'Waiting':'Open'}</span></div>
    {status&&<WorkMaterials status={status} canEdit={manage&&w.completion==='open'}/>}
    {!!notes.length&&<div className="work-notes">{notes.map(note=><div key={note.id}><p className="preserve-lines work-remaining">{note.note}</p>{(note.owner||note.date)&&<p className="muted">{note.owner}{note.date?' / Target: '+dateLabel(note.date):''}</p>}</div>)}</div>}
    {planned.map(v=><section key={v.id} id={'visit-'+v.id} className="work-schedule"><InlineVisit visit={v} hideWorkTitle compact editable={isOpen&&(pm||actor.roles.includes('lead')&&v.coordinator_id===actor.id)}/></section>)}
    {!planned.length&&w.completion==='open'&&<p className="muted work-unscheduled">No dates yet{status?.default_helpers?' / '+status.default_helpers+(status.default_helpers===1?' helper requested':' helpers requested'):''}</p>}
    {manage&&w.completion==='open'&&<details className="inline-action add-work-date"><summary>+ Add date</summary><VisitEditor work={[{id:w.id,description:w.description}]} leads={[...leads].sort((a,b)=>Number(b.id===w.responsible_lead)-Number(a.id===w.responsible_lead))} pm={pm} actorId={actor.id} initialHelpers={status?.default_helpers??0} requestId={randomUUID()}/></details>}
  </article>;
}


