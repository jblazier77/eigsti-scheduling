import {createClient} from '@supabase/supabase-js';
import {createHmac} from 'node:crypto';
import {AppError} from '../domain/access.ts';
import {requireAdmin,validateEmployee,type Employee} from '../domain/employees.ts';
import {contactUuid} from '../domain/contacts.ts';
import {validateConfig,type SupabaseConfig} from './supabase.ts';
export function onboardingInput(form:FormData){
 const values=validateEmployee({display_name:form.get('name'),roles:form.getAll('roles'),active:true});
 const email=String(form.get('email')??'').trim().toLowerCase(),password=form.get('password');
 if(email.length>254||! /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))throw new AppError('invalid_input',400,'Enter a valid email address.');
 if(typeof password!=='string'||password.length<12||Buffer.byteLength(password,'utf8')>72)throw new AppError('invalid_input',400,'Use a temporary password of at least 12 characters and at most 72 bytes.');
 return {values,email,password,requestId:contactUuid(form.get('requestId'))};
}
// Only the authenticated Server Action supplies this isolated privileged client.
// No cookies, persisted sessions, user listing, deletion or password-reset retry.
export async function onboardEmployee(config:SupabaseConfig,key:string,input:ReturnType<typeof onboardingInput>,authorize:()=>Promise<import('../domain/access.ts').Actor>,transport:typeof fetch=fetch):Promise<Employee>{
 const actor=await authorize();requireAdmin(actor);validateConfig(config);
 if(!key||(!key.startsWith('sb_secret_')&&!isServiceKey(key)))throw new AppError('invalid_input',400,'Employee creation needs the private server key configured.');
 const fingerprint=createHmac('sha256',key).update(JSON.stringify([actor.id,input.requestId,input.email,input.values])).digest('hex');
 const raw=createHmac('sha256',key).update(actor.id+':'+input.requestId).digest('hex');
 const id=raw.slice(0,8)+'-'+raw.slice(8,12)+'-4'+raw.slice(13,16)+'-a'+raw.slice(17,20)+'-'+raw.slice(20,32);
 const client=createClient(config.url,key,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},global:{fetch:transport}});
 // Missing migration must fail before creating any sign-in account.
 const probe=await client.rpc('employee_onboarding_ready',{p_actor:actor.id});
 if(probe.error)throw new AppError('invalid_input',400,'Employee creation is not ready. Apply the employee account database update and check server configuration.');
 let {data,error}=await client.auth.admin.getUserById(id);
 if(error&&error.status!==404)throw new AppError('save_failed',503,'Account setup was not confirmed. Retry the same form.');
 if(!data.user){
  requireAdmin(await authorize());
  const created=await client.auth.admin.createUser({id,email:input.email,password:input.password,email_confirm:true,app_metadata:{eigsti_onboarding:fingerprint,eigsti_actor:actor.id,eigsti_request:input.requestId}});
  data=created.data;error=created.error;
  if(error){
   // A lost response or concurrent identical submit may have created our ID.
   const recovered=await client.auth.admin.getUserById(id);
   if(!recovered.data.user){
    if(['weak_password','validation_failed'].includes(error.code??''))throw new AppError('invalid_input',400,'Choose a stronger temporary password and check the email.');
    if(['email_exists','email_exists_or_sso_enabled','user_already_exists'].includes(error.code??''))throw new AppError('invalid_input',400,'That email already has an account. Use its existing employee profile or a different email.');
    throw new AppError('save_failed',503,'Account setup was not confirmed. Check the temporary password and retry the same form.');
   }
   data=recovered.data;
  }
 }
 if(data.user?.id!==id||data.user?.app_metadata?.eigsti_onboarding!==fingerprint)throw new AppError('invalid_input',400,'This account request changed. Return to Employees and start a new form.');
 requireAdmin(await authorize());
 const result=await client.rpc('enroll_employee_account',{p_actor:actor.id,p_id:id,p_request:input.requestId,p_values:input.values});
 if(result.error)throw new AppError('save_failed',503,'Sign-in account may exist, but employee setup was not confirmed. Retry this unchanged form.');
 return result.data as Employee;
}
function isServiceKey(key:string){try{return JSON.parse(Buffer.from(key.split('.')[1],'base64url').toString()).role==='service_role';}catch{return false;}}
