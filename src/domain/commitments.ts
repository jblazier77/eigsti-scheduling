import {AppError} from './access.ts';
import {validDate,addDays,monday} from './visits.ts';
export type CommitmentValues={commitment_date:string|null;note:string};
export type Commitment=CommitmentValues&{id:string;job_id:string;contact_id:string};
export type CalendarCommitment=Commitment&{contact_name:string;phone_action:string|null;job_title:string};
export type JobCommitments={can_manage:boolean;items:Commitment[]};
export function isSubcontractor(value:string){return value.trim().toLowerCase()==='subcontractor';}
export function validateCommitment(input:unknown):CommitmentValues{
 const fail=()=>{throw new AppError('invalid_input',400,'Enter a commitment date or note, up to 2,000 characters.');};
 if(!input||typeof input!=='object'||Array.isArray(input))return fail();
 const v=input as Record<string,unknown>;
 if(Object.keys(v).length!==2||!Object.hasOwn(v,'note')||!Object.hasOwn(v,'commitment_date')||typeof v.note!=='string'||v.note.length>2000||/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(v.note))return fail();
 if(v.commitment_date!==null&&!validDate(v.commitment_date))return fail();
 if(!v.note.trim()&&v.commitment_date===null)return fail();
 return {commitment_date:v.commitment_date as string|null,note:v.note.trim()};
}
export type CalendarView='day'|'week'|'two-weeks'|'month';
function shiftMonth(day:string,delta:number){const [year,month,date]=day.split('-').map(Number),first=new Date(Date.UTC(year,month-1+delta,1,12)),last=new Date(Date.UTC(first.getUTCFullYear(),first.getUTCMonth()+1,0,12)).getUTCDate();first.setUTCDate(Math.min(date,last));return first.toISOString().slice(0,10);}
export function calendarWindow(day:string,requested?:string){
 if(!validDate(day))throw new AppError('invalid_input',400,'Choose a calendar date.');
 const view:CalendarView=['day','week','two-weeks','month'].includes(requested??'')?requested as CalendarView:'day';
 let start=day,end=day;
 if(view==='week'||view==='two-weeks'){start=monday(day);end=addDays(start,view==='week'?6:13);}
 if(view==='month'){const first=day.slice(0,7)+'-01',next=shiftMonth(first,1);start=monday(first);end=addDays(monday(addDays(next,-1)),6);}
 const days:string[]=[];for(let d=start;d<=end;d=addDays(d,1))days.push(d);
 const chunks:{start:string;end:string}[]=[];for(let i=0;i<days.length;i+=28)chunks.push({start:days[i],end:days[Math.min(i+27,days.length-1)]});
 return {view,start,end,days,chunks,previous:view==='month'?shiftMonth(day,-1):addDays(day,view==='day'?-1:view==='week'?-7:-14),next:view==='month'?shiftMonth(day,1):addDays(day,view==='day'?1:view==='week'?7:14),label:view==='month'?new Intl.DateTimeFormat('en-US',{month:'long',year:'numeric',timeZone:'UTC'}).format(new Date(day+'T12:00:00Z')):start===end?day:start+' - '+end};
}
export function uniqueCalendarItems<T extends {id:string}>(groups:T[][]):T[]{return [...new Map(groups.flat().map(item=>[item.id,item])).values()];}
