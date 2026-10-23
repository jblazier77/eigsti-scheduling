'use client';
import { useId, useState, type ReactNode } from 'react';
import { loadVisitEditorAction, type VisitEditorData } from '../visit-editor-actions';
import { CancelVisit } from './visit-editor';
import { VisitCardEditor } from './visit-card-editor';
import { DetailIcon } from './detail-icons';
import { StaffingWarning } from './staffing-warning';
import { dateLabel, slotLabel, type Visit } from '../../domain/visits.ts';
export function InlineVisit({visit:initialVisit,editable,showJob=false,hideWorkTitle=false,compact=false,showStaffingWarning=false,calendarCard=false,scope}:{visit:Visit;editable:boolean;showJob?:boolean;hideWorkTitle?:boolean;compact?:boolean;showStaffingWarning?:boolean;calendarCard?:boolean;scope?:ReactNode}) {
  const editorId=useId();
  const [editorOpen,setEditorOpen]=useState(false);
  const [data,setData]=useState<VisitEditorData|null>(null),[loadedSignature,setLoadedSignature]=useState('');
  const [loading,setLoading]=useState(false),[message,setMessage]=useState('');
  const visit=data&&loadedSignature===initialVisit.updated_at?data.visit:initialVisit;
  const vacant=Math.max(0,visit.required_helpers-visit.participants.filter(p=>p.duty==='helping').length);
  async function load(){
    if(loading)return;setLoading(true);setMessage('');
    try{const result=await loadVisitEditorAction(initialVisit.id);if(result.data){setData(result.data);setLoadedSignature(initialVisit.updated_at);}else setMessage(result.message??'Could not load this plan.');}
    catch{setMessage('Could not load this plan. Try again.');}finally{setLoading(false);}
  }
  const panels=<>{loading&&<p role="status">Loading plan...</p>}{message&&<div role="status"><p>{message}</p><button className="button" type="button" onClick={()=>void load()} disabled={loading}>Try again</button></div>}{data&&<div className="inline-visit-panels"><VisitCardEditor visit={data.visit} leads={data.leads} options={data.options} pm={data.pm} requestId={data.requests.dates} onSaved={v=>{setData(d=>d?{...d,visit:v}:d);void load();}}/><section className="inline-visit-cancel"><CancelVisit visit={data.visit} requestId={data.requests.cancel}/></section></div>}</>;
  return <div className={'inline-visit'+(calendarCard?' calendar-work-details':compact?' compact-work-plan':'')}>
    {!hideWorkTitle&&<h3>{visit.description}</h3>}{showJob&&<p>{visit.job_title}</p>}
    {scope}
    <div className="schedule-line"><strong>{dateLabel(visit.start_date)}{visit.end_date!==visit.start_date?' - '+dateLabel(visit.end_date):''}</strong><span>{slotLabel(visit)}</span>{visit.state!=='planned'&&<span className="badge">{visit.state==='completed'?'Completed':'Cancelled'}</span>}{showStaffingWarning&&<StaffingWarning visit={visit}/>}</div>
    <div className="crew-row"><p className="crew-line">{visit.participants.map(p=>p.name+(p.duty==='leading'?' (lead)':' (helping)')).join(', ')||'No crew assigned'}</p>{calendarCard&&editable&&visit.state==='planned'&&<button type="button" className="icon-action edit-details-icon" title="Edit dates and crew" aria-label={'Edit dates and crew: '+visit.description} aria-expanded={editorOpen} aria-controls={editorId} onClick={()=>{const open=!editorOpen;setEditorOpen(open);if(open&&(!data||loadedSignature!==initialVisit.updated_at))void load();}}><DetailIcon kind="edit"/></button>}</div>
    {!showStaffingWarning&&visit.state==='planned'&&vacant>0&&<p className="staffing-notice">{vacant} helper {vacant===1?'space':'spaces'} to fill</p>}
    {visit.state==='planned'&&visit.day_conflicts>0&&<p className="form-message">Other plans share this day. Check the workload.</p>}
    {calendarCard&&editable&&visit.state==='planned'&&(editorOpen||data||loading||message)&&<div id={editorId} className="calendar-inline-editor" hidden={!editorOpen}>{panels}</div>}
    {!calendarCard&&editable&&visit.state==='planned'&&<div className="visit-actions">
      <details name={'visit-action-'+visit.id} className="inline-visit-editor" onToggle={e=>{if(e.currentTarget.open&&(!data||loadedSignature!==initialVisit.updated_at))void load();}}><summary className={compact?'icon-action edit-details-icon':'button'} title={compact?'Edit dates and crew':undefined} aria-label={compact?'Edit dates and crew: '+visit.description:undefined}>{compact?<DetailIcon kind="edit"/>:<>Edit plan &amp; crew</>}</summary>
        {panels}
      </details>
    </div>}
  </div>;
}
