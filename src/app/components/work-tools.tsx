'use client';
import {useCallback,useState} from 'react';
import type {StaffOption} from '../../domain/visits.ts';
import type {JobWork,LeadOption} from '../../domain/work.ts';
import {DetailIcon} from './detail-icons';
import {InlineNewWork} from './work-form';
export function WorkTools({jobId,leads,staff=[],editable,count,title}:{jobId:string;work:JobWork[];leads:LeadOption[];staff?:StaffOption[];editable:boolean;count:number;title:string}){
 const [request,setRequest]=useState<string|null>(null),close=useCallback(()=>setRequest(null),[]);
 return <><div className="section-heading work-section-heading"><h2>{title} <span className="muted">{count}</span></h2>{editable&&!request&&<button className="button" type="button" onClick={()=>setRequest(crypto.randomUUID())}><DetailIcon kind="plus"/> Add work</button>}</div>
 {editable&&request&&<div className="work-management-panel"><h3>Add work</h3><InlineNewWork jobId={jobId} leads={leads} staff={staff} requestId={request} original={{description:'',responsible_lead:null}} onDone={close}/></div>}</>;
}
