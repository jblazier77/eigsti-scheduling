'use client';

import Link from 'next/link';
import { useActionState, useEffect, useId, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { changedWorkFields, type WorkValues, type LeadOption } from '../../domain/work.ts';
import { createWorkAction, updateWorkAction } from '../work-actions';
import { createQuickWorkAction } from '../planning-update-actions';
import {materialLabels,type MaterialValues} from '../../domain/planning-updates.ts';
import type {VisitSlot} from '../../domain/visits.ts';
import type { FormState } from '../actions';

type WorkFormProps = { jobId: string; workId?: string; requestId?: string; original: WorkValues; leads: LeadOption[]; originalLeadName?: string | null };

export function InlineWorkEditor(props: WorkFormProps & { workId: string }) {
  const [reset, setReset] = useState(0);
  return <WorkForm {...props} key={reset} inline onCancel={() => setReset(value => value + 1)} />;
}

export function InlineNewWork(props:WorkFormProps & {onDone?:()=>void}){
  const [reset,setReset]=useState({version:0,requestId:props.requestId});
  return <WorkForm {...props} key={reset.version} requestId={reset.requestId} inlineCreate onCancel={()=>{if(props.onDone)props.onDone();else setReset(v=>({version:v.version+1,requestId:crypto.randomUUID()}));}}/>;
}

export function WorkForm({ jobId, workId, requestId, original, leads, originalLeadName, inline = false, inlineCreate=false, onCancel,onDone }: WorkFormProps & { inline?: boolean; inlineCreate?:boolean; onCancel?: () => void;onDone?:()=>void }) {
  const router = useRouter();
  const fieldId = useId();
  const [baseline, setBaseline] = useState(original);
  const lastServerValues = useRef(JSON.stringify(original));
  const [stableRequest] = useState(requestId);
  const [values, setValues] = useState(baseline);
  const [scheduleDate,setScheduleDate]=useState(''),[lastDate,setLastDate]=useState('');
  const [slot,setSlot]=useState<VisitSlot>('day'),[startTime,setStartTime]=useState(''),[endTime,setEndTime]=useState(''),[helpersNeeded,setHelpersNeeded]=useState(0);
  const [materialStatus,setMaterialStatus]=useState<MaterialValues['material_status']>('not_set'),[materialName,setMaterialName]=useState(''),[materialDate,setMaterialDate]=useState('');
  const materials:MaterialValues|null=materialStatus==='not_set'?null:{material_name:materialName.trim()||values.description.trim().slice(0,300),material_status:materialStatus,material_expected_on:materialDate||null};
  const patch = changedWorkFields(baseline, values);
  const dirty = Object.keys(patch).length > 0 || (!workId&&(!!scheduleDate||helpersNeeded>0||!!materials));
  const [state, action, pending] = useActionState(async (previous: FormState, form: FormData): Promise<FormState> => {
    try {
      const result = await (workId ? updateWorkAction : scheduleDate||helpersNeeded>0||materials ? createQuickWorkAction : createWorkAction)(previous, form);
      if (inline && result.jobId) {
        const saved = { ...baseline, ...patch };
        setBaseline(saved); setValues(saved);
        router.refresh();
        return { message: 'Work and lead saved.' };
      }
      return result;
    } catch { return { message: 'The save was not confirmed. Your details are still here.', uncertain: true }; }
  }, { message: '' });
  const locked = pending || !!state.jobId || (!workId && !!state.uncertain);
  useEffect(() => {
    // Accept fresh server values for pristine rows. Preserve another row's draft
    // when a save refreshes the page, including its original narrow-patch base.
    const signature = JSON.stringify(original);
    if (inline && !pending && !dirty && lastServerValues.current !== signature) {
      lastServerValues.current = signature;
      setBaseline(original); setValues(original);
    }
  }, [original, inline, pending, dirty]);
  useEffect(() => { if (state.jobId&&!inlineCreate) { router.replace('/jobs/' + state.jobId); router.refresh(); } }, [state.jobId, router,inlineCreate]);
  useEffect(()=>{if(inlineCreate&&state.jobId)onDone?.();},[inlineCreate,state.jobId,onDone]);
  useEffect(() => {
    if (!dirty || state.jobId) return;
    const warn = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue = ''; };
    window.addEventListener('beforeunload', warn); return () => window.removeEventListener('beforeunload', warn);
  }, [dirty, state.jobId]);
  if(inlineCreate&&state.jobId)return <div role="status"><p>Work added.</p><button type="button" className="button" onClick={onCancel}>Add another</button></div>;
  return <form action={action} className="stack">
    <input type="hidden" name="jobId" value={jobId} /><input type="hidden" name="workId" value={workId ?? ''} /><input type="hidden" name="requestId" value={stableRequest ?? ''} /><input type="hidden" name="values" value={JSON.stringify(workId ? patch : values)} />
    {!workId&&<input type="hidden" name="schedule" value={JSON.stringify(scheduleDate?{start_date:scheduleDate,end_date:lastDate||scheduleDate,slot,start_time:slot==='timed'?startTime:null,end_time:slot==='timed'?endTime:null,required_helpers:helpersNeeded}:null)}/>}
    {!workId&&<><input type="hidden" name="helpersNeeded" value={helpersNeeded}/><input type="hidden" name="materials" value={JSON.stringify(materials)}/></>}
    <div className={inline ? 'work-inline-fields' : 'stack'}>
      <div><label htmlFor={fieldId + '-description'}>Work</label><input id={fieldId + '-description'} value={values.description} onChange={e => setValues({ ...values, description: e.target.value })} required maxLength={1000} readOnly={locked} />{!inline && <p className="muted field-hint">Keep Whole job for simple projects, or describe work such as framing or finish carpentry.</p>}</div>
      <div><label htmlFor={fieldId + '-lead'}>Responsible lead</label><select id={fieldId + '-lead'} required={!workId&&!!scheduleDate} value={values.responsible_lead ?? ''} onChange={e => setValues({ ...values, responsible_lead: e.target.value || null })} disabled={locked}>
        <option value="">Not assigned yet</option>
        {baseline.responsible_lead && !leads.some(lead => lead.id === baseline.responsible_lead) && <option value={baseline.responsible_lead}>{originalLeadName || 'Previously assigned lead'} - unavailable for new assignments</option>}
        {leads.map(lead => <option key={lead.id} value={lead.id}>{lead.display_name}</option>)}
      </select>{!leads.length && <p className="muted field-hint">No active lead accounts are available. You can save unassigned and assign a lead later.</p>}</div>
    </div>
    {!workId&&<fieldset disabled={locked} className="visit-fields optional-work-date"><div className="two-actions"><label>Date (optional)<input type="date" value={scheduleDate} onChange={e=>{setScheduleDate(e.target.value);setLastDate(e.target.value);}}/></label><label>Helpers needed<input type="number" min="0" max="20" required value={helpersNeeded} onChange={e=>setHelpersNeeded(Number(e.target.value))}/></label></div>
      <label>Material availability<select value={materialStatus} onChange={e=>{const next=e.target.value as MaterialValues['material_status'];setMaterialStatus(next);if(!['need_to_order','ordered'].includes(next))setMaterialDate('');}}>{Object.entries(materialLabels).map(([key,label])=><option key={key} value={key}>{label}</option>)}</select></label>
      {['need_to_order','ordered','in_stock'].includes(materialStatus)&&<label>Material / item (optional)<input maxLength={300} placeholder="Uses the work description if blank" value={materialName} onChange={e=>setMaterialName(e.target.value)}/></label>}
      {['need_to_order','ordered'].includes(materialStatus)&&<label>Expected arrival (optional)<input type="date" value={materialDate} onChange={e=>setMaterialDate(e.target.value)}/></label>}
      {scheduleDate&&<details className="quick-work-options"><summary>More date / time options</summary><label>Through<input type="date" required value={lastDate||scheduleDate} onChange={e=>setLastDate(e.target.value)}/></label>
      <label>Time (optional)<select value={slot} onChange={e=>setSlot(e.target.value as VisitSlot)}><option value="day">No time set</option><option value="all_day">Reserve all day</option><option value="morning">Morning</option><option value="afternoon">Afternoon</option><option value="timed">Specific hours</option></select></label>
      {slot==='timed'&&<div className="two-actions"><label>Start<input type="time" min="07:00" max="15:30" required value={startTime} onChange={e=>setStartTime(e.target.value)}/></label><label>End<input type="time" min="07:00" max="15:30" required value={endTime} onChange={e=>setEndTime(e.target.value)}/></label></div>}</details>}
      <p className="muted field-hint">Leave blank to schedule later. Dates need a lead; times are optional.</p>
    </fieldset>}
    {state.message && <p className="form-message" role="alert">{state.message}</p>}
    {state.uncertain && <p className="muted">{workId ? <><a href={'/jobs/' + jobId} target="_blank" rel="noreferrer">Check the saved work in a new tab</a> before saving again. Only changed fields will be replaced.</> : 'Retry this same save to avoid adding duplicate work.'}</p>}
    <div className={inline ? 'work-inline-actions' : 'two-actions'}>
      <button className="button primary" disabled={pending || !!state.jobId || (!!workId && !dirty)}>{pending ? 'Saving...' : state.jobId ? 'Saved. Opening...' : inline ? 'Save' : workId ? 'Save work and lead' : state.uncertain ? 'Retry this save' : 'Save work'}</button>
      {inline||inlineCreate ? <button type="button" className="button" disabled={pending || (!onDone && !dirty && !state.message)} onClick={()=>{if(!state.uncertain||window.confirm('The save may have completed. Discard this draft?'))onCancel?.();}}>Cancel</button> : <Link className="button" href={'/jobs/' + jobId} onClick={e => { if (pending || (dirty && !window.confirm('Leave this form? Unsaved work changes will be lost.'))) e.preventDefault(); }}>Cancel</Link>}
    </div>
  </form>;
}

