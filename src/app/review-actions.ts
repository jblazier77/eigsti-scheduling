'use server';
import {revalidatePath} from 'next/cache';
import {workSession} from '../lib/work-session';
import {validateVisit,visitId} from '../domain/visits.ts';
import {AppError,requirePm,requireActive} from '../domain/access.ts';
import {optionalNumber} from '../domain/planning-review.ts';
import {validateCreateJob} from '../domain/jobs.ts';
import {validateJobPatch} from '../domain/job-edits.ts';
import {classificationPatch} from '../domain/job-classification.ts';
import {validateContact} from '../domain/contacts.ts';
import {validateWork,workUuid} from '../domain/work.ts';
import {validateOptionalPlan,validateMaterial,helperCount} from '../domain/planning-updates.ts';
import type {WorkValues} from '../domain/work.ts';
import type {FormState} from './actions';
function read(form:FormData,name:string){const text=form.get(name);if(typeof text!=='string'||text.length>24000)throw new AppError('invalid_input',400,'Check the details.');try{return JSON.parse(text);}catch{throw new AppError('invalid_input',400,'Check the details.');}}
function failed(e:unknown):FormState{return {message:e instanceof AppError?e.message:'Save not confirmed. Keep this draft and retry.',uncertain:!(e instanceof AppError)||['connection_failed','save_failed'].includes(e.code)};}
function refresh(id:string){revalidatePath('/jobs');revalidatePath('/jobs/'+id);revalidatePath('/queue');revalidatePath('/schedule');}
export async function savePriorityAction(_prev:FormState,form:FormData):Promise<FormState>{try{const {actor,gateway}=await workSession(true);requirePm(actor);const id=workUuid(form.get('jobId'));await gateway.savePriority(id,workUuid(form.get('requestId')),optionalNumber(form.get('priority'),'priority'));refresh(id);return {message:'Priority saved.',jobId:id};}catch(e){return failed(e);}}
export async function saveWorkDetailsAction(_prev:FormState,form:FormData):Promise<FormState>{try{
 const {actor,gateway}=await workSession(true);requireActive(actor);const raw=read(form,'values');
 if(!raw||typeof raw!=='object'||Array.isArray(raw)||!Object.keys(raw).length||Object.keys(raw).some(k=>!['description','estimated_days','responsible_lead','default_helpers'].includes(k)))throw new AppError('invalid_input',400,'Check the work details.');
 const patch:Record<string,unknown>={};
 if(Object.hasOwn(raw,'description'))patch.description=validateWork({description:raw.description},true).description;
 if(Object.hasOwn(raw,'responsible_lead')){requirePm(actor);patch.responsible_lead=validateWork({responsible_lead:raw.responsible_lead},true).responsible_lead;}
 if(Object.hasOwn(raw,'estimated_days'))patch.estimated_days=optionalNumber(raw.estimated_days,'days');
 if(Object.hasOwn(raw,'default_helpers'))patch.default_helpers=helperCount(String(raw.default_helpers));
 const result=await gateway.saveWorkDetails(workUuid(form.get('workId')),workUuid(form.get('requestId')),patch);refresh(result.job_id);return {message:'Work saved.',jobId:result.job_id};
 }catch(e){return failed(e);}}
export async function createWorkspaceAction(_prev:FormState,form:FormData):Promise<FormState>{try{
 const {actor,gateway}=await workSession(true);requirePm(actor);
 const basic=validateCreateJob({requestId:form.get('requestId'),customer:form.get('customer'),phone:form.get('phone'),address:form.get('address')});
 const details=read(form,'details');if(!details||typeof details!=='object'||Array.isArray(details)||Object.keys(details).some(k=>!['title','scope','access_notes'].includes(k)))throw new AppError('invalid_input',400,'Check the job details.');
 const patch=Object.keys(details).length?validateJobPatch(details):{};
 const work=read(form,'work'),contacts=read(form,'contacts');
 if(!Array.isArray(work)||work.length>20||!Array.isArray(contacts)||contacts.length>20)throw new AppError('invalid_input',400,'Use up to 20 tasks and contacts during setup.');
 const tasks=work.map(row=>{const values=validateWork(row.values) as WorkValues,plan=validateOptionalPlan(row.plan,values),helpers=helperCount(String(row.helpers));if(plan&&plan.required_helpers!==helpers)throw new AppError('invalid_input',400,'Check the helper count.');const rawNamed=row.named_helpers??[];if(!Array.isArray(rawNamed)||rawNamed.length>20)throw new AppError('invalid_input',400,'Check the helpers.');const named_helpers=rawNamed.map(workUuid);if(new Set(named_helpers).size!==named_helpers.length||named_helpers.length>helpers||named_helpers.includes(values.responsible_lead??'')||named_helpers.length>0&&!plan)throw new AppError('invalid_input',400,'Choose a date, a separate lead and enough helper spaces.');return {values,plan,helpers,named_helpers,materials:row.materials===null?null:validateMaterial(row.materials),days:optionalNumber(row.days,'days')};});
 const result=await gateway.createWorkspace(basic,classificationPatch(read(form,'classification')),patch,optionalNumber(form.get('priority'),'priority'),tasks,contacts.map(c=>validateContact(c)));refresh(result.id);return {message:'Job saved.',jobId:result.id};
 }catch(e){return failed(e);}}

