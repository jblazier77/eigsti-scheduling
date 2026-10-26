import {AppError} from './access.ts';
export function optionalNumber(value:unknown,kind:'priority'|'days'):number|null {
 if(value===null||value==='')return null;
 if(typeof value!=='number'&&typeof value!=='string')throw new AppError('invalid_input',400,'Enter a valid '+kind+'.');
 const text=String(value);const n=Number(value);
 if(!/^\d+(?:\.\d{1,2})?$/.test(text)||!Number.isFinite(n)||n<=0||n>(kind==='priority'?9999:999)||(kind==='priority'&&!Number.isInteger(n)))throw new AppError('invalid_input',400,kind==='priority'?'Use a whole priority number from 1 to 9999, or leave blank.':'Use estimated days greater than 0 and up to 999, or leave blank.');
 return n;
}
export type HelpRequest={job_id:string;title:string;description:string;work_id:string;visit_id:string|null;start_date:string|null;end_date:string|null;requested:number;assigned:number;missing:number;priority:number|null};
