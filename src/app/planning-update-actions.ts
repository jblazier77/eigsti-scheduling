'use server';
import {revalidatePath} from 'next/cache';
import {workSession} from '../lib/work-session';
import {AppError,requirePm,requireActive} from '../domain/access.ts';
import {validateWork,workUuid,type WorkValues} from '../domain/work.ts';
import {validateOptionalPlan,validateMaterial,helperCount,type MaterialValues} from '../domain/planning-updates.ts';
import type {FormState} from './actions';
function read(form:FormData,name:string){const text=form.get(name);if(typeof text!=='string'||text.length>8000)throw new AppError('invalid_input',400,'Check the work details.');try{return JSON.parse(text);}catch{throw new AppError('invalid_input',400,'Check the work details.');}}
function failure(error:unknown){return {message:error instanceof AppError?error.message:'The save was not confirmed. Keep this draft and retry.',uncertain:!(error instanceof AppError)||['connection_failed','save_failed'].includes(error.code)};}
export async function createPlannedWorkAction(_previous:FormState,form:FormData):Promise<FormState>{
 let jobId:string;
 try{const {actor,gateway}=await workSession(true);requirePm(actor);jobId=workUuid(form.get('jobId'));const values=validateWork(read(form,'values')) as WorkValues;const plan=validateOptionalPlan(read(form,'schedule'),values);await gateway.createWorkWithPlan(jobId,workUuid(form.get('requestId')),values,plan);}catch(error){return failure(error);}
 revalidatePath('/jobs');revalidatePath('/jobs/'+jobId);revalidatePath('/schedule');revalidatePath('/queue');return {message:'Work saved.',jobId};
}
export type MaterialState=FormState&{values?:MaterialValues};
export async function createQuickWorkAction(_previous:FormState,form:FormData):Promise<FormState>{
 let jobId:string;
 try{
  const {actor,gateway}=await workSession(true);requirePm(actor);jobId=workUuid(form.get('jobId'));
  const values=validateWork(read(form,'values')) as WorkValues,plan=validateOptionalPlan(read(form,'schedule'),values),helpers=helperCount(form.get('helpersNeeded'));
  if(plan&&plan.required_helpers!==helpers)throw new AppError('invalid_input',400,'Check the helper count.');
  const rawMaterials=read(form,'materials'),materials=rawMaterials===null?null:validateMaterial(rawMaterials);
  await gateway.createQuickWork(jobId,workUuid(form.get('requestId')),values,plan,helpers,materials);
 }catch(error){return failure(error);}
 revalidatePath('/jobs');revalidatePath('/jobs/'+jobId);revalidatePath('/schedule');revalidatePath('/queue');return {message:'Work saved.',jobId};
}
export async function saveMaterialAction(_previous:MaterialState,form:FormData):Promise<MaterialState>{
 let jobId:string,values:MaterialValues;
 try{const {actor,gateway}=await workSession();requireActive(actor);if(!actor.roles.some(role=>role==='pm'||role==='lead'))throw new AppError('not_allowed',403,'A work planner is required.');values=validateMaterial(read(form,'values'));const result=await gateway.saveMaterials(workUuid(form.get('workId')),workUuid(form.get('requestId')),values);jobId=result.job_id;}catch(error){return failure(error);}
 revalidatePath('/jobs/'+jobId);revalidatePath('/queue');revalidatePath('/schedule');return {message:'Material status saved.',values};
}