export async function saveWorkSetupAction(_prev:FormState,form:FormData):Promise<FormState>{try{
 const {actor,gateway}=await workSession(true);requireActive(actor);if(!actor.roles.some(r=>r==='pm'||r==='lead'))throw new AppError('not_allowed',403,'Work planner required.');
 const raw=read(form,'values');if(!raw||typeof raw!=='object'||Array.isArray(raw)||Object.keys(raw).some(k=>!['description','estimated_days','responsible_lead','default_helpers'].includes(k)))throw new AppError('invalid_input',400,'Check the work details.');
 const patch:Record<string,unknown>={};if(Object.hasOwn(raw,'description'))patch.description=validateWork({description:raw.description},true).description;
 if(Object.hasOwn(raw,'responsible_lead')){requirePm(actor);patch.responsible_lead=validateWork({responsible_lead:raw.responsible_lead},true).responsible_lead;}
 if(Object.hasOwn(raw,'estimated_days'))patch.estimated_days=optionalNumber(raw.estimated_days,'days');
 if(Object.hasOwn(raw,'default_helpers'))patch.default_helpers=helperCount(String(raw.default_helpers));
 const materialsRaw=read(form,'materials'),materials=materialsRaw===null?null:validateMaterial(materialsRaw),planRaw=read(form,'schedule');
 const planningWork=validateWork(read(form,'planningWork')) as WorkValues;
 const plan=validateOptionalPlan(planRaw,planningWork);
 const rawVisits=read(form,'visits');if(!Array.isArray(rawVisits)||rawVisits.length>100)throw new AppError('invalid_input',400,'Check the work dates.');
 const seen=new Set<string>();
 const visits=rawVisits.map(v=>{if(!v||typeof v!=='object'||Array.isArray(v))throw new AppError('invalid_input',400,'Check the work dates.');const id=visitId(v.id);if(seen.has(id)||typeof v.cancel!=='boolean')throw new AppError('invalid_input',400,'Check the work dates.');seen.add(id);
 if(v.cancel)return {id,patch:{},helpers:null,cancel:true};
 const values=validateVisit({...v.values,required_helpers:String(v.values?.required_helpers)});
 if(!Array.isArray(v.fields)||v.fields.some((k:unknown)=>typeof k!=='string'||!Object.hasOwn(values,k)))throw new AppError('invalid_input',400,'Check the work dates.');
 const visitPatch=Object.fromEntries(v.fields.map((key:keyof typeof values)=>[key,values[key]]));
 const helpers=v.helpers===null?null:Array.isArray(v.helpers)?v.helpers.map(visitId):undefined;
 if(helpers===undefined||helpers!==null&&(helpers.length>20||new Set(helpers).size!==helpers.length))throw new AppError('invalid_input',400,'Check the helpers.');
 return {id,patch:visitPatch,helpers,cancel:false};});
 const rawNamed=form.has('newHelpers')?read(form,'newHelpers'):null;
 if(rawNamed!==null&&(!Array.isArray(rawNamed)||rawNamed.length>20))throw new AppError('invalid_input',400,'Check the helpers.');
 const named=rawNamed===null?null:rawNamed.map(workUuid);
 if(named&&(new Set(named).size!==named.length||named.length>0&&!plan||plan&&named.length>plan.required_helpers))throw new AppError('invalid_input',400,'Choose a date and enough helper spaces.');
 const result=await gateway.saveWorkSetup(workUuid(form.get('workId')),workUuid(form.get('requestId')),patch,materials,plan,visits,named);refresh(result.job_id);return {message:'Work saved.',jobId:result.job_id};
 }catch(e){return failed(e);}}
