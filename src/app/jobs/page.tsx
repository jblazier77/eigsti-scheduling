import Link from 'next/link';
import { listJobs } from '../../domain/jobs.ts';
import { requireSession } from '../../lib/session';
import { Shell } from '../components/shell';
import { JobMarkers } from '../components/job-markers';
export const dynamic='force-dynamic';
export default async function Jobs({searchParams}:{searchParams:Promise<{scope?:string;offset?:string;kind?:string}>}) {
  const {actor,gateway}=await requireSession(),query=await searchParams,pm=actor.roles.includes('pm');
  const scope=pm&&query.scope==='all'?'all':'mine',kind=['rain','filler'].includes(query.kind??'')?query.kind!:'all';
  const offset=/^\d+$/.test(query.offset??'')?Math.min(Number(query.offset),100000):0;
  const jobs=await listJobs(actor,{scope,kind,offset:String(offset)},gateway);
  const url=(s=scope,k=kind,o=0)=>'/jobs?'+new URLSearchParams({scope:s,kind:k,offset:String(o)});
  return <Shell title={kind==='filler'?'Filler work':kind==='rain'?'Rain-day options':pm&&scope==='all'?'All Jobs':'My Jobs'}>
    <div className="toolbar">{pm&&<div className="segmented" aria-label="Job ownership"><Link className={scope==='mine'?'selected':''} href={url('mine')}>My Jobs</Link><Link className={scope==='all'?'selected':''} href={url('all')}>All Jobs</Link></div>}{pm&&<Link className="button primary" href={kind==='filler'?'/jobs/new?filler=1':'/jobs/new'}>+ {kind==='filler'?'Filler job':'New job'}</Link>}</div>
    <nav className="schedule-nav" aria-label="Job tags">{[['all','All work'],['rain','Rain day'],['filler','Filler']].map(([k,label])=><Link className="button" key={k} href={url(scope,k)} aria-current={kind===k?'page':undefined}>{label}</Link>)}</nav>
    {kind!=='all'&&<p className="muted">Open jobs you can access. Tags help find work; check readiness before scheduling.</p>}
    <div className="section-heading"><h2>{kind==='all'?'Jobs to keep moving':'Available list'}</h2><span className="muted">{jobs.length}{jobs.length===50?'+':''} shown</span></div>
    {!jobs.length?<div className="card empty"><h2>{kind==='all'?'No jobs here yet':'No matching jobs'}</h2><p>{kind!=='all'?'Try another filter or check job assignments.':pm?'Create a job with a customer name, phone and address.':'Assigned jobs will appear here.'}</p></div>:<div className="job-grid">{jobs.map(job=><article key={job.id} className="job-card"><div className="job-top"><span className="badge">{job.lifecycle==='open'?'Open job':'Closed job'}</span></div><h2><Link href={'/jobs/'+job.id}>{job.title}</Link></h2><p>{job.customer_name}</p><p className="muted">{job.address}</p><JobMarkers value={job}/><Link className="card-link" href={'/jobs/'+job.id}>Open job details</Link></article>)}</div>}
    <div className="pagination">{offset>0&&<Link className="button" href={url(scope,kind,Math.max(0,offset-50))}>Previous</Link>}{jobs.length===50&&<Link className="button" href={url(scope,kind,offset+50)}>Next jobs</Link>}</div>
  </Shell>;
}

