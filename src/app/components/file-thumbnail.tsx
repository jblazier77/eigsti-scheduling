'use client';
import {useState} from 'react';
import {canPreviewPhoto,type JobFile} from '../../domain/files.ts';
import {DetailIcon} from './detail-icons';
export function FileThumbnail({file}:{file:JobFile}) {
  const [failed,setFailed]=useState(false),[retry,setRetry]=useState(0);
  const photo=canPreviewPhoto(file),base='/jobs/'+file.job_id+'/files/'+file.id;
  const label=file.status!=='ready'?'Upload incomplete':file.mime_type==='application/pdf'?'PDF':file.mime_type==='image/heic'||file.mime_type==='image/heif'?'Original photo':'File';
  return <div className="thumbnail-frame">
    <a className="thumbnail-link" href={photo?base+'/preview':base+'/download'} target="_blank" rel="noreferrer" aria-label={'Open '+file.filename} aria-disabled={file.status!=='ready'} onClick={e=>{if(file.status!=='ready')e.preventDefault();}}>
      {photo&&!failed?<img key={retry} src={base+'/preview'+(retry?'?retry='+retry:'')} alt={file.filename} width={320} height={220} loading="lazy" decoding="async" referrerPolicy="no-referrer" onError={()=>setFailed(true)}/>:<div className="file-tile-placeholder"><DetailIcon kind={file.mime_type.startsWith('image/')?'photo':'document'}/><span>{failed?'Preview unavailable':label}</span></div>}
    </a>
    {photo&&failed&&<button type="button" className="thumbnail-retry" onClick={()=>{setRetry(n=>n+1);setFailed(false);}}>Retry preview</button>}
  </div>;
}
