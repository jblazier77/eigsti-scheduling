import Link from 'next/link';
import { listJobs } from '../../domain/jobs.ts';
import { requireSession } from '../../lib/session';
import { Shell } from '../components/shell';
import {JobPriority} from '../components/planning-review';
import {dateLabel} from '../../domain/visits.ts';
import { JobMarkers } from '../components/job-markers';
export const dynamic='force-dynamic';
export default async function Jobs({searchParams}:{searchParams:Promise<{scope?:string;offset?:string;kind?:string;state?:string}>}) {
  const {actor,gateway}=await requireSession(),query=await searchParams,pm=actor.roles.includes('pm');
  const scope=pm&&query.scope==='all'?'all':'mine',kind=['rain','filler'].includes(query.kind??'')?query.kind!:'all';
  const offset=/^\d+$/.test(query.offset??'')?Math.min(Number(query.offset),100000):0;
  const state=pm&&query.state==='archived'?'archived':'active';
  const jobs=await listJobs(actor,{scope,kind,state,offset:String(offset)},gateway);
  const help=pm&&state==='active'?await gateway.helpRequests():[];
  const url=(s=scope,k=kind,o=0,t=state)=>'/jobs?'+new URLSearchParams({scope:s,kind:k,offset:String(o),state:t});
  return <Shell title={state==='archived'?'Archived jobs':kind==='filler'?'Filler work':kind==='rain'?'Rain-day options':pm&&scope==='all'?'All Jobs':'My Jobs'}>
    <div className="toolbar">{pm&&<div className="segmented" aria-label="Job ownership"><Link className={scope==='mine'?'selected':''} href={url('mine')}>My Jobs</Link><Link className={scope==='all'?'selected':''} href={url('all')}>All Jobs</Link></div>}{pm&&<Link className="button primary" href={kind==='filler'?'/jobs/new?filler=1':'/jobs/new'}>+ {kind==='filler'?'Filler job':'New job'}</Link>}</div>
    {pm&&<nav className="segmented" aria-label="Job status"><Link className={state==='active'?'selected':''} href={url(scope,kind,0,'active')}>Active</Link><Link className={state==='archived'?'selected':''} href={url(scope,kind,0,'archived')}>Archived</Link></nav>}
    <nav className="schedule-nav" aria-label="Job tags">{[['all','All work'],['rain','Rain day'],['filler','Filler']].map(([k,label])=><Link className="button" key={k} href={url(scope,k)} aria-current={kind===k?'page':undefined}>{label}</Link>)}</nav>
    {kind!=='all'&&<p className="muted">Jobs you can access. Tags help find work; check readiness before scheduling.</p>}
    {pm&&state==='active'&&<section className="card help-dashboard" aria-label="Help requested on my jobs"><div className="section-heading"><h2>Help needed</h2><span className="badge">{help.length} {help.length===1?'request':'requests'}</span></div>{!help.length?<p className="muted">No unfilled help requests on your jobs.</p>:<ul className="help-request-list">{help.map(h=><li key={h.visit_id??h.work_id}><Link href={'/jobs/'+h.job_id+'#'+(h.visit_id?'visit-'+h.visit_id:'work-'+h.work_id)}><strong>{h.title}</strong><span>{h.description}</span><span>{h.start_date?dateLabel(h.start_date)+(h.end_date!==h.start_date?' – '+dateLabel(h.end_date!):''):'Undated'} · {h.assigned}/{h.requested} assigned <strong className="staffing-notice">⚠ {h.missing} needed</strong></span></Link></li>)}</ul>}</section>}
    <div className="section-heading"><h2>{state==='archived'?'Restore a job for additional work':kind==='all'?'Jobs to keep moving':'Available list'}</h2><span className="muted">{jobs.length}{jobs.length===50?'+':''} shown</span></div>
    {!jobs.length?<div className="card empty"><h2>{state==='archived'?'No archived jobs':kind==='all'?'No jobs here yet':'No matching jobs'}</h2><p>{state==='archived'?'Archived jobs will appear here. Restore the same job when more work is needed.':kind!=='all'?'Try another filter or check job assignments.':pm?'Create a job with a customer name, phone and address.':'Assigned jobs will appear here.'}</p></div>:<div className="job-grid">{jobs.map(job=><article key={job.id} className="job-card">{job.lifecycle!=='open'&&<div className="job-top"><span className="badge">{job.lifecycle==='archived'?'Archived':'Closed job'}</span></div>}<h2><Link href={'/jobs/'+job.id}>{job.title}</Link></h2><p>{job.customer_name}</p><p className="muted">{job.address}</p><JobPriority jobId={job.id} priority={job.priority??null} editable={pm&&state==='active'}/><JobMarkers value={job}/></article>)}</div>}
    <div className="pagination">{offset>0&&<Link className="button" href={url(scope,kind,Math.max(0,offset-50))}>Previous</Link>}{jobs.length===50&&<Link className="button" href={url(scope,kind,offset+50)}>Next jobs</Link>}</div>
  </Shell>;
}

