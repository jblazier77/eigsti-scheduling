'use client';

import Link from 'next/link';
import { useActionState, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { changedWorkFields, type WorkValues, type LeadOption } from '../../domain/work.ts';
import { createWorkAction, updateWorkAction } from '../work-actions';
import type { FormState } from '../actions';

export function WorkForm({ jobId, workId, requestId, original, leads, originalLeadName }: { jobId: string; workId?: string; requestId?: string; original: WorkValues; leads: LeadOption[]; originalLeadName?: string | null }) {
  const router = useRouter();
  const [baseline] = useState(original);
  const [stableRequest] = useState(requestId);
  const [values, setValues] = useState(baseline);
  const [state, action, pending] = useActionState(async (previous: FormState, form: FormData): Promise<FormState> => {
    try { return await (workId ? updateWorkAction : createWorkAction)(previous, form); }
    catch { return { message: 'The save was not confirmed. Your details are still here.', uncertain: true }; }
  }, { message: '' });
  const patch = changedWorkFields(baseline, values);
  const dirty = Object.keys(patch).length > 0;
  const locked = pending || !!state.jobId || (!workId && !!state.uncertain);
  useEffect(() => { if (state.jobId) { router.replace('/jobs/' + state.jobId); router.refresh(); } }, [state.jobId, router]);
  useEffect(() => {
    if (!dirty || state.jobId) return;
    const warn = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue = ''; };
    window.addEventListener('beforeunload', warn); return () => window.removeEventListener('beforeunload', warn);
  }, [dirty, state.jobId]);
  return <form action={action} className="stack">
    <input type="hidden" name="jobId" value={jobId} /><input type="hidden" name="workId" value={workId ?? ''} /><input type="hidden" name="requestId" value={stableRequest ?? ''} /><input type="hidden" name="values" value={JSON.stringify(workId ? patch : values)} />
    <div><label htmlFor="work-description">Work</label><input id="work-description" value={values.description} onChange={e => setValues({ ...values, description: e.target.value })} required maxLength={1000} readOnly={locked} /><p className="muted field-hint">Keep “Whole job” for simple projects, or describe a portion such as framing or finish carpentry.</p></div>
    <div><label htmlFor="work-lead">Responsible lead</label><select id="work-lead" value={values.responsible_lead ?? ''} onChange={e => setValues({ ...values, responsible_lead: e.target.value || null })} disabled={locked}>
      <option value="">Not assigned yet</option>
      {baseline.responsible_lead && !leads.some(lead => lead.id === baseline.responsible_lead) && <option value={baseline.responsible_lead}>{originalLeadName || 'Previously assigned lead'} — unavailable for new assignments</option>}
      {leads.map(lead => <option key={lead.id} value={lead.id}>{lead.display_name}</option>)}
    </select>{!leads.length && <p className="muted field-hint">No active lead accounts are available. You can save unassigned and assign a lead later.</p>}</div>
    <p className="muted">Lead ownership gives access to this job. Dates and helpers will be planned separately.</p>
    {state.message && <p className="form-message" role="alert">{state.message}</p>}
    {state.uncertain && <p className="muted">{workId ? <><a href={'/jobs/' + jobId} target="_blank" rel="noreferrer">Check the saved work in a new tab</a> before saving again. Only changed fields will be replaced.</> : 'Retry this same save to avoid adding a duplicate portion.'}</p>}
    <div className="two-actions"><button className="button primary" disabled={pending || !!state.jobId || (!!workId && !dirty)}>{pending ? 'Saving…' : state.jobId ? 'Saved. Opening…' : workId ? 'Save work and lead' : state.uncertain ? 'Retry this save' : 'Add work portion'}</button><Link className="button" href={'/jobs/' + jobId} onClick={e => { if (pending || (dirty && !window.confirm('Leave this form? Unsaved work changes will be lost.'))) e.preventDefault(); }}>Cancel</Link></div>
  </form>;
}
