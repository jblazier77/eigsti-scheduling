import { AppError } from '../../domain/access.ts';
import type { SupabaseSession } from '../../server/supabase.ts';
import { ContactList } from './contact-list';

export async function JobContacts({jobId,isPm,canAdd,gateway,primary}: {jobId:string;isPm:boolean;canAdd:boolean;gateway:SupabaseSession;collapsible?:boolean;primary?:{name:string;phone:string;phoneAction:string}}){
 let contacts;
 try {contacts=await gateway.listContacts(jobId);}
 catch(error){if(!(error instanceof AppError)||error.code!=='schema_pending')throw error;return <section className="card"><h3>Contacts</h3><p className="muted">Contacts are temporarily unavailable. Please try again later.</p></section>;}
 let directory:Awaited<ReturnType<SupabaseSession['listSubcontractors']>>=[];
 let directoryUnavailable=false;
 if(canAdd){try{directory=await gateway.listSubcontractors();}catch(error){if(!(error instanceof AppError))throw error;directoryUnavailable=true;}}
 let commitments={can_manage:false,items:[]} as Awaited<ReturnType<SupabaseSession['jobCommitments']>>,commitmentsUnavailable=false;
 try{commitments=await gateway.jobCommitments(jobId);}catch(error){if(!(error instanceof AppError)||error.code!=='schema_pending')throw error;commitmentsUnavailable=true;}
 return <ContactList jobId={jobId} isPm={isPm} canAdd={canAdd} contacts={contacts} primary={primary} directory={directory.map(({id,name,phone,email})=>({id,name,phone,email}))} directoryUnavailable={directoryUnavailable} commitments={commitments.items} canManageCommitments={commitments.can_manage} commitmentsUnavailable={commitmentsUnavailable}/>;
}
