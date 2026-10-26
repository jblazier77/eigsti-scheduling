'use client';
import {useActionState,useState} from 'react';
import {useRouter} from 'next/navigation';
import {createEmployeeAction,type CreateEmployeeState} from '../employee-create-actions';
export function EmployeeCreate(){
 const [open,setOpen]=useState(false),[key,setKey]=useState('');
 if(!open)return <button className="button primary" onClick={()=>{setKey(crypto.randomUUID());setOpen(true);}}>Add employee</button>;
 return <CreateForm key={key} requestId={key} close={()=>setOpen(false)}/>;
}
function CreateForm({requestId,close}:{requestId:string;close:()=>void}){
 const router=useRouter();
 const [name,setName]=useState(''),[email,setEmail]=useState(''),[password,setPassword]=useState(''),[roles,setRoles]=useState(['helper']);
 const [state,action,pending]=useActionState(async(s:CreateEmployeeState,f:FormData)=>{try{return await createEmployeeAction(s,f);}catch{return {message:'Account setup was not confirmed. Retry this unchanged form.',uncertain:true};}},{message:''} as CreateEmployeeState);
 if(state.done)return <div role="status"><p>{state.message}</p><button className="button" onClick={()=>{router.refresh();close();}}>Done</button></div>;
 return <form action={action} className="stack employee-form"><h2>Add employee</h2><input type="hidden" name="requestId" value={requestId}/><fieldset disabled={pending} aria-readonly={state.uncertain}><label>Name<input name="name" value={name} onChange={e=>setName(e.target.value)} required maxLength={100} readOnly={state.uncertain}/></label><label>Email<input name="email" value={email} onChange={e=>setEmail(e.target.value)} type="email" required maxLength={254} autoComplete="off" readOnly={state.uncertain}/></label><label>Temporary password<input name="password" value={password} onChange={e=>setPassword(e.target.value)} type="password" required minLength={12} autoComplete="new-password" readOnly={state.uncertain}/></label><fieldset><legend>Roles</legend>{[['helper','Helper'],['lead','Lead'],['pm','PM'],['admin','Administrator']].map(([v,label])=><label className="staff-choice" key={v}><input name="roles" type="checkbox" value={v} checked={roles.includes(v)} onChange={e=>{if(!state.uncertain)setRoles(e.target.checked?[...roles,v]:roles.filter(r=>r!==v));}}/>{label}</label>)}</fieldset></fieldset><p className="muted">Share the temporary password privately. No email is sent. They can change it in My account.</p>{state.message&&<p role="alert">{state.message}</p>}<div className="two-actions"><button className="button primary" disabled={pending}>{pending?'Adding…':state.uncertain?'Retry same setup':'Add employee'}</button><button type="button" className="button" disabled={pending} onClick={()=>{if(!state.uncertain||confirm('Setup was not confirmed. Check Employees before starting another account. Close this form?')){router.refresh();close();}}}>Cancel</button></div></form>;
}
