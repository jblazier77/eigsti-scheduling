import {pricingSession} from '../../../../lib/pricing-session';
import {pricingBody} from '../../../../server/pricing-http.ts';
import {contactUuid} from '../../../../domain/contacts.ts';
import {validatePriceRows} from '../../../../domain/pricing.ts';
import {AppError} from '../../../../domain/access.ts';
import {revalidatePath} from 'next/cache';
export const dynamic='force-dynamic';
export async function POST(request:Request,{params}:{params:Promise<{id:string}>}){const headers={'Cache-Control':'private, no-store'};try{const {gateway}=await pricingSession(true),{id}=await params,body=await pricingBody(request);if(!body||!['save','publish'].includes(body.action)||!Number.isInteger(body.version)||body.version<0)throw new AppError('invalid_input',400,'Invalid price-list operation.');const result=await gateway.save(contactUuid(id),contactUuid(body.requestId),body.version,validatePriceRows(body.rows,body.action==='publish'),body.action==='publish');revalidatePath('/pricing');return Response.json({ok:true,...result},{headers});}catch(e){return Response.json({ok:false,message:e instanceof AppError?e.message:'Save not confirmed. Retry the same request.'},{status:e instanceof AppError?e.status:503,headers});}}
