'use server';
import {revalidatePath} from 'next/cache';
import {currentSession} from '../lib/session';
import {AppError} from '../domain/access.ts';
import {contactUuid} from '../domain/contacts.ts';
import {requireAdmin,validateEmployee,type Employee} from '../domain/employees.ts';
export type EmployeeState={message:string;employee?:Employee;uncertain?:boolean};
export async function saveEmployeeAction(_previous:EmployeeState,form:FormData):Promise<EmployeeState>{
 let employee:Employee;
 try{
  const session=await currentSession();requireAdmin(session?.actor??null);
  if(!session)throw new AppError('sign_in_required',401,'Please sign in.');
  const raw=form.get('values'),expected=form.get('expected');
  if(typeof raw!=='string'||raw.length>2000||typeof expected!=='string'||expected.length>50||!/^\d{4}-\d\d-\d\dT/.test(expected)||!Number.isFinite(Date.parse(expected)))throw new AppError('invalid_input',400,'Check the employee details.');
  let values;try{values=JSON.parse(raw);}catch{throw new AppError('invalid_input',400,'Check the employee details.');}
  employee=await session.gateway.saveEmployee(contactUuid(form.get('id')),contactUuid(form.get('requestId')),expected,validateEmployee(values));
 }catch(error){return {message:error instanceof AppError?error.message:'The employee change was not confirmed. Retry the same draft.',uncertain:!(error instanceof AppError)||['connection_failed','save_failed'].includes(error.code)};}
 revalidatePath('/','layout');return {message:'Employee saved.',employee};
}
