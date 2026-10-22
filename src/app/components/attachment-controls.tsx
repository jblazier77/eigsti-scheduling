'use client';
import {useId,useRef,useState} from 'react';
import {FILE_ACCEPT} from '../../domain/files.ts';
import {FileUpload} from './file-upload';
import {DetailIcon} from './detail-icons';
export function AttachmentControls({jobId}:{jobId:string}) {
  const files=useRef<HTMLInputElement>(null),photos=useRef<HTMLInputElement>(null),panel=useId();
  const [selection,setSelection]=useState<{file:File;requestId:string}|null>(null);
  function choose(event:React.ChangeEvent<HTMLInputElement>){const file=event.target.files?.[0];if(file)setSelection({file,requestId:crypto.randomUUID()});event.target.value='';}
  return <div className="top-attachments"><div className="attachment-toolbar"><span className="muted">Add</span><button type="button" className="icon-action" title="Attach a file" aria-label="Attach a file" aria-controls={panel} disabled={!!selection} onClick={()=>files.current?.click()}><DetailIcon kind="attachment"/></button><button type="button" className="icon-action" title="Add a photo" aria-label="Add a photo" aria-controls={panel} disabled={!!selection} onClick={()=>photos.current?.click()}><DetailIcon kind="photo"/></button></div>
    <input hidden ref={files} type="file" accept={FILE_ACCEPT} onChange={choose} aria-label="Choose job attachment"/>
    <input hidden ref={photos} type="file" accept="image/jpeg,image/png,image/webp,image/heic,image/heif,.heic,.heif" onChange={choose} aria-label="Choose job photo"/>
    <div id={panel} className="inline-upload" hidden={!selection}>{selection&&<FileUpload key={selection.requestId} jobId={jobId} requestId={selection.requestId} initialFile={selection.file} onComplete={()=>setSelection(null)} onCancel={()=>setSelection(null)}/>}</div>
  </div>;
}
