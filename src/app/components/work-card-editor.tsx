'use client';

import Link from 'next/link';
import { useActionState, useEffect, useId, useRef, useState } from 'react';
import { AppError } from '../../domain/access.ts';
import { changedWorkCard, validateWorkChanges, type JobWork, type LeadOption, type WorkValues } from '../../domain/work.ts';
import { updateWorkCardAction, type WorkCardState } from '../work-actions';

type Props = { jobId: string; work: JobWork[]; leads: LeadOption[]; requestId: string };
const valuesFor = (work: JobWork[]) => Object.fromEntries(work.map(item => [item.id, { description: item.description, responsible_lead: item.responsible_lead }]));

export function WorkCardEditor(props: Props) {
  const [reset, setReset] = useState({ version: 0, requestId: props.requestId });
  return <WorkCardForm {...props} key={reset.version} requestId={reset.requestId} onCancel={() => setReset(value => ({ version: value.version + 1, requestId: crypto.randomUUID() }))} />;
}

function WorkCardForm({ jobId, work, leads, requestId: initialRequest, onCancel }: Props & { onCancel: () => void }) {
  const fieldId = useId();
  const [baseline, setBaseline] = useState(work);
  const [values, setValues] = useState<Record<string, WorkValues>>(() => valuesFor(work));
  const [requestId, setRequestId] = useState(initialRequest);
  const lastServer = useRef(JSON.stringify(work));
  const changes = changedWorkCard(baseline, values);
  const dirty = changes.length > 0;
  const [state, action, pending] = useActionState(async (previous: WorkCardState, form: FormData): Promise<WorkCardState> => {
    // Bound the direct action request before sending; retain every draft if it
    // cannot fit within the existing 32 KB Server Action limit.
    try { validateWorkChanges(JSON.parse(String(form.get('values')))); }
    catch (error) { return { message: error instanceof AppError ? error.message : 'Check the work details.' }; }
    try {
      const result = await updateWorkCardAction(previous, form);
      if (result.jobId) {
        if (!result.work) throw new Error('Missing saved work');
        setBaseline(result.work); setValues(valuesFor(result.work));
        // Ignore the pre-save props until revalidation delivers fresh data.
        lastServer.current = JSON.stringify(work);
        setRequestId(crypto.randomUUID());
        // revalidatePath in the Server Action already returns refreshed UI in
        // its response. A second router refresh needlessly extends the action.
        return { message: 'Work and leads saved.', jobId: result.jobId };
      }
      return result;
    } catch { return { message: 'The save was not confirmed. Keep these changes and retry this same save.', uncertain: true }; }
  }, { message: '' });
  const locked = pending || !!state.uncertain;
  useEffect(() => {
    const signature = JSON.stringify(work);
    if (!pending && !dirty && !state.uncertain && lastServer.current !== signature) {
      lastServer.current = signature; setBaseline(work); setValues(valuesFor(work));
    }
  }, [work, pending, dirty, state.uncertain]);
  useEffect(() => {
    if (!dirty) return;
    const warn = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue = ''; };
    window.addEventListener('beforeunload', warn); return () => window.removeEventListener('beforeunload', warn);
  }, [dirty]);
  return <>
    <div className="section-heading"><h3>Work and leads</h3><Link className="button" href={'/jobs/' + jobId + '/work/new'} onClick={event => {
      if (pending || (dirty && !window.confirm('Leave this card? Unsaved work changes will be lost.'))) event.preventDefault();
    }}>Add work portion</Link></div>
    <form action={action} className="stack">
      <input type="hidden" name="jobId" value={jobId} /><input type="hidden" name="requestId" value={requestId} /><input type="hidden" name="values" value={JSON.stringify(changes)} />
      {baseline.map(item => <div className="contact-entry" key={item.id}>{item.completion === 'open' ? <div className="work-inline-fields">
        <div><label htmlFor={fieldId + item.id + '-work'}>Work</label><input id={fieldId + item.id + '-work'} value={values[item.id].description} onChange={event => setValues({ ...values, [item.id]: { ...values[item.id], description: event.target.value } })} required maxLength={1000} readOnly={locked} /></div>
        <div><label htmlFor={fieldId + item.id + '-lead'}>Responsible lead</label><select id={fieldId + item.id + '-lead'} value={values[item.id].responsible_lead ?? ''} disabled={locked} onChange={event => setValues({ ...values, [item.id]: { ...values[item.id], responsible_lead: event.target.value || null } })}>
          <option value="">Not assigned yet</option>
          {item.responsible_lead && !leads.some(lead => lead.id === item.responsible_lead) && <option value={item.responsible_lead}>{item.lead_name || 'Previously assigned lead'} - unavailable for new assignments</option>}
          {leads.map(lead => <option key={lead.id} value={lead.id}>{lead.display_name}</option>)}
        </select></div>
      </div> : <><h3>{item.description}</h3><p>{item.lead_name || 'Lead not assigned yet'} <span className="badge">Completed</span></p></>}</div>)}
      {!leads.length && <p className="muted">No active lead accounts are available. You can leave work unassigned.</p>}
      {state.message && <p className="form-message" role="status">{state.message}</p>}
      {state.uncertain && <p className="muted"><a href={'/jobs/' + jobId} target="_blank" rel="noreferrer">Check saved work in a new tab</a> if needed. Your changes are retained. Retry to confirm whether the entire card was saved.</p>}
      <div className="work-inline-actions"><button className="button primary" aria-busy={pending} disabled={pending || !dirty}>{pending ? 'Saving...' : state.uncertain ? 'Retry save' : !dirty && state.jobId ? 'Saved' : 'Save'}</button><button type="button" className="button" disabled={pending || (!dirty && !state.message)} onClick={() => {
        if (!state.uncertain || window.confirm('The last save may already have completed. Discard this draft and show the last loaded values?')) onCancel();
      }}>Cancel</button></div>
    </form>
  </>;
}
