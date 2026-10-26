'use client';
import { useActionState, useEffect, useState } from 'react';
import { saveVisitAction, type VisitState } from '../visit-actions';
import { companyToday, visitPatch, type Visit, type VisitValues } from '../../domain/visits.ts';
type Person = { id: string; display_name: string };
type Work = { id: string; description: string };
type Props = { visit?: Visit; work: Work[]; leads: Person[]; pm: boolean; actorId: string; requestId: string; initialHelpers?:number; onSaved?: (visit: Visit) => void };
export function VisitEditor(props: Props) {
  const [resetState, setResetState] = useState({ version: 0, requestId: props.requestId });
  return <VisitForm {...props} requestId={resetState.requestId} key={resetState.version} reset={() => setResetState(v => ({ version: v.version + 1, requestId: crypto.randomUUID() }))} />;
}
function VisitForm({ visit, work, leads, pm, actorId, requestId: initialId, reset, onSaved,initialHelpers=0 }: Props & { reset: () => void }) {
  const initial: VisitValues = visit ? { start_date: visit.start_date, end_date: visit.end_date, slot: visit.slot, start_time: visit.start_time?.slice(0, 5) ?? null, end_time: visit.end_time?.slice(0, 5) ?? null, coordinator_id: visit.coordinator_id, required_helpers: visit.required_helpers, certainty: visit.certainty } : { start_date: companyToday(), end_date: companyToday(), slot: 'day', start_time: null, end_time: null, coordinator_id: pm ? leads[0]?.id ?? '' : actorId, required_helpers: initialHelpers, certainty: 'tentative' };
  const [baseline, setBaseline] = useState(initial), [values, setValues] = useState(initial);
  const [workId, setWorkId] = useState(visit?.work_item_id ?? work[0]?.id ?? '');
  const [requestId, setRequestId] = useState(initialId);
  const [state, action, pending] = useActionState(async (previous: VisitState, form: FormData): Promise<VisitState> => {
    try {
      const result = await saveVisitAction(previous, form);
      if (result.visit) { const v = result.visit; const next = { ...v, start_time: v.start_time?.slice(0, 5) ?? null, end_time: v.end_time?.slice(0, 5) ?? null }; setBaseline(next); setValues(next); setRequestId(crypto.randomUUID()); onSaved?.(v); }
      return result;
    } catch { return { message: 'The save was not confirmed. Keep this form and retry.', uncertain: true }; }
  }, { message: '' });
  const dirty = !visit || Object.keys(visitPatch(baseline, values)).length > 0;
  const locked = pending || !!state.uncertain;
  useEffect(() => {
    if (!dirty || (!visit && state.visit)) return;
    const warn = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue = ''; };
    window.addEventListener('beforeunload', warn); return () => window.removeEventListener('beforeunload', warn);
  }, [dirty, visit, state.visit]);
  function field<K extends keyof VisitValues>(key: K, value: VisitValues[K]) { setValues(previous => ({ ...previous, [key]: value })); }
  if (!visit && state.visit) return <div role="status"><p>Work saved below. Edit dates and crew directly on its card.</p><button className="button" onClick={reset}>Add another date</button></div>;
  return <form action={action} className="stack">
    <input type="hidden" name="operation" value="save" /><input type="hidden" name="workId" value={workId} /><input type="hidden" name="visitId" value={visit?.id ?? ''} /><input type="hidden" name="requestId" value={requestId} /><input type="hidden" name="fields" value={JSON.stringify(Object.keys(visitPatch(baseline, values)))} />
    {Object.entries(values).filter(([key]) => ['start_date','end_date','slot','start_time','end_time','coordinator_id','required_helpers','certainty'].includes(key)).map(([key,value]) => <input type="hidden" key={key} name={key} value={value ?? ''} />)}
    <fieldset disabled={locked || visit?.state !== undefined && visit.state !== 'planned'} className="visit-fields">
      {!visit&&work.length>1 && <label>Work<select value={workId} onChange={e => setWorkId(e.target.value)} required>{work.map(w => <option key={w.id} value={w.id}>{w.description}</option>)}</select></label>}
      {pm ? <label>Coordinating lead<select name="coordinator_id" value={values.coordinator_id??''} onChange={e => field('coordinator_id', e.target.value||null)}><option value="">Not assigned yet</option>{leads.map(lead => <option key={lead.id} value={lead.id}>{lead.display_name}</option>)}</select></label> : <input type="hidden" name="coordinator_id" value={values.coordinator_id??''} />}
      <div className="two-actions"><label>First day<input type="date" name="start_date" required value={values.start_date} onChange={e => { field('start_date', e.target.value); if (values.end_date < e.target.value) field('end_date', e.target.value); }} /></label><label>Last day<input type="date" name="end_date" required value={values.end_date} onChange={e => field('end_date', e.target.value)} /></label></div>
      <label>Time (optional)<select name="slot" value={values.slot} onChange={e => setValues(v => ({ ...v, slot: e.target.value as VisitValues['slot'], start_time: null, end_time: null }))}><option value="day">No time set</option><option value="all_day">Reserve all day</option><option value="morning">Morning</option><option value="afternoon">Afternoon</option><option value="timed">Specific hours (one day)</option></select></label>
      {values.slot === 'timed' && <div className="two-actions"><label>Start<input name="start_time" type="time" min="07:00" max="15:30" required value={values.start_time ?? ''} onChange={e => field('start_time', e.target.value)} /></label><label>End<input name="end_time" type="time" min="07:00" max="15:30" required value={values.end_time ?? ''} onChange={e => field('end_time', e.target.value)} /></label></div>}
      <label>Helpers needed<input name="required_helpers" type="number" min="0" max="20" required value={values.required_helpers} onChange={e => field('required_helpers', Number(e.target.value))} /></label>
    </fieldset>
    <p className="muted">Central time. Weekdays, 7:00 AM–3:30 PM; multi-day work skips weekends. No time set allows several jobs on the same day. Optional time blocks reserve named people for tentative and confirmed plans.</p>
    {state.message && <p role="status" className="form-message">{state.message}</p>}
    <div className="two-actions"><button className="button primary" aria-busy={pending} disabled={pending || !dirty || !workId || visit?.state !== undefined && visit.state !== 'planned'}>{pending ? 'Saving...' : state.uncertain ? 'Retry same save' : 'Save work'}</button><button className="button" type="button" disabled={pending} onClick={() => { if (!state.uncertain || window.confirm('The save may have completed. Discard this draft?')) reset(); }}>Cancel</button></div>
  </form>;
}
export function CancelVisit({ visit, requestId: initialRequestId }: { visit: Visit; requestId: string }) {
  const [requestId] = useState(initialRequestId);
  const [state, action, pending] = useActionState(saveVisitAction, { message: '' });
  return <form action={action} onSubmit={e => { if (!window.confirm('Remove this work from the schedule and release everyone from these dates? The work stays on the job.')) e.preventDefault(); }}><input type="hidden" name="operation" value="cancel" /><input type="hidden" name="workId" value={visit.work_item_id} /><input type="hidden" name="visitId" value={visit.id} /><input type="hidden" name="requestId" value={requestId} /><button className="button" disabled={pending || !!state.visit} aria-busy={pending}>{pending ? 'Cancelling...' : state.visit ? 'Removed from schedule' : 'Remove from schedule'}</button>{state.message && <p role="status">{state.message}</p>}</form>;
}




