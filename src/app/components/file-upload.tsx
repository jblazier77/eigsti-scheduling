'use client';

import { useEffect, useRef, useState } from 'react';
import {useRouter} from 'next/navigation';
import { FILE_ACCEPT, validateFile } from '../../domain/files.ts';
import { AppError } from '../../domain/access.ts';
import { finishFileAction, prepareFileAction } from '../file-actions';

export function FileUpload({ jobId, requestId,initialFile,onComplete,onCancel }: { jobId: string; requestId: string;initialFile?:File;onComplete?:()=>void;onCancel?:()=>void }) {
  const router=useRouter();
  const [stableId] = useState(requestId);
  const [file, setFile] = useState<File | null>(initialFile??null);
  const [started, setStarted] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const finished = useRef(false);
  const active = useRef(false);
  const detailPath = '/jobs/' + jobId;
  useEffect(() => {
    if (!file) return;
    const warn = (event: BeforeUnloadEvent) => { if (!finished.current) { event.preventDefault(); event.returnValue = ''; } };
    window.addEventListener('beforeunload', warn);
    return () => window.removeEventListener('beforeunload', warn);
  }, [file]);
  async function upload(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!file || active.current) return;
    active.current = true; setBusy(true);
    try {
      const input = validateFile({ name: file.name, size: file.size, mime: file.type });
      setStarted(true); setMessage('Preparing upload...');
      const prepared = await prepareFileAction(jobId, stableId, input);
      if (!prepared.ok) { setMessage(prepared.message); return; }
      if (!prepared.upload.complete) {
        setMessage('Uploading ' + file.name + '...');
        // Only this file's scoped upload capability leaves the app server.
        // No employee session token, cookies or administrative key is sent.
        try {
          await fetch(prepared.upload.signedUrl!, { method: 'PUT', body: file, headers: { 'Content-Type': prepared.upload.mime!, 'cache-control': 'max-age=0', 'x-upsert': 'false' }, credentials: 'omit', referrerPolicy: 'no-referrer', signal: AbortSignal.timeout(120000) });
        } catch { /* Transfer may have committed. Ask the server to verify before retrying. */ }
        setMessage('Confirming upload...');
        const confirmed = await finishFileAction(jobId, prepared.upload.fileId);
        if (!confirmed.ok) { setMessage(confirmed.message); return; }
      }
      finished.current = true;
      if(onComplete){onComplete();router.refresh();}else window.location.replace(detailPath);
    } catch (error) { setMessage(error instanceof AppError ? error.message : 'The upload was not confirmed. Your selected file is retained; keep this tab open and retry.'); }
    finally { active.current = false; setBusy(false); }
  }
  return <form className="stack" onSubmit={upload}>
    {initialFile?<p className="selected-attachment">{initialFile.name}</p>:<div><label htmlFor="job-file">Photo or PDF</label><input id="job-file" type="file" accept={FILE_ACCEPT} disabled={busy || started} onChange={event => { setFile(event.target.files?.[0] ?? null); setMessage(''); }} required /></div>}
    <p className="muted">PDF, JPEG, PNG, WebP, HEIC or HEIF. Up to 10 MB per file. iPhone originals are supported; HEIC viewing depends on your device.</p>
    <p className="muted">Files are shared with employees who have access to this job.</p>
    {message && <p className="form-message" role="status" aria-live="polite">{message}</p>}
    <button className="button primary full" disabled={!file || busy}>{busy ? 'Uploading...' : started ? 'Retry this upload' : 'Upload file'}</button>
    {started && !busy && <p className="muted">Keep this tab open to retry the same file without a duplicate. <a href={detailPath} target="_blank" rel="noreferrer">Check the job in another tab</a>.</p>}
    {onCancel?<button type="button" className="button" disabled={busy} onClick={()=>{if(!started||window.confirm('The transfer may have completed. Cancel this draft? An unfinished upload can be removed in the gallery.')){finished.current=true;onCancel();}}}>Cancel</button>:<a className="button full" href={detailPath} onClick={event => { if (busy || (file && !window.confirm('Leave this upload? If unfinished, it will not appear as an available job file.'))) event.preventDefault(); else finished.current = true; }}>Back to job</a>}
  </form>;
}
