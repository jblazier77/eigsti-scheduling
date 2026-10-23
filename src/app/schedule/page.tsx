import Link from 'next/link';
import {redirect} from 'next/navigation';
import {requireSession} from '../../lib/session';
import {visitSession} from '../../lib/visit-session';
import {companyToday,dateLabel,validDate,visitOnDay} from '../../domain/visits.ts';
import {calendarWindow,uniqueCalendarItems,type CalendarCommitment,type CalendarView} from '../../domain/commitments.ts';
import {AppError} from '../../domain/access.ts';
import {Shell} from '../components/shell';
import {InlineVisit} from '../components/inline-visit';
import {JobMarkers} from '../components/job-markers';
import {CalendarJobHeader} from '../components/calendar-job-header';
export const dynamic='force-dynamic';
export default async function SchedulePage({searchParams}:{searchParams:Promise<{day?:string;view?:string;scope?:string}>}){
 const {actor,gateway:jobsGateway}=await requireSession(),pm=actor.roles.includes('pm'),lead=actor.roles.includes('lead');
 if(!pm&&!lead&&!actor.roles.includes('helper'))redirect('/jobs');
 const query=await searchParams,day=validDate(query.day)?query.day:companyToday(),calendar=calendarWindow(day,query.view),scope=pm&&query.scope==='all'?'all':'mine';
 const {gateway}=await visitSession();
 let commitmentsUnavailable=false;
 const [visitGroups,commitmentGroups]=await Promise.all([
  Promise.all(calendar.chunks.map(range=>gateway.schedule(range.start,range.end,scope==='all'))),
  pm||lead?Promise.all(calendar.chunks.map(range=>jobsGateway.calendarCommitments(range.start,range.end,scope==='all'))).catch(error=>{if(!(error instanceof AppError)||error.code!=='schema_pending')throw error;commitmentsUnavailable=true;return [] as CalendarCommitment[][];}):Promise.resolve([] as CalendarCommitment[][])
 ]);
 const visits=uniqueCalendarItems(visitGroups),commitments=uniqueCalendarItems(commitmentGroups),jobs=await jobsGateway.calendarJobs([...new Set([...visits.map(v=>v.job_id),...commitments.map(c=>c.job_id)])]);
 const url=(date:string,view:CalendarView=calendar.view)=>'/schedule?'+new URLSearchParams({day:date,view,scope});
 const month=calendar.view==='month';
 return <Shell title={pm?'Job schedule':'My schedule'}>
  <form action="/schedule" className="queue-filter"><label>Day<input type="date" name="day" defaultValue={day} required/></label><input type="hidden" name="view" value={calendar.view}/>{pm&&<label>Jobs<select name="scope" defaultValue={scope}><option value="mine">My jobs</option><option value="all">All jobs</option></select></label>}<button className="button">Show schedule</button></form>
  <nav className="schedule-nav" aria-label="Schedule views"><Link className="button" href={url(calendar.previous)}>Previous</Link><Link className="button" href={url(companyToday())}>Today</Link><Link className="button" href={url(calendar.next)}>Next</Link>{([['day','Day'],['week','Week'],['two-weeks','Two weeks'],['month','Month']] as const).map(([view,label])=><Link key={view} className="button" aria-current={view===calendar.view?'page':undefined} href={url(day,view)}>{label}</Link>)}</nav>
  <h2 className="calendar-range">{month?calendar.label:calendar.start===calendar.end?dateLabel(calendar.start):dateLabel(calendar.start)+' – '+dateLabel(calendar.end)}</h2>
  <details className="schedule-notes"><summary>Schedule notes</summary><p className="muted">Central time. Crew work is planned on weekdays. Dates alone allow several jobs per day; optional time blocks reserve named people. <span className="commitment-key">⚑ Subcontractor commitment</span> records a promise or need and does not book our crew.</p></details>
  {commitmentsUnavailable&&<p role="status">Subcontractor commitments are temporarily unavailable. Scheduled crew work is shown below.</p>}
  <div className={month?'schedule-month':calendar.view==='day'?'schedule-day':'schedule-week schedule-multiweek'}>{calendar.days.map(date=>{
   const work=visits.filter(v=>visitOnDay(v,date)).sort((a,b)=>(a.slot==='afternoon'?'12:00':a.start_time??'07:00').localeCompare(b.slot==='afternoon'?'12:00':b.start_time??'07:00')||a.job_title.localeCompare(b.job_title));
   const promises=commitments.filter(c=>c.commitment_date===date);
   return <section className={'schedule-column'+(month&&date.slice(0,7)!==day.slice(0,7)?' outside-month':'')+(date===companyToday()?' calendar-today':'')} key={date} aria-label={dateLabel(date)}><h3><Link href={url(date,'day')}>{month?new Intl.DateTimeFormat('en-US',{weekday:'short',day:'numeric',timeZone:'UTC'}).format(new Date(date+'T12:00:00Z')):dateLabel(date)}</Link></h3>{!work.length&&!promises.length&&<p className="calendar-empty">No jobs scheduled.</p>}
    {work.filter(v=>jobs[v.job_id]).map(v=><article className="card calendar-work" key={v.id}><CalendarJobHeader job={jobs[v.job_id]}/><InlineVisit visit={v} calendarCard scope={<JobMarkers value={jobs[v.job_id]}/>} showStaffingWarning={pm} editable={pm||lead&&v.coordinator_id===actor.id}/></article>)}
    {promises.filter(c=>jobs[c.job_id]).map(c=><article className="calendar-commitment" key={c.id}><CalendarJobHeader job={jobs[c.job_id]} contactId={c.contact_id}/><span className="commitment-key">{'\u2691'} Subcontractor</span><strong>{c.contact_name}</strong>{c.note&&<p className="preserve-lines">{c.note}</p>}<JobMarkers value={jobs[c.job_id]}/>{c.phone_action&&<a href={'tel:'+c.phone_action} aria-label={'Call '+c.contact_name}>Call subcontractor</a>}</article>)}
   </section>;
  })}</div>
 </Shell>;
}
