'use client';
import { useActionState, useState } from 'react';
import { archiveFileAction } from '../file-actions';

export function RemoveFile({ jobId, fileId }: { jobId: string; fileId: string }) {
  const [confirm, setConfirm] = useState(false);
  const [state, action, pending] = useActionState(archiveFileAction, { message: '' });
  if (!confirm) return <button type="button" className="text-button" onClick={() => setConfirm(true)}>Remove file</button>;
  return <form action={action} className="stack"><input type="hidden" name="jobId" value={jobId} /><input type="hidden" name="fileId" value={fileId} />
    <p className="muted">Remove this file from the job? Its history and stored original will be retained.</p>
    {state.message && <p className="form-message" role="alert">{state.message}</p>}
    <div className="two-actions"><button className="button" disabled={pending}>{pending ? 'Removing...' : 'Remove file'}</button><button type="button" className="button" disabled={pending} onClick={() => setConfirm(false)}>Keep file</button></div>
  </form>;
}
