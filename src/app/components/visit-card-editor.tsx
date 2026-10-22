'use client';
import { useActionState, useEffect, useState } from 'react';
import { saveVisitAction, type VisitState } from '../visit-actions';
import { valuesFromVisit, selectedHelpers, visitCardChange, chooseVisitHelper, type Visit, type VisitValues, type StaffOption } from '../../domain/visits.ts';
type Props = { visit: Visit; leads: { id: string; display_name: string }[]; options: StaffOption[]; pm: boolean; requestId: string; onSaved: (visit: Visit) => void };
export function VisitCardEditor(props: Props) {
  const [resetState,setResetState] = useState({ version: 0, requestId: props.requestId });
  return <VisitCardForm {...props} key={resetState.version} requestId={resetState.requestId} reset={() => setResetState(v => ({ version:v.version+1,requestId:crypto.randomUUID() }))} />;
}
function VisitCardForm({ visit, leads, options, pm, requestId: initialRequest, onSaved, reset }: Props & { reset: () => void }) {
  const [baseline,setBaseline] = useState(visit);
  const [values,setValues] = useState(() => valuesFromVisit(visit));
  const [helpers,setHelpers] = useState(() => selectedHelpers(visit));
  const [requestId,setRequestId] = useState(initialRequest);
  const changes = visitCardChange(baseline,values,helpers);
  const dirty = Object.keys(changes.patch).length>0 || changes.helpers!==null;
  const [state,action,pending] = useActionState(async (previous: VisitState,form: FormData): Promise<VisitState> => {
    try {
      const result = await saveVisitAction(previous,form);
      if (result.visit) { setBaseline(result.visit); setValues(valuesFromVisit(result.visit)); setHelpers(selectedHelpers(result.visit)); setRequestId(crypto.randomUUID()); onSaved(result.visit); return { message:'Visit saved.' }; }
      return result;
    } catch { return { message:'The save was not confirmed. Your whole visit draft is retained for retry.',uncertain:true }; }
  },{ message:'' });
  const locked = pending || !!state.uncertain;
  useEffect(() => {
    if (!dirty) return;
    const warn = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue=''; };
    window.addEventListener('beforeunload',warn); return () => window.removeEventListener('beforeunload',warn);
  },[dirty]);
  function field<K extends keyof VisitValues>(key: K,value: VisitValues[K]) { setValues(v => ({ ...v,[key]:value })); }
  function choose(id: string,checked: boolean) {
    const next = chooseVisitHelper(values,helpers,id,checked);
    setHelpers(next.helpers); setValues(next.values);
  }
  const original = selectedHelpers(baseline);
  const people = [...options,...baseline.participants.filter(p => p.duty==='helping' && !options.some(o => o.id===p.id)).map(p => ({ id:p.id,name:p.name+' (inactive)',busy:false }))];
  return <form action={action} className="stack">
    <input type="hidden" name="operation" value="card" /><input type="hidden" name="workId" value={baseline.work_item_id} /><input type="hidden" name="visitId" value={baseline.id} /><input type="hidden" name="requestId" value={requestId} />
    <input type="hidden" name="fields" value={JSON.stringify(Object.keys(changes.patch))} /><input type="hidden" name="helpersMode" value={changes.helpers===null?'unchanged':'changed'} />
    {Object.entries(values).map(([key,value]) => <input type="hidden" key={key} name={key} value={value??''} />)}
    {helpers.map(id => <input type="hidden" name="helper" key={id} value={id} />)}
    <fieldset disabled={locked} className="visit-fields">
      {pm && <label>Coordinating lead<select value={values.coordinator_id} onChange={e => { field('coordinator_id',e.target.value); setHelpers(h => h.filter(id => id!==e.target.value)); }}>{leads.map(p => <option key={p.id} value={p.id}>{p.display_name}</option>)}</select></label>}
      <div className="two-actions"><label>First day<input type="date" required value={values.start_date} onChange={e => { field('start_date',e.target.value); if (values.end_date<e.target.value) field('end_date',e.target.value); }} /></label><label>Last day<input type="date" required value={values.end_date} onChange={e => field('end_date',e.target.value)} /></label></div>
      <label>Time (optional)<select value={values.slot} onChange={e => setValues(v => ({ ...v,slot:e.target.value as VisitValues['slot'],start_time:null,end_time:null }))}><option value="day">No time set</option><option value="all_day">Reserve all day</option><option value="morning">Morning</option><option value="afternoon">Afternoon</option><option value="timed">Specific hours (one day)</option></select></label>
      {values.slot==='timed' && <div className="two-actions"><label>Start<input type="time" required min="07:00" max="15:30" value={values.start_time??''} onChange={e => field('start_time',e.target.value)} /></label><label>End<input type="time" required min="07:00" max="15:30" value={values.end_time??''} onChange={e => field('end_time',e.target.value)} /></label></div>}
      <div className="two-actions"><label>Helpers needed<input type="number" min="0" max="20" required value={values.required_helpers} onChange={e => field('required_helpers',Number(e.target.value))} /></label><label>Plan<select value={values.certainty} onChange={e => field('certainty',e.target.value as VisitValues['certainty'])}><option value="tentative">Tentative</option><option value="confirmed">Confirmed</option></select></label></div>
      <h4>Named help</h4><p>{helpers.length} of {values.required_helpers} helper spaces filled. Selecting someone adds a space if needed.</p>
      {people.filter(p => p.id!==values.coordinator_id).map(person => <label className="staff-choice" key={person.id}><input type="checkbox" checked={helpers.includes(person.id)} disabled={(!pm && original.includes(person.id)) || (!helpers.includes(person.id) && helpers.length>=20)} onChange={e => choose(person.id,e.target.checked)} />{person.name}{person.busy?' · Busy at saved time':''}</label>)}
      {!pm && <p className="muted">Existing named help stays assigned. You can fill vacant places.</p>}
    </fieldset>
    <p className="muted">Central time. Dates alone allow several jobs per day. Availability is checked for your chosen dates when you save.</p>
    {state.message && <p role="status" className="form-message">{state.message}</p>}
    <div className="two-actions"><button className="button primary" aria-busy={pending} disabled={pending||!dirty}>{pending?'Saving...':state.uncertain?'Retry same save':!dirty&&state.message==='Visit saved.'?'Saved':'Save'}</button><button className="button" type="button" disabled={pending||(!dirty&&!state.message)} onClick={() => { if (!state.uncertain || window.confirm('The save may already have completed. Discard this whole draft?')) reset(); }}>Cancel</button></div>
  </form>;
}
