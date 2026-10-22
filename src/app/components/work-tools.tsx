'use client';
import {useCallback,useState} from 'react';
import type {JobWork,LeadOption} from '../../domain/work.ts';
import {DetailIcon} from './detail-icons';
import {WorkCardEditor} from './work-card-editor';
import {InlineNewWork} from './work-form';

export function WorkTools({jobId,work,leads,editable,count,title}:{jobId:string;work:JobWork[];leads:LeadOption[];editable:boolean;count:number;title:string}){
 const [panel,setPanel]=useState<{kind:'edit'|'add';requestId:string}|null>(null);
 const close=useCallback(()=>setPanel(null),[]);
 return <>
  <div className="section-heading work-section-heading"><h2>{title} <span className="muted">{count}</span></h2>{editable&&!panel&&<div className="work-heading-actions">{work.some(w=>w.completion==='open')&&<button className="icon-action edit-details-icon" title="Edit work and leads" aria-label="Edit work and leads" onClick={()=>setPanel({kind:'edit',requestId:crypto.randomUUID()})}><DetailIcon kind="edit"/></button>}<button className="button" onClick={()=>setPanel({kind:'add',requestId:crypto.randomUUID()})}><DetailIcon kind="plus"/> Add work</button></div>}</div>
  {editable&&panel&&<div className="work-management-panel"><h3>{panel.kind==='edit'?'Edit work & leads':'Add work'}</h3>{panel.kind==='edit'?<WorkCardEditor jobId={jobId} work={work.filter(w=>w.completion==='open')} leads={leads} requestId={panel.requestId} compact onDone={close}/>:<InlineNewWork jobId={jobId} leads={leads} requestId={panel.requestId} original={{description:'',responsible_lead:null}} onDone={close}/>}</div>}
 </>;
}
