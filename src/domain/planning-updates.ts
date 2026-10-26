import {AppError} from './access.ts';
import {validDate,validateVisit,type VisitValues} from './visits.ts';
import type {WorkValues} from './work.ts';
export const materialLabels={not_set:'Not set',not_needed:'No material hold',need_to_order:'Need to order',ordered:'Ordered',in_stock:'In stock'} as const;
export type MaterialValues={material_name:string;material_status:keyof typeof materialLabels;material_expected_on:string|null};
export type WorkStatus={id:string;readiness:string;waiting_until:string|null;default_helpers?:number;estimated_days?:number|null}&Partial<MaterialValues>;
export function helperCount(input:unknown):number{
 if(typeof input!=='string'||!/^\d{1,2}$/.test(input)||Number(input)>20)throw new AppError('invalid_input',400,'Choose between 0 and 20 helpers.');
 return Number(input);
}
export function validateMaterial(input:unknown):MaterialValues{
 const fail=()=>{throw new AppError('invalid_input',400,'Choose a material status, describe the material and check its expected date.');};
 if(!input||typeof input!=='object'||Array.isArray(input))return fail();
 const values=input as Record<string,unknown>;
 if(Object.keys(values).length!==3||!['material_name','material_status','material_expected_on'].every(k=>Object.hasOwn(values,k)))return fail();
 if(typeof values.material_name!=='string'||values.material_name.length>300||/[\u0000-\u001f\u007f]/.test(values.material_name)||typeof values.material_status!=='string'||!Object.hasOwn(materialLabels,values.material_status))return fail();
 const name=values.material_name.trim(),status=values.material_status as MaterialValues['material_status'];
 if(['need_to_order','ordered','in_stock'].includes(status)&&!name)return fail();
 const date=values.material_expected_on;
 if(date!==null&&(!validDate(date)||!['need_to_order','ordered'].includes(status)))return fail();
 return {material_name:name,material_status:status,material_expected_on:date as string|null};
}
export function validateOptionalPlan(raw:unknown,work:WorkValues):VisitValues|null{
 if(raw===null)return null;
 if(!raw||typeof raw!=='object'||Array.isArray(raw))throw new AppError('invalid_input',400,'Check the optional work dates.');
 const plan=raw as Record<string,unknown>;
 if(Object.keys(plan).some(k=>!['start_date','end_date','slot','start_time','end_time','required_helpers'].includes(k)))throw new AppError('invalid_input',400,'Check the optional work dates.');
 return validateVisit({...plan,coordinator_id:work.responsible_lead,certainty:'tentative',required_helpers:String(plan.required_helpers??0)});
}
