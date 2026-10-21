'use client';

import Link from 'next/link';
import { useActionState, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { changedContactFields, contactFields, emptyContact, type ContactValues } from '../../domain/contacts.ts';
import { archiveContactAction, createContactAction, updateContactAction } from '../contact-actions';
import type { FormState } from '../actions';

export function ContactForm({ jobId, contactId, requestId, original = emptyContact }: { jobId: string; contactId?: string; requestId?: string; original?: ContactValues }) {
  const router = useRouter();
  const [baseline] = useState(original);
  const [stableRequestId] = useState(requestId);
  const [values, setValues] = useState(baseline);
  const [remove, setRemove] = useState(false);
  const [state, action, pending] = useActionState(async (previous: FormState, form: FormData): Promise<FormState> => {
    try {
      return await (contactId ? updateContactAction : createContactAction)(previous, form);
    } catch { return { message: 'The save was not confirmed. Your contact details are still here.', uncertain: true }; }
  }, { message: '' });
  // Pass the archive action directly so its framework redirect is not caught
  // by the save action's interrupted-transport fallback.
  const [archiveState, archiveAction, archiving] = useActionState(archiveContactAction, { message: '' });
  const busy = pending || archiving;
  const patch = changedContactFields(baseline, values);
  const dirty = Object.keys(patch).length > 0;
  const detailPath = '/jobs/' + jobId;
  const locked = busy || !!state.jobId || (!contactId && !!state.uncertain);
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
    <input type="hidden" name="contactId" value={contactId ?? ''} />
    <input type="hidden" name="requestId" value={stableRequestId ?? ''} />
    <input type="hidden" name="values" value={JSON.stringify(contactId ? patch : values)} />
    {contactFields.map(field => <div key={field.name}>
      <label htmlFor={'contact-' + field.name}>{field.label}{!field.required && <span className="muted"> (optional)</span>}</label>
      {field.name === 'notes' ? <textarea id={'contact-' + field.name} rows={4} maxLength={field.max} value={values[field.name]} readOnly={locked} onChange={event => setValues({ ...values, [field.name]: event.target.value })} />
        : <input id={'contact-' + field.name} type={field.name === 'phone' ? 'tel' : field.name === 'email' ? 'email' : 'text'} required={field.required} maxLength={field.max} value={values[field.name]} readOnly={locked} onChange={event => setValues({ ...values, [field.name]: event.target.value })} />}
      {field.name === 'relationship' && <p className="muted field-hint">For example: spouse, site contact, electrician or plumber.</p>}
    </div>)}
    {state.message && <p className="form-message" role="alert">{state.message}</p>}
    {archiveState.message && <p className="form-message" role="alert">{archiveState.message}</p>}
    {(state.uncertain || archiveState.uncertain) && <p className="muted">{!contactId ? 'Your details are retained. Retry this same save to avoid adding a duplicate.' : <><a href={detailPath} target="_blank" rel="noreferrer">Check the saved contacts in a new tab</a> before trying again. Saving again replaces the fields changed on this form.</>}</p>}
    <div className="two-actions"><button className="button primary" name="intent" value="save" disabled={busy || !!state.jobId || (!!contactId && !dirty)}>{pending ? 'Saving...' : state.jobId ? 'Saved. Opening...' : state.uncertain && !contactId ? 'Retry this save' : contactId ? 'Save contact' : 'Add contact'}</button>
      <Link className="button" href={detailPath} onClick={event => { if (busy || (dirty && !window.confirm('Leave this form? Unsaved contact changes will be lost.'))) event.preventDefault(); }}>Cancel</Link></div>
    {contactId && <div className="contact-removal">{!remove ? <button className="text-button" type="button" disabled={locked} onClick={() => setRemove(true)}>Remove contact from job</button>
      : <><p>Remove this contact from the job? Their history will be retained.</p><div className="two-actions"><button className="button" formAction={archiveAction} formNoValidate disabled={locked}>{archiving ? 'Removing...' : 'Remove contact'}</button><button className="button" type="button" disabled={locked} onClick={() => setRemove(false)}>Keep contact</button></div></>}</div>}
  </form>;
}
