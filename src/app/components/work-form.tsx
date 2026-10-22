'use client';

import Link from 'next/link';
import { useActionState, useEffect, useId, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { changedWorkFields, type WorkValues, type LeadOption } from '../../domain/work.ts';
import { createWorkAction, updateWorkAction } from '../work-actions';
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
  const patch = changedWorkFields(baseline, values);
  const dirty = Object.keys(patch).length > 0;
  const [state, action, pending] = useActionState(async (previous: FormState, form: FormData): Promise<FormState> => {
    try {
      const result = await (workId ? updateWorkAction : createWorkAction)(previous, form);
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
    <div className={inline ? 'work-inline-fields' : 'stack'}>
      <div><label htmlFor={fieldId + '-description'}>Work</label><input id={fieldId + '-description'} value={values.description} onChange={e => setValues({ ...values, description: e.target.value })} required maxLength={1000} readOnly={locked} />{!inline && <p className="muted field-hint">Keep Whole job for simple projects, or describe work such as framing or finish carpentry.</p>}</div>
      <div><label htmlFor={fieldId + '-lead'}>Responsible lead</label><select id={fieldId + '-lead'} value={values.responsible_lead ?? ''} onChange={e => setValues({ ...values, responsible_lead: e.target.value || null })} disabled={locked}>
        <option value="">Not assigned yet</option>
        {baseline.responsible_lead && !leads.some(lead => lead.id === baseline.responsible_lead) && <option value={baseline.responsible_lead}>{originalLeadName || 'Previously assigned lead'} - unavailable for new assignments</option>}
        {leads.map(lead => <option key={lead.id} value={lead.id}>{lead.display_name}</option>)}
      </select>{!leads.length && <p className="muted field-hint">No active lead accounts are available. You can save unassigned and assign a lead later.</p>}</div>
    </div>
    {!inline && <p className="muted">Lead ownership gives access to this job. Dates and helpers will be planned separately.</p>}
    {state.message && <p className="form-message" role="alert">{state.message}</p>}
    {state.uncertain && <p className="muted">{workId ? <><a href={'/jobs/' + jobId} target="_blank" rel="noreferrer">Check the saved work in a new tab</a> before saving again. Only changed fields will be replaced.</> : 'Retry this same save to avoid adding duplicate work.'}</p>}
    <div className={inline ? 'work-inline-actions' : 'two-actions'}>
      <button className="button primary" disabled={pending || !!state.jobId || (!!workId && !dirty)}>{pending ? 'Saving...' : state.jobId ? 'Saved. Opening...' : inline ? 'Save' : workId ? 'Save work and lead' : state.uncertain ? 'Retry this save' : 'Save work'}</button>
      {inline||inlineCreate ? <button type="button" className="button" disabled={pending || (!onDone && !dirty && !state.message)} onClick={()=>{if(!state.uncertain||window.confirm('The save may have completed. Discard this draft?'))onCancel?.();}}>Cancel</button> : <Link className="button" href={'/jobs/' + jobId} onClick={e => { if (pending || (dirty && !window.confirm('Leave this form? Unsaved work changes will be lost.'))) e.preventDefault(); }}>Cancel</Link>}
    </div>
  </form>;
}

