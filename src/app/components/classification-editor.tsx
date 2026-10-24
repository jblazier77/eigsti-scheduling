'use client';
import { useActionState, useEffect, useState } from 'react';
import { classificationChanges, trades, type JobClassification, type Trade } from '../../domain/job-classification.ts';
import { saveClassificationAction, type ClassificationState } from '../classification-actions';
import { WorkIcon,JobMarkers } from './job-markers';

function ScopeButton({selected,label,kind,onClick,disabled=false}:{selected:boolean;label:string;kind:string;onClick:()=>void;disabled?:boolean}) {
  return <button type="button" className="scope-toggle" aria-pressed={selected} disabled={disabled} onClick={onClick}><WorkIcon kind={kind}/><span>{label}</span><span className="selection-mark" aria-hidden="true">{selected?'✓':''}</span></button>;
}
export function TradeChoices({value,onChange,disabled=false,wholeHouse}:{value:Trade[];onChange:(v:Trade[])=>void;disabled?:boolean;wholeHouse?:{value:boolean;onChange:()=>void}}) {
  return <fieldset className="scope-picker"><legend>{wholeHouse?'Project scopes':'Trades'}</legend><div className="scope-grid">
    {wholeHouse&&<ScopeButton selected={wholeHouse.value} label="Whole house" kind="house" onClick={wholeHouse.onChange} disabled={disabled}/>}
    {trades.map(t=><ScopeButton key={t.id} selected={value.includes(t.id)} label={t.label} kind={t.id} onClick={()=>onChange((value.includes(t.id)?value.filter(id=>id!==t.id):[...value,t.id]).sort())} disabled={disabled}/>)}</div></fieldset>;
}
export function ClassificationFields({value,onChange,disabled=false}:{value:JobClassification;onChange:(v:JobClassification)=>void;disabled?:boolean}) {
  return <div className="classification-fields"><fieldset className="tag-picker"><legend>Job tags</legend><div className="tag-toggle-row">
    <ScopeButton selected={value.rain_day} label="Rain-day option" kind="rain" onClick={()=>onChange({...value,rain_day:!value.rain_day})} disabled={disabled}/>
    <ScopeButton selected={value.filler} label="Filler work" kind="filler" onClick={()=>onChange({...value,filler:!value.filler})} disabled={disabled}/>
  </div></fieldset><TradeChoices value={value.trades} onChange={v=>onChange({...value,trades:v})} disabled={disabled} wholeHouse={{value:value.whole_house,onChange:()=>onChange({...value,whole_house:!value.whole_house})}}/></div>;
}
export function ReadOnlyClassification({value}:{value:JobClassification}) {
  return <div className="classification-readonly"><JobMarkers value={value}/></div>;
}
export function ClassificationEditor({jobId,original,requestId}: {jobId:string;original:JobClassification;requestId:string}) {
  const [reset,setReset]=useState({version:0,requestId});
  return <ClassificationForm key={reset.version} jobId={jobId} original={original} requestId={reset.requestId} cancel={()=>setReset(n=>({version:n.version+1,requestId:crypto.randomUUID()}))}/>;
}
function ClassificationForm({jobId,original,requestId,cancel}:{jobId:string;original:JobClassification;requestId:string;cancel:()=>void}) {
  const [baseline,setBaseline]=useState(original),[value,setValue]=useState(original),[request,setRequest]=useState(requestId);
  const patch=classificationChanges(baseline,value),dirty=!!Object.keys(patch).length;
  const [state,action,pending]=useActionState(async(previous:ClassificationState,form:FormData):Promise<ClassificationState>=>{
    try{const result=await saveClassificationAction(previous,form);if(result.saved){setBaseline(value);setRequest(crypto.randomUUID());}return result;}
    catch{return{message:'Save not confirmed. Retry the same draft.',uncertain:true};}
  },{message:''});
  useEffect(()=>{if(!dirty&&!pending&&!state.uncertain){setBaseline(original);setValue(original);}},[original,dirty,pending,state.uncertain]);
  useEffect(()=>{if(!dirty)return;const warn=(e:BeforeUnloadEvent)=>{e.preventDefault();e.returnValue='';};window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn);},[dirty]);
  return <form action={action} className="stack"><input type="hidden" name="jobId" value={jobId}/><input type="hidden" name="requestId" value={request}/><input type="hidden" name="patch" value={JSON.stringify(patch)}/>
    <ClassificationFields value={value} onChange={setValue} disabled={pending||state.uncertain}/>
    {state.message&&<p role="status">{state.message}</p>}{state.uncertain&&<p>Keep this draft for retry; the last save may already have completed.</p>}
    {(dirty||state.uncertain)&&<div className="two-actions"><button className="button primary" disabled={pending||!dirty} aria-busy={pending}>{pending?'Saving…':state.uncertain?'Retry save':!dirty&&state.saved?'Saved':'Save'}</button><button className="button" type="button" disabled={pending||!dirty&&!state.message} onClick={()=>{if(!state.uncertain||window.confirm('The last save may have completed. Discard this draft?'))cancel();}}>Cancel</button></div>}
  </form>;
}
