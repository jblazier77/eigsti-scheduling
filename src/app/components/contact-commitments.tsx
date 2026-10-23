'use client';
import {useActionState,useEffect,useId,useState} from 'react';
import {useRouter} from 'next/navigation';
import {dateLabel} from '../../domain/visits.ts';
import type {Commitment} from '../../domain/commitments.ts';
import type {FormState} from '../actions';
import {saveCommitmentAction} from '../commitment-actions';

export function ContactCommitments({jobId,contactId,items,canManage}:{jobId:string;contactId:string;items:Commitment[];canManage:boolean}){
 const [draft,setDraft]=useState<{item?:Commitment;requestId:string}|null>(null);
 return <div className="contact-commitments">{items.map(item=><div className="commitment-line" key={item.id}><span aria-hidden="true">⚑</span><span>{item.commitment_date&&<strong>{dateLabel(item.commitment_date)} </strong>}<span className="preserve-lines">{item.note}</span>{!item.commitment_date&&<small className="muted"> · No date yet</small>}</span>{canManage&&!draft&&<button type="button" className="text-button" aria-label="Edit subcontractor commitment" onClick={()=>setDraft({item,requestId:crypto.randomUUID()})}>Edit</button>}</div>)}{canManage&&!draft&&<button type="button" className="text-button" onClick={()=>setDraft({requestId:crypto.randomUUID()})}>+ Commitment</button>}{draft&&<CommitmentForm key={draft.requestId} jobId={jobId} contactId={contactId} requestId={draft.requestId} item={draft.item} onDone={()=>setDraft(null)}/>}</div>;
}
function CommitmentForm({jobId,contactId,requestId,item,onDone}:{jobId:string;contactId:string;requestId:string;item?:Commitment;onDone:()=>void}){
 const router=useRouter(),formId=useId();
 const [date,setDate]=useState(item?.commitment_date??''),[note,setNote]=useState(item?.note??''),[remove,setRemove]=useState(false);
 const [state,action,pending]=useActionState(async(previous:FormState,form:FormData)=>{try{return await saveCommitmentAction(previous,form);}catch{return {message:'The save was not confirmed. Your draft is retained; retry the same save.',uncertain:true};}}, {message:''} as FormState);
 const dirty=date!==(item?.commitment_date??'')||note!==(item?.note??'');
 useEffect(()=>{if(state.jobId){onDone();router.refresh();}},[state.jobId,onDone,router]);
 useEffect(()=>{if(!dirty||state.jobId)return;const warn=(e:BeforeUnloadEvent)=>{e.preventDefault();e.returnValue='';};window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn);},[dirty,state.jobId]);
 const locked=pending||!!state.jobId||!!state.uncertain;
 return <form action={action} className="stack commitment-editor"><input type="hidden" name="jobId" value={jobId}/><input type="hidden" name="contactId" value={contactId}/><input type="hidden" name="id" value={item?.id??''}/><input type="hidden" name="requestId" value={requestId}/><input type="hidden" name="remove" value={remove?'yes':'no'}/><input type="hidden" name="values" value={JSON.stringify({commitment_date:date||null,note})}/><fieldset disabled={locked} className="commitment-fields"><legend>{item?'Edit commitment':'Add commitment'}</legend><label htmlFor={formId+'date'}>Date (optional)</label><input id={formId+'date'} type="date" min="2000-01-01" max="2099-12-31" value={date} onChange={e=>setDate(e.target.value)}/><label htmlFor={formId+'note'}>What was promised or is needed</label><textarea id={formId+'note'} rows={2} maxLength={2000} value={note} onChange={e=>setNote(e.target.value)}/></fieldset>{state.message&&<p role="alert">{state.message}</p>}{state.uncertain&&<p className="muted">Keep this draft unchanged and retry, or check the job in another tab before closing.</p>}{remove&&<p>Remove this commitment? Its history will be retained.</p>}<div className="two-actions"><button className="button primary" disabled={pending||!!state.jobId||(!remove&&!date&&!note.trim())}>{pending?'Saving…':state.uncertain?'Retry this save':remove?'Remove commitment':'Save'}</button><button type="button" className="button" disabled={pending} onClick={()=>{if(!dirty||window.confirm('Discard this commitment draft?'))onDone();}}>Cancel</button>{item&&!locked&&<button className="text-button" type="button" onClick={()=>setRemove(!remove)}>{remove?'Keep commitment':'Remove'}</button>}</div></form>;
}
