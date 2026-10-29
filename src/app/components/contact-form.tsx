'use client';

import Link from 'next/link';
import { useActionState, useEffect, useId, useState } from 'react';
import { useRouter } from 'next/navigation';
import { changedContactFields, contactFields, contactTypes, emptyContact, type ContactValues } from '../../domain/contacts.ts';
import type { Subcontractor } from '../../domain/job-classification.ts';
import { archiveContactAction, archiveContactInlineAction, createContactAction, updateContactAction } from '../contact-actions';
import type { FormState } from '../actions';
import { createCommittedContactAction } from '../commitment-actions';
import { isSubcontractor } from '../../domain/commitments.ts';

export function ContactForm({ jobId, contactId, requestId, original = emptyContact, onDone, directory=[], allowCommitment=false }: { jobId: string; contactId?: string; requestId?: string; original?: ContactValues; onDone?:()=>void; directory?:Pick<Subcontractor,'id'|'name'|'phone'|'email'>[]; allowCommitment?:boolean }) {
  const router = useRouter();
  const formId = useId();
  const [baseline] = useState(original);
  const [stableRequestId] = useState(requestId);
  const [values, setValues] = useState(baseline);
  const [remove, setRemove] = useState(false);
  const [commitment,setCommitment]=useState({commitment_date:'',note:''});
  const withCommitment=!contactId&&allowCommitment&&isSubcontractor(values.relationship)&&(!!commitment.commitment_date||!!commitment.note.trim());
  const [state, action, pending] = useActionState(async (previous: FormState, form: FormData): Promise<FormState> => {
    try {
      return await (contactId ? updateContactAction : withCommitment ? createCommittedContactAction : createContactAction)(previous, form);
    } catch { return { message: 'The save was not confirmed. Your contact details are still here.', uncertain: true }; }
  }, { message: '' });
  // Pass the archive action directly so its framework redirect is not caught
  // by the save action's interrupted-transport fallback.
  const [archiveState, archiveAction, archiving] = useActionState(onDone ? async (previous:FormState,form:FormData):Promise<FormState> => {
    try {return await archiveContactInlineAction(previous,form);}
    catch {return {message:'Removal was not confirmed. Check the contact list before retrying.',uncertain:true};}
  } : archiveContactAction, { message: '' });
  const busy = pending || archiving;
  const patch = changedContactFields(baseline, values);
  const dirty = Object.keys(patch).length > 0 || !!commitment.commitment_date || !!commitment.note;
  const detailPath = '/jobs/' + jobId;
  const savedJob = state.jobId || archiveState.jobId;
  const locked = busy || !!savedJob || (!contactId && !!state.uncertain);
  useEffect(() => {
    if (savedJob) { if (onDone) onDone(); else router.replace('/jobs/' + savedJob); router.refresh(); }
  }, [savedJob, router, onDone]);
  useEffect(() => {
    if (!dirty || savedJob) return;
    const warn = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue = ''; };
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [dirty, savedJob]);
  const cancel = () => { if (!busy && (!dirty || window.confirm('Discard unsaved contact changes?'))) onDone?.(); };
  return <form action={action} className={'stack'+(onDone?' compact-contact-form':'')}>
    <input type="hidden" name="jobId" value={jobId} />
    <input type="hidden" name="contactId" value={contactId ?? ''} />
    <input type="hidden" name="requestId" value={stableRequestId ?? ''} />
    <input type="hidden" name="values" value={JSON.stringify(contactId ? patch : values)} />
    <input type="hidden" name="commitment" value={JSON.stringify({...commitment,commitment_date:commitment.commitment_date||null})}/>
    <div className="contact-form-fields">{contactFields.map(field => <div key={field.name} className={field.name==='notes'?'contact-notes-field':undefined}>
      <label htmlFor={formId + field.name}>{field.label}{!field.required && <span className="muted"> (optional)</span>}</label>
      {field.name==='relationship' ? <><select id={formId+field.name} disabled={locked} value={values.relationship} onChange={event=>setValues({...values,relationship:event.target.value})}>
        <option value="">Choose type</option>{contactTypes.map(type=><option key={type}>{type}</option>)}
        {values.relationship && !contactTypes.some(type=>type===values.relationship) && <option>{values.relationship}</option>}
      </select>{!contactId && ['Subcontractor','Vendor'].includes(values.relationship) && <div className="directory-contact-picker"><label htmlFor={formId+'directory'}>Use existing company contact</label><select id={formId+'directory'} defaultValue="" disabled={locked} onChange={event=>{const entry=directory.find(item=>item.id===event.target.value);if(entry)setValues({...values,name:entry.name,phone:entry.phone,email:entry.email});}}><option value="">Enter manually or choose existing</option>{directory.map(entry=><option key={entry.id} value={entry.id}>{entry.name}</option>)}</select><p className="muted field-hint">Copies contact details to this job. Directory changes do not update this copy.</p></div>}</>
        : field.name === 'notes' ? <textarea id={formId+field.name} rows={2} maxLength={field.max} value={values[field.name]} readOnly={locked} onChange={event => setValues({ ...values, [field.name]: event.target.value })} />
        : <input id={formId+field.name} type={field.name === 'phone' ? 'tel' : field.name === 'email' ? 'email' : 'text'} required={field.required} maxLength={field.max} value={values[field.name]} readOnly={locked} onChange={event => setValues({ ...values, [field.name]: event.target.value })} />}
    </div>)}</div>
    {!contactId&&allowCommitment&&isSubcontractor(values.relationship)&&<fieldset disabled={locked} className="commitment-fields"><legend>Subcontractor commitment (optional)</legend><label>Date<input type="date" min="2000-01-01" max="2099-12-31" value={commitment.commitment_date} onChange={e=>setCommitment({...commitment,commitment_date:e.target.value})}/></label><label>What was promised or is needed<textarea rows={2} maxLength={2000} value={commitment.note} onChange={e=>setCommitment({...commitment,note:e.target.value})}/></label></fieldset>}
    {state.message && <p className="form-message" role="alert">{state.message}</p>}
    {archiveState.message && <p className="form-message" role="alert">{archiveState.message}</p>}
    {(state.uncertain || archiveState.uncertain) && <p className="muted">{!contactId ? 'Your details are retained. Retry this same save to avoid adding a duplicate.' : <><a href={detailPath} target="_blank" rel="noreferrer">Check the saved contacts in a new tab</a> before trying again. Saving again replaces the fields changed on this form.</>}</p>}
    <div className="two-actions"><button className="button primary" name="intent" value="save" disabled={busy || !!state.jobId || (!!contactId && !dirty)}>{pending ? 'Saving...' : state.jobId ? 'Saved. Opening...' : state.uncertain && !contactId ? 'Retry this save' : contactId ? 'Save contact' : 'Add contact'}</button>
      {onDone ? <button className="button" type="button" disabled={busy} onClick={cancel}>Cancel</button> : <Link className="button" href={detailPath} onClick={event => { if (busy || (dirty && !window.confirm('Leave this form? Unsaved contact changes will be lost.'))) event.preventDefault(); }}>Cancel</Link>}</div>
    {contactId && <div className="contact-removal">{!remove ? <button className="text-button" type="button" disabled={locked} onClick={() => setRemove(true)}>Remove contact from job</button>
      : <><p>Remove this contact from the job? Their history will be retained.</p><div className="two-actions"><button className="button" formAction={archiveAction} formNoValidate disabled={locked}>{archiving ? 'Removing...' : 'Remove contact'}</button><button className="button" type="button" disabled={locked} onClick={() => setRemove(false)}>Keep contact</button></div></>}</div>}
  </form>;
}
