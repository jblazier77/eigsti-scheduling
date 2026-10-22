import Link from 'next/link';
import {randomUUID} from 'node:crypto';
import {notFound} from 'next/navigation';
import {requireSession} from '../../../lib/session';
import {uuidPattern} from '../../../domain/jobs.ts';
import {Shell} from '../../components/shell';
import {JobContacts} from '../../components/job-contacts';
import {JobFiles} from '../../components/job-files';
import {JobWorkspace} from '../../components/job-workspace';
import {ClassificationEditor,ReadOnlyClassification} from '../../components/classification-editor';
import {JobMarkers} from '../../components/job-markers';
import {JobScopeDetails} from '../../components/job-scope-details';
import {AttachmentControls} from '../../components/attachment-controls';
export const dynamic='force-dynamic';
export default async function JobDetail({params}:{params:Promise<{id:string}>}) {
  const {actor,gateway}=await requireSession(),{id}=await params;
  if(!uuidPattern.test(id))notFound();
  const job=await gateway.getJob(id);if(!job)notFound();
  const pm=actor.roles.includes('pm'),classification={rain_day:job.rain_day??false,filler:job.filler??false,whole_house:job.whole_house??false,trades:job.trades??[]};
  const original={title:job.title,customer_name:job.customer_name,phone:job.phone,address:job.address,scope:job.scope,access_notes:job.access_notes};
  return <Shell title="Job details" compactTitle>
    <Link className="back-link" href="/jobs">Back to jobs</Link>
    <section className="job-overview"><div className="section-heading"><h1>{job.title}</h1><span className="badge">{job.lifecycle==='open'?'Open job':'Closed job'}</span></div>
      {job.customer_name!==job.title&&<p className="muted">{job.customer_name}</p>}<p className="address">{job.address}</p>
      <JobMarkers value={{rain_day:job.rain_day,filler:job.filler}}/>
      <JobScopeDetails jobId={id} original={original} canEdit={pm}/>
      <div className="job-actions-row"><div className="job-quick-actions"><a className="button" href={'https://www.google.com/maps/dir/?api=1&destination='+encodeURIComponent(job.address)} target="_blank" rel="noreferrer">Directions</a><a className="button" href={'tel:'+job.phone_action} aria-label={'Call '+job.customer_name}>Call</a><a className="button" href={'sms:'+job.phone_action} aria-label={'Text '+job.customer_name}>Text</a></div>{(pm||actor.roles.includes('lead'))&&<AttachmentControls jobId={id}/>}</div>
    </section>
    {job.access_notes&&<aside className="arrival-note"><h2>Before you start</h2><p className="preserve-lines">{job.access_notes}</p></aside>}
    <section className="project-scopes">{pm?<ClassificationEditor jobId={id} original={classification} requestId={randomUUID()}/>:<ReadOnlyClassification value={classification}/>}</section>
    <JobWorkspace jobId={id} isOpen={job.lifecycle==='open'}>
    <JobContacts jobId={id} isPm={pm} canAdd={pm||actor.roles.includes('lead')} gateway={gateway} collapsible primary={{name:job.customer_name,phone:job.phone,phoneAction:job.phone_action}}/>
    </JobWorkspace>
    <JobFiles jobId={id}/>
  </Shell>;
}
