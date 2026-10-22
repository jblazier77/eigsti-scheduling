'use client';
import { useState } from 'react';
import { loadVisitEditorAction, type VisitEditorData } from '../visit-editor-actions';
import { CancelVisit } from './visit-editor';
import { VisitCardEditor } from './visit-card-editor';
import { DetailIcon } from './detail-icons';
import { dateLabel, slotLabel, type Visit } from '../../domain/visits.ts';
export function InlineVisit({visit:initialVisit,editable,showJob=false,hideWorkTitle=false,compact=false}:{visit:Visit;editable:boolean;showJob?:boolean;hideWorkTitle?:boolean;compact?:boolean}) {
  const [data,setData]=useState<VisitEditorData|null>(null),[loadedSignature,setLoadedSignature]=useState('');
  const [loading,setLoading]=useState(false),[message,setMessage]=useState('');
  const visit=data&&loadedSignature===initialVisit.updated_at?data.visit:initialVisit;
  const vacant=Math.max(0,visit.required_helpers-visit.participants.filter(p=>p.duty==='helping').length);
  async function load(){
    if(loading)return;setLoading(true);setMessage('');
    try{const result=await loadVisitEditorAction(initialVisit.id);if(result.data){setData(result.data);setLoadedSignature(initialVisit.updated_at);}else setMessage(result.message??'Could not load this plan.');}
    catch{setMessage('Could not load this plan. Try again.');}finally{setLoading(false);}
  }
  return <div className={'inline-visit'+(compact?' compact-work-plan':'')}>
    {!hideWorkTitle&&<h3>{visit.description}</h3>}{showJob&&<p>{visit.job_title}</p>}
    <div className="schedule-line"><strong>{dateLabel(visit.start_date)}{visit.end_date!==visit.start_date?' - '+dateLabel(visit.end_date):''}</strong><span>{slotLabel(visit)}</span><span className="badge">{visit.state==='completed'?'Completed':visit.state==='cancelled'?'Cancelled':visit.certainty==='confirmed'?'Confirmed':'Tentative'}</span></div>
    <p className="crew-line">{visit.participants.map(p=>p.name+(p.duty==='leading'?' (lead)':' (helping)')).join(', ')||'No crew assigned'}</p>
    {visit.state==='planned'&&vacant>0&&<p className="staffing-notice">{vacant} helper {vacant===1?'space':'spaces'} to fill</p>}
    {visit.state==='planned'&&visit.day_conflicts>0&&<p className="form-message">Other plans share this day. Check the workload.</p>}
    {editable&&visit.state==='planned'&&<div className="visit-actions">
      <details name={'visit-action-'+visit.id} className="inline-visit-editor" onToggle={e=>{if(e.currentTarget.open&&(!data||loadedSignature!==initialVisit.updated_at))void load();}}><summary className={compact?'icon-action edit-details-icon':'button'} title={compact?'Edit dates and crew':undefined} aria-label={compact?'Edit dates and crew: '+visit.description:undefined}>{compact?<DetailIcon kind="edit"/>:<>Edit plan &amp; crew</>}</summary>
        {loading&&<p role="status">Loading plan...</p>}{message&&<div role="status"><p>{message}</p><button className="button" type="button" onClick={()=>void load()} disabled={loading}>Try again</button></div>}
        {data&&<div className="inline-visit-panels"><VisitCardEditor visit={data.visit} leads={data.leads} options={data.options} pm={data.pm} requestId={data.requests.dates} onSaved={v=>{setData(d=>d?{...d,visit:v}:d);void load();}}/><section className="inline-visit-cancel"><CancelVisit visit={data.visit} requestId={data.requests.cancel}/></section></div>}
      </details>
    </div>}
  </div>;
}
