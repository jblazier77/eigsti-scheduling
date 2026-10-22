'use client';
import {useRef,useState} from 'react';
import type {JobEditValues} from '../../domain/job-edits.ts';
import {InlineJobDetails} from './edit-job-form';
import {DetailIcon} from './detail-icons';
export function JobScopeDetails({jobId,original,canEdit}:{jobId:string;original:JobEditValues;canEdit:boolean}) {
  const [editing,setEditing]=useState(false);
  const editButton=useRef<HTMLButtonElement>(null);
  return <section className="top-job-scope" aria-label="Job scope"><div className="scope-heading"><h2>Scope</h2>{canEdit&&<button ref={editButton} type="button" className="icon-action edit-details-icon" aria-label="Edit job details and scope" title="Edit job details and scope" aria-expanded={editing} aria-controls={'job-scope-editor-'+jobId} onClick={()=>setEditing(true)}><DetailIcon kind="edit"/></button>}</div>
    <p className="preserve-lines">{original.scope||'No scope added yet.'}</p>
    {canEdit&&<div id={'job-scope-editor-'+jobId} className="scope-edit-panel" hidden={!editing}>{editing&&<InlineJobDetails jobId={jobId} original={original} scopeFirst onDone={()=>{setEditing(false);editButton.current?.focus();}}/>}</div>}
  </section>;
}
