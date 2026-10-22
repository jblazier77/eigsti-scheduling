'use client';

import Link from 'next/link';
import { useActionState, useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { changedJobFields, jobEditFields, type JobEditValues } from '../../domain/job-edits.ts';
import { updateJobAction, type FormState } from '../actions';

export function InlineJobDetails({jobId,original,scopeFirst=false,onDone}:{jobId:string;original:JobEditValues;scopeFirst?:boolean;onDone?:()=>void}){
  const [reset,setReset]=useState(0);
  return <EditJobForm key={reset} jobId={jobId} original={original} inline scopeFirst={scopeFirst} onSaved={onDone} onCancel={()=>{setReset(n=>n+1);onDone?.();}}/>;
}
export function EditJobForm({ jobId, original,inline=false,onCancel,scopeFirst=false,onSaved }: { jobId: string; original: JobEditValues;inline?:boolean;onCancel?:()=>void;scopeFirst?:boolean;onSaved?:()=>void }) {
  const router = useRouter();
  const [baseline,setBaseline]=useState(original);
  const lastServer=useRef(JSON.stringify(original));
  const [values, setValues] = useState(original);
  const [state, action, pending] = useActionState(async (previous: FormState, form: FormData): Promise<FormState> => {
    try {const result=await updateJobAction(previous,form);if(inline&&result.jobId){const saved={...baseline,...changedJobFields(baseline,values)};setBaseline(saved);setValues(saved);lastServer.current=JSON.stringify(original);onSaved?.();return{message:'Job details saved.'};}return result;}
    catch { return { message: 'The save was not confirmed. Your changes are still here.', uncertain: true }; }
  }, { message: '' });
  const patch = changedJobFields(baseline, values);
  const dirty = Object.keys(patch).length > 0;
  const detailPath = '/jobs/' + jobId;
  useEffect(() => {
    if (state.jobId&&!inline) { router.replace('/jobs/' + state.jobId); router.refresh(); }
  }, [state.jobId, router,inline]);
  useEffect(()=>{const signature=JSON.stringify(original);if(inline&&!pending&&!dirty&&!state.uncertain&&signature!==lastServer.current){lastServer.current=signature;setBaseline(original);setValues(original);}},[original,inline,pending,dirty,state.uncertain]);
  useEffect(() => {
    if (!dirty || state.jobId) return;
    const warn = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue = ''; };
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [dirty, state.jobId]);
  return <form action={action} className="stack">
    <input type="hidden" name="jobId" value={jobId} />
    <input type="hidden" name="patch" value={JSON.stringify(patch)} />
    {[...jobEditFields].sort((a,b)=>scopeFirst?Number(b.name==='scope')-Number(a.name==='scope'):0).map(field => <div key={field.name}>
      <label htmlFor={field.name}>{field.label}{!field.required && <span className="muted"> (optional)</span>}</label>
      {field.required ? <input id={field.name} type={field.name === 'phone' ? 'tel' : 'text'} required maxLength={field.max}
        value={values[field.name]} readOnly={pending || !!state.jobId||!!state.uncertain} onChange={event => setValues({ ...values, [field.name]: event.target.value })} />
        : <textarea id={field.name} rows={field.name === 'scope' ? 7 : 4} maxLength={field.max}
          value={values[field.name]} readOnly={pending || !!state.jobId||!!state.uncertain} onChange={event => setValues({ ...values, [field.name]: event.target.value })} />}
      {field.name === 'title' && <p className="muted field-hint">The job title stays as written when you change the customer or address.</p>}
      {field.name === 'access_notes' && <p className="muted field-hint">Arrival instructions, parking and preparation for the crew.</p>}
    </div>)}
    {state.message && <p className="form-message" role="alert">{state.message}</p>}
    {state.uncertain && <p className="muted">Keep this tab open. <a href={detailPath} target="_blank" rel="noreferrer">Check the saved job in a new tab</a> before saving again. Saving again replaces the fields you changed with the values on this form.</p>}
    <div className="two-actions"><button className="button primary" disabled={pending || !dirty || !!state.jobId}>{pending ? 'Saving changes...' : state.jobId ? 'Saved. Opening...' : 'Save changes'}</button>
      {inline?<button className="button" type="button" disabled={pending} onClick={()=>{if(!state.uncertain||window.confirm('The save may have completed. Discard this draft?'))onCancel?.();}}>Cancel</button>:<Link className="button" href={detailPath} onClick={event => { if (pending || (dirty && !window.confirm('Leave this form? Unsaved changes will be lost.'))) event.preventDefault(); }}>Cancel</Link>}</div>
  </form>;
}
