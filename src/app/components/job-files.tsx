import {currentSession} from '../../lib/session';
import {appConfig} from '../../lib/config';
import {authClient} from '../../lib/supabase-server';
import {AppError,hasRole} from '../../domain/access.ts';
import {FileSession} from '../../server/files.ts';
import {RemoveFile} from './remove-file';
import {FileThumbnail} from './file-thumbnail';
export async function JobFiles({jobId}:{jobId:string}) {
  const session=await currentSession(),config=appConfig();if(!session||!config)return null;
  const client=await authClient(),{data}=await client.auth.getSession();if(!data.session)return null;
  const gateway=new FileSession(config,data.session.access_token);
  let files;
  try{files=await gateway.listFiles(jobId);}catch(error){if(!(error instanceof AppError)||error.code!=='schema_pending')throw error;return <section className="attachment-gallery"><h2>Photos &amp; files</h2><p className="muted">Files are temporarily unavailable.</p></section>;}
  const writer=hasRole(session.actor,'pm')||hasRole(session.actor,'lead');
  return <section className="attachment-gallery" id="job-attachments"><div className="section-heading"><h2>Photos &amp; files</h2><span className="muted">{files.length}</span></div>
    {!files.length&&<p className="muted">No attachments yet.</p>}
    <div className="attachment-grid">{files.map(file=><article className="attachment-tile" key={file.id}><FileThumbnail file={file}/><p className="attachment-name" title={file.filename}>{file.filename}</p><p className="muted attachment-size">{(file.byte_size/1048576).toFixed(1)} MB{file.status!=='ready'?' / Upload incomplete':''}</p>{file.status==='ready'&&<a className="attachment-original" href={'/jobs/'+jobId+'/files/'+file.id+'/download'} target="_blank" rel="noreferrer">Open original</a>}
      {writer&&(hasRole(session.actor,'pm')||file.created_by===session.actor.id)&&<details className="attachment-options"><summary>File options</summary><RemoveFile jobId={jobId} fileId={file.id}/></details>}
    </article>)}</div>
  </section>;
}
