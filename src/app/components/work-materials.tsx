'use client';
import {useActionState,useEffect,useId,useRef,useState} from 'react';
import {materialLabels,type MaterialValues,type WorkStatus} from '../../domain/planning-updates.ts';
import {dateLabel} from '../../domain/visits.ts';
import {saveMaterialAction,type MaterialState} from '../planning-update-actions';
import {DetailIcon} from './detail-icons';
const materialValues=(status:WorkStatus):MaterialValues=>({material_name:status.material_name??'',material_status:status.material_status??'not_set',material_expected_on:status.material_expected_on??null});
export function WorkMaterials(props:{status:WorkStatus;canEdit:boolean}){
 const [version,setVersion]=useState(0);
 return <MaterialForm {...props} key={version} onReset={()=>setVersion(value=>value+1)}/>;
}
function MaterialForm({status,canEdit,onReset}:{status:WorkStatus;canEdit:boolean;onReset:()=>void}){
 const [baseline,setBaseline]=useState(()=>materialValues(status)),[values,setValues]=useState(()=>materialValues(status));
 const [request,setRequest]=useState(''),[editing,setEditing]=useState(false);const panelId=useId();
 const [state,action,pending]=useActionState(async(previous:MaterialState,form:FormData):Promise<MaterialState>=>{
  try{const result=await saveMaterialAction(previous,form);if(result.values){setBaseline(result.values);setValues(result.values);setRequest('');setEditing(false);}return result;}catch{return {message:'Save not confirmed. Keep the same draft and retry.',uncertain:true};}
 },{message:''});
 const dirty=JSON.stringify(baseline)!==JSON.stringify(values),locked=pending||!!state.uncertain;
 const signature=JSON.stringify(materialValues(status));
 const lastServer=useRef(signature);
 useEffect(()=>{if(lastServer.current!==signature&&!dirty&&!pending&&!state.uncertain){lastServer.current=signature;const next=materialValues(status);setBaseline(next);setValues(next);}},[signature,dirty,pending,state.uncertain]);
 useEffect(()=>{if(!dirty)return;const warn=(e:BeforeUnloadEvent)=>{e.preventDefault();e.returnValue='';};window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn);},[dirty]);
 const summary=status.material_status&&status.material_status!=='not_set'?`${status.material_name?status.material_name+' / ':''}${materialLabels[status.material_status]}${status.material_expected_on?' / Expected '+dateLabel(status.material_expected_on):''}`:'';
 if(!canEdit)return summary?<p className="material-summary">{summary}</p>:null;
 if(!status.material_status)return <p className="muted">Material controls will be available after the planning update.</p>;
 return <section className="material-editor"><div className="material-heading"><p className="material-summary">{summary||'Materials not set'}</p><button type="button" className="icon-action edit-details-icon" title="Edit materials" aria-label="Edit materials" aria-expanded={editing} aria-controls={panelId} onClick={()=>{setEditing(true);if(!request)setRequest(crypto.randomUUID());}}><DetailIcon kind="edit"/></button></div><form id={panelId} hidden={!editing} action={action} className="stack material-form">
  <input type="hidden" name="workId" value={status.id}/><input type="hidden" name="requestId" value={request}/><input type="hidden" name="values" value={JSON.stringify(values)}/>
  <label>Material<input maxLength={300} placeholder="e.g. Cabinets" readOnly={locked} value={values.material_name} required={['need_to_order','ordered','in_stock'].includes(values.material_status)} onChange={e=>setValues({...values,material_name:e.target.value})}/></label>
  <label>Availability<select disabled={locked} value={values.material_status} onChange={e=>{const next=e.target.value as MaterialValues['material_status'];setValues({...values,material_status:next,material_expected_on:['need_to_order','ordered'].includes(next)?values.material_expected_on:null});}}>{Object.entries(materialLabels).map(([key,label])=><option value={key} key={key}>{label}</option>)}</select></label>
  {['need_to_order','ordered'].includes(values.material_status)&&<label>Expected arrival (optional)<input type="date" disabled={locked} value={values.material_expected_on??''} onChange={e=>setValues({...values,material_expected_on:e.target.value||null})}/></label>}
  <p className="muted">An expected date does not mark material in stock. Update the status when it arrives.</p>
  {state.message&&<p className="form-message" role="status">{state.message}</p>}
  <div className="two-actions"><button className="button primary" disabled={pending||!dirty||!request}>{pending?'Saving...':state.uncertain?'Retry save':'Save'}</button><button className="button" type="button" disabled={pending} onClick={()=>{if(state.uncertain&&!window.confirm('This save may have completed. Discard the draft?'))return;onReset();}}>Cancel</button></div>
 </form></section>;
}
