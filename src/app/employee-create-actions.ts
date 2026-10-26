'use server';
import {revalidatePath} from 'next/cache';
import {currentSession} from '../lib/session';
import {appConfig} from '../lib/config';
import {AppError} from '../domain/access.ts';
import {requireAdmin} from '../domain/employees.ts';
import {onboardingInput,onboardEmployee} from '../server/employee-onboarding.ts';
export type CreateEmployeeState={message:string;done?:boolean;uncertain?:boolean};
export async function createEmployeeAction(_previous:CreateEmployeeState,form:FormData):Promise<CreateEmployeeState>{
 try{
  const authorize=async()=>{const session=await currentSession();requireAdmin(session?.actor??null);if(!session)throw new AppError('sign_in_required',401,'Please sign in.');const actor=await session.gateway.getActor();requireAdmin(actor);return actor;};
  await authorize();const input=onboardingInput(form),config=appConfig();
  if(!config)throw new AppError('invalid_input',400,'Application configuration is missing.');
  await onboardEmployee(config,process.env.SUPABASE_ADMIN_KEY??'',input,authorize);
 }catch(error){return {message:error instanceof AppError?error.message:'Account setup was not confirmed. Retry the same form.',uncertain:!(error instanceof AppError)||error.code==='save_failed'};}
 revalidatePath('/','layout');return {message:'Employee added. Share the temporary password privately; they can change it in My account.',done:true};
}
