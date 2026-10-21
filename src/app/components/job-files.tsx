import Link from 'next/link';
import { currentSession } from '../../lib/session';
import { appConfig } from '../../lib/config';
import { authClient } from '../../lib/supabase-server';
import { AppError, hasRole } from '../../domain/access.ts';
import { FileSession } from '../../server/files.ts';
import { RemoveFile } from './remove-file';

export async function JobFiles({ jobId }: { jobId: string }) {
  const session = await currentSession();
  const config = appConfig();
  if (!session || !config) return null;
  const client = await authClient();
  const { data } = await client.auth.getSession();
  if (!data.session) return null;
  const gateway = new FileSession(config, data.session.access_token);
  let files;
  try { files = await gateway.listFiles(jobId); }
  catch (error) {
    if (!(error instanceof AppError) || error.code !== 'schema_pending') throw error;
    return <section className="card"><h3>Job files</h3><p className="muted">Job files are temporarily unavailable. Please try again later.</p></section>;
  }
  const canWrite = hasRole(session.actor, 'pm') || hasRole(session.actor, 'lead');
  return <section className="card"><div className="section-heading"><h3>Job files</h3>{canWrite && <Link className="button" href={'/jobs/' + jobId + '/files/new'}>Upload file</Link>}</div>
    {!files.length && <p className="muted">No files added yet.</p>}
    {files.map(file => <article key={file.id} className="contact-entry"><h3>{file.filename}</h3><p className="muted">{(file.byte_size / 1048576).toFixed(1)} MB · {file.status === 'ready' ? 'Available' : 'Upload incomplete'}</p>
      {file.status === 'ready' && <a className="button" href={'/jobs/' + jobId + '/files/' + file.id + '/download'} target="_blank" rel="noreferrer">Download file<span className="sr-only"> {file.filename}</span></a>}
      {canWrite && (hasRole(session.actor, 'pm') || file.created_by === session.actor.id) && <RemoveFile jobId={jobId} fileId={file.id} />}
    </article>)}
  </section>;
}
