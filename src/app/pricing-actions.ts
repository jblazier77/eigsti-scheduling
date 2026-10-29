'use server';
import {pricingSession} from '../lib/pricing-session';
import {contactUuid} from '../domain/contacts.ts';
import {priceFile,pricingMetadata} from '../domain/pricing.ts';
import {AppError} from '../domain/access.ts';
import {revalidatePath} from 'next/cache';
const message=(e:unknown)=>e instanceof AppError?e.message:'The action was not confirmed. Retry the same request.';
export async function preparePricingUpload(input:{requestId:string;vendor:string;catalog:string;effective:string;expires:string;notes:string;file:{name:string;size:number;type:string}}){try{const {gateway}=await pricingSession(true),file=priceFile(input.file),meta=pricingMetadata(input),reserved=await gateway.begin(contactUuid(input.requestId),contactUuid(input.vendor),meta,file);let list=await gateway.list(reserved.id);if(!list)throw new AppError('invalid_input',400,'Price list unavailable.');if(list.status==='uploading'){try{list=await gateway.finish(list.id);}catch(e){if(!(e instanceof AppError)||e.code!=='upload_pending')throw e;}}return {ok:true as const,list,url:list.status==='uploading'?await gateway.signUpload(list):null};}catch(e){return {ok:false as const,message:message(e)};}}
export async function finishPricingUpload(id:string){try{const {gateway}=await pricingSession(true),list=await gateway.finish(contactUuid(id));revalidatePath('/pricing');return {ok:true as const,list};}catch(e){return {ok:false as const,message:message(e)};}}
export async function withdrawPricing(id:string,request:string){try{const {gateway}=await pricingSession(true);await gateway.withdraw(contactUuid(id),contactUuid(request));revalidatePath('/pricing');return {ok:true as const};}catch(e){return {ok:false as const,message:message(e)};}}
