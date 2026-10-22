'use client';

import Link from 'next/link';
import { useActionState, useEffect, useRef, useState } from 'react';
import { moveQueueItem, type LeadQueue } from '../../domain/queues.ts';
import { saveQueueAction, type QueueState } from '../queue-actions';

type Props = { queue: LeadQueue; requestId: string };
export function QueueEditor(props: Props) {
  const [reset, setReset] = useState({ version: 0, requestId: props.requestId });
  return <QueueForm {...props} key={reset.version} requestId={reset.requestId} onCancel={() => setReset(value => ({ version: value.version + 1, requestId: crypto.randomUUID() }))} />;
}
function QueueForm({ queue, requestId: initialRequest, onCancel }: Props & { onCancel: () => void }) {
  const [baseline, setBaseline] = useState(queue);
  const [order, setOrder] = useState(() => queue.items.map(item => item.id));
  const [requestId, setRequestId] = useState(initialRequest);
  const lastServer = useRef(JSON.stringify(queue));
  const dirty = JSON.stringify(order) !== JSON.stringify(baseline.items.map(item => item.id));
  const [state, action, pending] = useActionState(async (previous: QueueState, form: FormData): Promise<QueueState> => {
    try {
      const result = await saveQueueAction(previous, form);
      if (result.queue) {
        setBaseline(result.queue); setOrder(result.queue.items.map(item => item.id));
        lastServer.current = JSON.stringify(queue); setRequestId(crypto.randomUUID());
        return { message: 'Queue saved.', saved: true };
      }
      return result;
    } catch { return { message: 'The save was not confirmed. Your order is retained for retry.', uncertain: true }; }
  }, { message: '' });
  const locked = pending || !!state.uncertain || !!state.membershipChanged;
  useEffect(() => {
    const signature = JSON.stringify(queue);
    if (!pending && !dirty && !state.uncertain && !state.membershipChanged && lastServer.current !== signature) {
      lastServer.current = signature; setBaseline(queue); setOrder(queue.items.map(item => item.id));
    }
  }, [queue, pending, dirty, state.uncertain, state.membershipChanged]);
  useEffect(() => {
    if (!dirty) return;
    const warn = (event: BeforeUnloadEvent) => { event.preventDefault(); event.returnValue = ''; };
    window.addEventListener('beforeunload', warn); return () => window.removeEventListener('beforeunload', warn);
  }, [dirty]);
  const byId = new Map(baseline.items.map(item => [item.id, item]));
  return <section className="card"><h2>{baseline.lead_name}</h2><p className="muted">Move work up or down to set its priority. Dates and helpers are planned separately.</p>
    {!order.length && <p>No open work is assigned to this lead yet.</p>}
    <form action={action} className="stack">
      <input type="hidden" name="leadId" value={baseline.lead_id} /><input type="hidden" name="requestId" value={requestId} /><input type="hidden" name="order" value={JSON.stringify(order)} />
      <ol className="queue-list">{order.map((id, index) => { const item = byId.get(id)!; return <li key={id} className="queue-row"><span className="queue-position">{index + 1}</span><div className="queue-details"><h3>{item.description}</h3><p>{item.job_title}</p><span className="badge">{item.readiness === 'ready' ? 'Ready' : item.waiting_until ? 'Waiting until ' + item.waiting_until : 'Waiting'}</span><p><Link href={'/jobs/' + item.job_id} onClick={event => { if (pending || (dirty && !window.confirm('Leave this queue? Unsaved order changes will be lost.'))) event.preventDefault(); }}>Open job</Link></p></div><div className="queue-moves"><button type="button" className="button" disabled={locked || index === 0} aria-label={'Move ' + item.description + ' up'} onClick={() => setOrder(moveQueueItem(order, id, -1))}>Up</button><button type="button" className="button" disabled={locked || index === order.length - 1} aria-label={'Move ' + item.description + ' down'} onClick={() => setOrder(moveQueueItem(order, id, 1))}>Down</button></div></li>; })}</ol>
      {state.message && <p className="form-message" role="status">{state.message}</p>}
      {state.membershipChanged && <button type="button" className="button" onClick={() => window.location.reload()}>Reload queue</button>}
      {state.uncertain && <p className="muted">Retry confirms this same save. It will not reapply an old order over a newer saved order.</p>}
      <div className="work-inline-actions"><button className="button primary" aria-busy={pending} disabled={pending || !dirty || state.membershipChanged}>{pending ? 'Saving...' : state.uncertain ? 'Retry save' : !dirty && state.saved ? 'Saved' : 'Save'}</button><button type="button" className="button" disabled={pending || (!dirty && !state.message)} onClick={() => { if (!state.uncertain || window.confirm('The last save may already have completed. Discard this draft?')) onCancel(); }}>Cancel</button></div>
    </form>
  </section>;
}
