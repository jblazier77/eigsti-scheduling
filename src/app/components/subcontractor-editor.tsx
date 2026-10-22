'use client';
import { useActionState, useEffect, useRef, useState } from 'react';
import type { Subcontractor, SubcontractorValues } from '../../domain/job-classification.ts';
import { saveSubcontractorAction, type ClassificationState } from '../classification-actions';
import { TradeChoices } from './classification-editor';

const blank:SubcontractorValues={name:'',phone:'',email:'',trades:[]};
export function SubcontractorEditor({original,requestId}:{original?:Subcontractor;requestId:string}) {
  const [reset,setReset]=useState({version:0,requestId});
  return <DirectoryForm key={reset.version} original={original} requestId={reset.requestId} onCancel={()=>setReset(n=>({version:n.version+1,requestId:crypto.randomUUID()}))}/>;
}
function DirectoryForm({original,requestId,onCancel}:{original?:Subcontractor;requestId:string;onCancel:()=>void}) {
  const initial=original?{name:original.name,phone:original.phone,email:original.email,trades:original.trades}:blank;
  const [baseline,setBaseline]=useState(initial),[value,setValue]=useState(initial),[request,setRequest]=useState(requestId);
  const changed=(Object.keys(blank) as (keyof SubcontractorValues)[]).filter(k=>JSON.stringify(value[k])!==JSON.stringify(baseline[k]));
  const retry=useRef<FormData|null>(null);
  const [state,action,pending]=useActionState(async(previous:ClassificationState,form:FormData):Promise<ClassificationState>=>{
    const submission=previous.uncertain&&retry.current?retry.current:form;
    if(submission.get('archive')==='true')submission.set('patch','{"archive":true}');
    retry.current=submission;
    try{const result=await saveSubcontractorAction(previous,submission);if(result.saved){setBaseline(value);setRequest(crypto.randomUUID());retry.current=null;}return result;}catch{return{message:'Save not confirmed. Retry the same draft.',uncertain:true};}
  },{message:''});
  const serverSignature=JSON.stringify(initial);
  useEffect(()=>{if(original&&!changed.length&&!pending&&!state.uncertain){const current=JSON.parse(serverSignature);setBaseline(current);setValue(current);}},[serverSignature,changed.length,pending,state.uncertain,original]);
  useEffect(()=>{if(!changed.length)return;const warn=(e:BeforeUnloadEvent)=>{e.preventDefault();e.returnValue='';};window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn);},[changed.length]);
  const lock=pending||!!state.uncertain||!original&&!!state.saved;
  return <form action={action} className="stack">
    <input type="hidden" name="id" value={original?.id??''}/><input type="hidden" name="requestId" value={request}/><input type="hidden" name="patch" value={JSON.stringify(value)}/>{changed.map(k=><input key={k} type="hidden" name="changed" value={k}/>)}
    {(['name','phone','email'] as const).map(k=><label key={k}>{k==='name'?'Company / contact name':k==='phone'?'Phone (optional)':'Email (optional)'}<input name={k} type={k==='email'?'email':k==='phone'?'tel':'text'} required={k==='name'} maxLength={k==='name'?100:k==='phone'?40:254} value={value[k]} readOnly={lock} onChange={e=>setValue({...value,[k]:e.target.value})}/></label>)}
    <TradeChoices value={value.trades} onChange={v=>setValue({...value,trades:v})} disabled={lock}/>
    {state.message&&<p role="status">{state.message}</p>}{state.uncertain&&<p>The last save may have completed. Retry this same draft to confirm.</p>}
    <div className="two-actions"><button className="button primary" disabled={pending||!!original&&!changed.length&&!state.uncertain||!original&&!!state.saved} aria-busy={pending}>{pending?'Saving…':state.uncertain?'Retry save':state.saved&&!changed.length?'Saved':'Save'}</button><button className="button" type="button" disabled={pending} onClick={()=>{if(!state.uncertain||window.confirm('The last save may have completed. Discard this draft?'))onCancel();}}>{!original&&state.saved?'Add another':'Cancel'}</button></div>
    {original&&<button type="submit" name="archive" value="true" className="button" disabled={pending||state.uncertain} formNoValidate onClick={e=>{if(!window.confirm('Archive this subcontractor? Existing history is retained.'))e.preventDefault();}}>Archive subcontractor</button>}
  </form>;
}
