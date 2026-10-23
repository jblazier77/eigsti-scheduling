'use client';
import {useActionState,useEffect,useState} from 'react';
import {useRouter} from 'next/navigation';
import {setJobArchiveAction} from '../job-archive-actions';
import type {FormState} from '../actions';
export function JobArchiveControl({jobId,lifecycle,requestId}:{jobId:string;lifecycle:string;requestId:string}){
 const router=useRouter(),[stableRequest]=useState(requestId),archived=lifecycle!=='open';
 const [state,action,pending]=useActionState(async(previous:FormState,form:FormData)=>{try{return await setJobArchiveAction(previous,form);}catch{return {message:'The status change was not confirmed. Retry this same request.',uncertain:true};}}, {message:''} as FormState);
 useEffect(()=>{if(state.jobId)router.refresh();},[state.jobId,router]);
 const form=<form action={action} className="stack"><input type="hidden" name="jobId" value={jobId}/><input type="hidden" name="requestId" value={stableRequest}/><input type="hidden" name="expected" value={lifecycle}/><input type="hidden" name="operation" value={archived?'restore':'archive'}/><p className="muted">{archived?'Restore this same job for additional work or a punch list. Existing details, files, contacts and work history stay with it. Previous work ownership returns to active lead queues; review it before adding dates.':'Archive removes this job from active lists, lead queues and calendars. All details and history are kept, and you can restore it later. Today or future crew dates and subcontractor commitments must be resolved first.'}</p>{state.message&&<p role="status">{state.message}</p>}{state.uncertain&&<p>Check the job in another tab or retry this same request. Its status has not been confirmed.</p>}<button className="button" disabled={pending} aria-busy={pending}>{pending?'Saving...':state.uncertain?'Retry same request':archived?'Restore for more work':'Archive job'}</button></form>;
 return archived?<section className="archive-banner"><h2>{lifecycle==='archived'?'Archived job':'Inactive job'}</h2>{form}</section>:<details className="job-archive-options"><summary>Job options</summary>{form}</details>;
}
