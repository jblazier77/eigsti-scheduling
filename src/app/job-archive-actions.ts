'use server';
import {revalidatePath} from 'next/cache';
import {requireSession} from '../lib/session';
import {AppError,requirePm} from '../domain/access.ts';
import {contactUuid} from '../domain/contacts.ts';
import type {FormState} from './actions';
export async function setJobArchiveAction(_previous:FormState,form:FormData):Promise<FormState>{
 let jobId:string,message:string;
 try{
  const {actor,gateway}=await requireSession();requirePm(actor);
  const action=form.get('operation'),expected=form.get('expected');
  if((action!=='archive'&&action!=='restore')||typeof expected!=='string'||!['open','closed','archived'].includes(expected))throw new AppError('invalid_input',400,'Check the job status.');
  const result=await gateway.setJobArchive(contactUuid(form.get('jobId')),contactUuid(form.get('requestId')),action,expected);
  jobId=result.id;message=(result.replayed?'This request was already saved. ':'')+(result.lifecycle==='open'?'Job restored. Add any additional work on this job.':'Job archived. You can restore it later for more work.');
 }catch(error){return {message:error instanceof AppError?error.message:'The job status change was not confirmed. Retry the same request.',uncertain:!(error instanceof AppError)||['connection_failed','save_failed'].includes(error.code)};}
 for(const path of ['/jobs','/jobs/'+jobId,'/schedule','/queue'])revalidatePath(path);
 return {message,jobId};
}
