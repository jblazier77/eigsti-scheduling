'use client';
import { useState } from 'react';
import { loadVisitEditorAction, type VisitEditorData } from '../visit-editor-actions';
import { CancelVisit } from './visit-editor';
import { VisitCardEditor } from './visit-card-editor';
import { dateLabel, slotLabel, type Visit } from '../../domain/visits.ts';
export function InlineVisit({ visit: initialVisit, editable, showJob = false }: { visit: Visit; editable: boolean; showJob?: boolean }) {
  const [data, setData] = useState<VisitEditorData | null>(null);
  const [loadedSignature, setLoadedSignature] = useState('');
  const [loading, setLoading] = useState(false), [message, setMessage] = useState('');
  const visit = data && loadedSignature === initialVisit.updated_at ? data.visit : initialVisit;
  async function load() {
    if (loading) return;
    setLoading(true); setMessage('');
    try { const result = await loadVisitEditorAction(initialVisit.id); if (result.data) { setData(result.data); setLoadedSignature(initialVisit.updated_at); } else setMessage(result.message ?? 'Could not load this visit.'); }
    catch { setMessage('Could not load this visit. Try again.'); }
    finally { setLoading(false); }
  }
  return <div className="inline-visit">
    <span className="badge">{visit.state === 'cancelled' ? 'Cancelled' : visit.certainty === 'confirmed' ? 'Confirmed' : 'Tentative'}{visit.state === 'completed' ? ' · Completed' : ''}</span>
    <h3>{visit.description}</h3>{showJob && <p>{visit.job_title}</p>}
    <p>{dateLabel(visit.start_date)}{visit.end_date !== visit.start_date ? ' – ' + dateLabel(visit.end_date) : ''} · {slotLabel(visit)}</p>
    {visit.day_conflicts > 0 && <p className="form-message">Other plans share this day. Review the workload; date-only plans don’t reserve exclusive hours.</p>}
    <p>{visit.participants.map(p => p.name + (p.duty === 'leading' ? ' (leading)' : ' (helping)')).join(', ')}</p>
    {visit.state === 'planned' && <p>{Math.max(0, visit.required_helpers - visit.participants.filter(p => p.duty === 'helping').length)} helper spaces vacant</p>}
    {editable && visit.state === 'planned' && <details className="inline-visit-editor" onToggle={event => { if (event.currentTarget.open && !data) void load(); }}>
      <summary className="button">Edit visit &amp; staffing</summary>
      {loading && <p role="status">Loading visit...</p>}
      {message && <div role="status"><p>{message}</p><button className="button" type="button" onClick={() => void load()} disabled={loading}>Try again</button></div>}
      {data && <div className="inline-visit-panels">
        <VisitCardEditor visit={data.visit} leads={data.leads} options={data.options} pm={data.pm} requestId={data.requests.dates} onSaved={v => { setData(d => d ? { ...d, visit: v } : d); void load(); }} />
        <section className="inline-visit-cancel"><CancelVisit visit={data.visit} requestId={data.requests.cancel} /></section>
      </div>}
    </details>}
  </div>;
}
