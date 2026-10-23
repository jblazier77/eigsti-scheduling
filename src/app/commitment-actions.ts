'use server';
import {revalidatePath} from 'next/cache';
import {workSession} from '../lib/work-session';
import {requireActive,AppError} from '../domain/access.ts';
import {contactUuid,validateContact,type ContactValues} from '../domain/contacts.ts';
import {validateCommitment} from '../domain/commitments.ts';
import type {FormState} from './actions';
function value(form:FormData,name:string){const raw=form.get(name);if(typeof raw!=='string'||raw.length>12000)throw new AppError('invalid_input',400,'Check the contact commitment.');try{return JSON.parse(raw);}catch{throw new AppError('invalid_input',400,'Check the contact commitment.');}}
function failure(error:unknown){return {message:error instanceof AppError?error.message:'The save was not confirmed. Keep this draft and retry.',uncertain:!(error instanceof AppError)||['connection_failed','save_failed'].includes(error.code)};}
function refresh(jobId:string){revalidatePath('/jobs/'+jobId);revalidatePath('/schedule');}
export async function saveCommitmentAction(_previous:FormState,form:FormData):Promise<FormState>{
 let jobId:string;
 try{const {actor,gateway}=await workSession();requireActive(actor);if(!actor.roles.some(r=>r==='pm'||r==='lead'))throw new AppError('not_allowed',403,'A job planner is required.');const remove=form.get('remove')==='yes';const result=await gateway.saveCommitment(contactUuid(form.get('jobId')),contactUuid(form.get('contactId')),form.get('id')?contactUuid(form.get('id')):null,contactUuid(form.get('requestId')),remove?{}:validateCommitment(value(form,'values')),remove);jobId=result.job_id;}catch(error){return failure(error);}
 refresh(jobId);return {message:'Commitment saved.',jobId};
}
export async function createCommittedContactAction(_previous:FormState,form:FormData):Promise<FormState>{
 let jobId:string;
 try{const {actor,gateway}=await workSession();requireActive(actor);if(!actor.roles.some(r=>r==='pm'||r==='lead'))throw new AppError('not_allowed',403,'A job planner is required.');jobId=contactUuid(form.get('jobId'));await gateway.createContactWithCommitment(jobId,contactUuid(form.get('requestId')),validateContact(value(form,'values')) as ContactValues,validateCommitment(value(form,'commitment')));}catch(error){return failure(error);}
 refresh(jobId);return {message:'Contact and commitment saved.',jobId};
}
