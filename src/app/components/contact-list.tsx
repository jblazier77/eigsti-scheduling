'use client';
import { useState } from 'react';
import { alphabeticalContacts, type JobContact } from '../../domain/contacts.ts';
import type { Subcontractor } from '../../domain/job-classification.ts';
import { ContactForm } from './contact-form';
import { DetailIcon } from './detail-icons';
import { ContactCommitments } from './contact-commitments';
import { isSubcontractor, type Commitment } from '../../domain/commitments.ts';

type Props={jobId:string;isPm:boolean;canAdd:boolean;contacts:JobContact[];primary?:{name:string;phone:string;phoneAction:string};directory:Pick<Subcontractor,'id'|'name'|'phone'|'email'>[];directoryUnavailable:boolean;commitments?:Commitment[];canManageCommitments?:boolean;commitmentsUnavailable?:boolean};
export function ContactList({jobId,isPm,canAdd,contacts,primary,directory,directoryUnavailable,commitments=[],canManageCommitments=false,commitmentsUnavailable=false}:Props){
 const [editor,setEditor]=useState<{id:string;requestId?:string}|null>(null);
 const rows=alphabeticalContacts([...contacts,...(primary?[{...primary,id:'primary',job_id:jobId,relationship:'Customer',phone_action:primary.phoneAction,email:'',notes:''}]:[])]);
 const close=()=>setEditor(null);
 return <section className="compact-contacts" aria-label="Job contacts">
  <div className="section-heading"><h3>Contacts <span className="muted">{rows.length}</span></h3>{canAdd && contacts.length<100 && !editor && <button type="button" className="button" onClick={()=>setEditor({id:'new',requestId:crypto.randomUUID()})}><DetailIcon kind="plus"/> Add contact</button>}</div>
  {editor?.id==='new' && <div className="contact-editor"><h4>Add contact</h4>{directoryUnavailable&&<p className="muted">The subcontractor directory is unavailable. You can still enter contact details manually.</p>}<ContactForm key={editor.requestId} jobId={jobId} requestId={editor.requestId} directory={directory} allowCommitment={canManageCommitments} onDone={close}/></div>}
  {commitmentsUnavailable&&<p className="muted">Subcontractor commitments are temporarily unavailable.</p>}
  {!rows.length&&<p className="muted">No contacts added yet.</p>}
  <ul className="compact-contact-list">{rows.map(contact=><li key={contact.id} id={'contact-'+contact.id}>
   <div className="compact-contact-row"><div className="contact-identity"><strong>{contact.name}</strong><span className="contact-type">{contact.relationship||'Other'}</span>{contact.phone&&<span className="contact-phone">{contact.phone}</span>}</div>
    <div className="contact-row-actions">
     {contact.phone_action&&<><a className="icon-action edit-details-icon" href={'tel:'+contact.phone_action} title={'Call '+contact.name} aria-label={'Call '+contact.name}><DetailIcon kind="phone"/></a><a className="icon-action edit-details-icon" href={'sms:'+contact.phone_action} title={'Text '+contact.name} aria-label={'Text '+contact.name}><DetailIcon kind="message"/></a></>}
     {contact.email&&<a className="icon-action edit-details-icon" href={'mailto:'+encodeURIComponent(contact.email)} title={'Email '+contact.name} aria-label={'Email '+contact.name}><DetailIcon kind="mail"/></a>}
     {isPm&&contact.id!=='primary'&&!editor&&<button type="button" className="icon-action edit-details-icon" title={'Edit '+contact.name} aria-label={'Edit '+contact.name} onClick={()=>setEditor({id:contact.id})}><DetailIcon kind="edit"/></button>}
    </div>
   </div>
   {contact.notes&&<p className="contact-note preserve-lines">{contact.notes}</p>}
   {isSubcontractor(contact.relationship)&&<ContactCommitments jobId={jobId} contactId={contact.id} items={commitments.filter(c=>c.contact_id===contact.id)} canManage={canManageCommitments}/>}
   {editor?.id===contact.id&&<div className="contact-editor"><ContactForm key={contact.id} jobId={jobId} contactId={contact.id} original={contact} onDone={close}/></div>}
  </li>)}</ul>
  {canAdd&&contacts.length>=100&&<p className="muted">Contact limit reached. Ask a project manager to remove an outdated contact.</p>}
 </section>;
}
