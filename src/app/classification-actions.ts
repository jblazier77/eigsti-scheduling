'use server';
import { revalidatePath } from 'next/cache';
import { requireSession } from '../lib/session';
import { AppError, requirePm } from '../domain/access.ts';
import { classificationPatch, subcontractorValues } from '../domain/job-classification.ts';
import { normalizePhone, uuidPattern } from '../domain/jobs.ts';

export type ClassificationState={message:string;saved?:boolean;uncertain?:boolean};
function id(value:FormDataEntryValue|null):string {
  if(typeof value!=='string'||!uuidPattern.test(value))throw new AppError('invalid_input',400,'Invalid identifier.');
  return value;
}
function readPatch(form:FormData):unknown {
  const text=form.get('patch');
  if(typeof text!=='string'||text.length>6000)throw new AppError('invalid_input',400,'Check the details.');
  try{return JSON.parse(text);}catch{throw new AppError('invalid_input',400,'Check the details.');}
}
export async function saveClassificationAction(_previous:ClassificationState,form:FormData):Promise<ClassificationState> {
  try {
    const {actor,gateway}=await requireSession();requirePm(actor);
    const jobId=id(form.get('jobId')),requestId=id(form.get('requestId')),patch=classificationPatch(readPatch(form));
    if(!Object.keys(patch).length)throw new AppError('invalid_input',400,'No changes to save.');
    await gateway.saveClassification(jobId,requestId,patch);
    for(const path of ['/jobs','/jobs/'+jobId,'/queue','/schedule'])revalidatePath(path);
    return{message:'Saved.',saved:true};
  }catch(error){return{message:error instanceof AppError?error.message:'The save was not confirmed. Your draft is retained.',uncertain:!(error instanceof AppError)||['connection_failed','save_failed'].includes(error.code)};}
}
export async function saveSubcontractorAction(_previous:ClassificationState,form:FormData):Promise<ClassificationState> {
  try {
    const {actor,gateway}=await requireSession();
    if(!actor.active||!actor.roles.some(r=>r==='admin'||r==='pm'))throw new AppError('not_allowed',403,'Only administrators and project managers can edit the directory.');
    const contractorId=form.get('id')?id(form.get('id')):null,requestId=id(form.get('requestId'));
    const raw=readPatch(form);
    const archive=raw&&typeof raw==='object'&&!Array.isArray(raw)&&JSON.stringify(raw)==='{"archive":true}';
    let patch;
    if(archive){if(!contractorId)throw new AppError('invalid_input',400,'Choose a subcontractor.');patch={archive:true as const};}
    else{
      const values=subcontractorValues(raw);
      if(values.phone)normalizePhone(values.phone);
      // Editors submit a full validated draft, then send only changed fields.
      const changed=form.getAll('changed');
      if(contractorId&&(!changed.length||changed.some(k=>typeof k!=='string'||!['name','phone','email','trades'].includes(k))))throw new AppError('invalid_input',400,'No valid changes to save.');
      patch=contractorId?Object.fromEntries(changed.map(k=>[String(k),values[k as keyof typeof values]])):values;
    }
    await gateway.saveSubcontractor(contractorId,requestId,patch);
    revalidatePath('/subcontractors');return{message:archive?'Subcontractor archived.':'Saved.',saved:true};
  }catch(error){return{message:error instanceof AppError?error.message:'The save was not confirmed. Your draft is retained.',uncertain:!(error instanceof AppError)||['connection_failed','save_failed'].includes(error.code)};}
}
