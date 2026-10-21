'use client';

import Link from 'next/link';
import { useActionState, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { changedJobFields, jobEditFields, type JobEditValues } from '../../domain/job-edits.ts';
import { updateJobAction, type FormState } from '../actions';

export function EditJobForm({ jobId, original }: { jobId: string; original: JobEditValues }) {
  const router = useRouter();
  const [values, setValues] = useState(original);
  const [state, action, pending] = useActionState(async (previous: FormState, form: FormData): Promise<FormState> => {
    try { return await updateJobAction(previous, form); }
    catch { return { message: 'The save was not confirmed. Your changes are still here.', uncertain: true }; }
  }, { message: '' });
  const patch = changedJobFields(original, values);
  const dirty = Object.keys(patch).length > 0;
  const detailPath = '/jobs/' + jobId;
  useEffect(() => {
    if (state.jobId) { router.replace('/jobs/' + state.jobId); router.refresh(); }
  }, [state.jobId, router]);
  useEffect(() => {
    if (!dirty || state.jobId) return;
    const warn = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue = ''; };
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [dirty, state.jobId]);
  return <form action={action} className="stack">
    <input type="hidden" name="jobId" value={jobId} />
    <input type="hidden" name="patch" value={JSON.stringify(patch)} />
    {jobEditFields.map(field => <div key={field.name}>
      <label htmlFor={field.name}>{field.label}{!field.required && <span className="muted"> (optional)</span>}</label>
      {field.required ? <input id={field.name} type={field.name === 'phone' ? 'tel' : 'text'} required maxLength={field.max}
        value={values[field.name]} readOnly={pending || !!state.jobId} onChange={event => setValues({ ...values, [field.name]: event.target.value })} />
        : <textarea id={field.name} rows={field.name === 'scope' ? 7 : 4} maxLength={field.max}
          value={values[field.name]} readOnly={pending || !!state.jobId} onChange={event => setValues({ ...values, [field.name]: event.target.value })} />}
      {field.name === 'title' && <p className="muted field-hint">The job title stays as written when you change the customer or address.</p>}
      {field.name === 'access_notes' && <p className="muted field-hint">Arrival instructions, parking and preparation for the crew.</p>}
    </div>)}
    {state.message && <p className="form-message" role="alert">{state.message}</p>}
    {state.uncertain && <p className="muted">Keep this tab open. <a href={detailPath} target="_blank" rel="noreferrer">Check the saved job in a new tab</a> before saving again. Saving again replaces the fields you changed with the values on this form.</p>}
    <div className="two-actions"><button className="button primary" disabled={pending || !dirty || !!state.jobId}>{pending ? 'Saving changes...' : state.jobId ? 'Saved. Opening...' : 'Save changes'}</button>
      <Link className="button" href={detailPath} onClick={event => { if (pending || (dirty && !window.confirm('Leave this form? Unsaved changes will be lost.'))) event.preventDefault(); }}>Cancel</Link></div>
  </form>;
}
