import {AppError,requireActive,type Actor,type AccountRole} from './access.ts';
export const employeeRoles:AccountRole[]=['admin','pm','lead','helper'];
export type EmployeeValues={display_name:string;roles:AccountRole[];active:boolean};
export type Employee=EmployeeValues&{id:string;updated_at:string;open_work:number;scheduled_work:number};
export function requireAdmin(actor:Actor|null){requireActive(actor);if(!actor.roles.includes('admin'))throw new AppError('not_allowed',403,'An administrator account is required.');}
export function validateEmployee(input:unknown):EmployeeValues{
 const fail=()=>{throw new AppError('invalid_input',400,'Enter a name (up to 100 characters), at least one role and an active status.');};
 if(!input||typeof input!=='object'||Array.isArray(input))return fail();
 const v=input as Record<string,unknown>;
 if(Object.keys(v).length!==3||typeof v.display_name!=='string'||!v.display_name.trim()||v.display_name.trim().length>100||/[\u0000-\u001f\u007f]/.test(v.display_name)||typeof v.active!=='boolean'||!Array.isArray(v.roles)||v.roles.length<1||v.roles.length>4||new Set(v.roles).size!==v.roles.length||v.roles.some(r=>!employeeRoles.includes(r)))return fail();
 return {display_name:v.display_name.trim(),roles:[...v.roles].sort(),active:v.active};
}
