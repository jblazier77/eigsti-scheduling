import { SupabaseSession } from './supabase.ts';
import { AppError } from '../domain/access.ts';
import type { MaterialValues,WorkStatus } from '../domain/planning-updates.ts';
import type { VisitValues,StaffOption } from '../domain/visits.ts';
import { workUuid, type JobWork, type LeadOption, type WorkPatch, type WorkValues, type WorkChange, type WorkBatchResult } from '../domain/work.ts';

export class WorkSession extends SupabaseSession {
  async planningStaff(jobId:string|null):Promise<StaffOption[]>{try{return await this.request('/rest/v1/rpc/planning_staff',{method:'POST',body:JSON.stringify({p_job_id:jobId})});}catch(error){if(error instanceof AppError&&error.code==='schema_pending')return [];throw error;}}
  async createStaffedWork(jobId:string,requestId:string,values:WorkValues,plan:VisitValues|null,helpers:number,materials:MaterialValues|null,days:number|null,named:string[]):Promise<{id:string}>{return this.request('/rest/v1/rpc/create_staffed_work',{method:'POST',body:JSON.stringify({p_job_id:jobId,p_request_id:requestId,p_values:values,p_plan:plan,p_helpers:helpers,p_materials:materials,p_days:days,p_named_helpers:named})});}
  async workStatus(jobId:string):Promise<WorkStatus[]> {
    const base={job_id:'eq.'+workUuid(jobId),limit:'100'};
    try{return await this.request('/rest/v1/work_items?'+new URLSearchParams({...base,select:'id,readiness,waiting_until,material_name,material_status,material_expected_on,default_helpers,estimated_days'}));}
    catch(error){if(!(error instanceof AppError)||error.code!=='schema_pending')throw error;}
    try{return await this.request('/rest/v1/work_items?'+new URLSearchParams({...base,select:'id,readiness,waiting_until,material_name,material_status,material_expected_on'}));}
    catch(error){if(!(error instanceof AppError)||error.code!=='schema_pending')throw error;return this.request('/rest/v1/work_items?'+new URLSearchParams({...base,select:'id,readiness,waiting_until'}));}
  }
  async createPlanningWork(jobId:string,requestId:string,values:WorkValues,plan:VisitValues|null,helpers:number,materials:MaterialValues|null,days:number|null):Promise<{id:string}>{return this.request('/rest/v1/rpc/create_planning_work',{method:'POST',body:JSON.stringify({p_job_id:jobId,p_request_id:requestId,p_values:values,p_plan:plan,p_helpers:helpers,p_materials:materials,p_days:days})});}
  async saveWorkSetup(workId:string,requestId:string,patch:Record<string,unknown>,materials:MaterialValues|null,plan:VisitValues|null,visits:unknown[]=[],newHelpers:string[]|null=null):Promise<{id:string;job_id:string}>{return this.request('/rest/v1/rpc/save_work_setup_with_help',{method:'POST',body:JSON.stringify({p_work_id:workId,p_request_id:requestId,p_patch:patch,p_materials:materials,p_plan:plan,p_visits:visits,p_new_helpers:newHelpers})});}
  async saveWorkDetails(workId:string,requestId:string,values:Record<string,unknown>):Promise<{id:string;job_id:string}>{return this.request('/rest/v1/rpc/save_work_details',{method:'POST',body:JSON.stringify({p_work_id:workId,p_request_id:requestId,p_values:values})});}
  async createWorkWithPlan(jobId:string,requestId:string,values:WorkValues,plan:VisitValues|null):Promise<{id:string}>{return this.request('/rest/v1/rpc/create_job_work_with_plan',{method:'POST',body:JSON.stringify({p_job_id:jobId,p_request_id:requestId,p_values:values,p_plan:plan})});}
  async createQuickWork(jobId:string,requestId:string,values:WorkValues,plan:VisitValues|null,helpers:number,materials:MaterialValues|null):Promise<{id:string}>{return this.request('/rest/v1/rpc/create_quick_work',{method:'POST',body:JSON.stringify({p_job_id:jobId,p_request_id:requestId,p_values:values,p_plan:plan,p_helpers:helpers,p_materials:materials})});}
  async saveMaterials(workId:string,requestId:string,values:MaterialValues):Promise<{id:string;job_id:string}>{return this.request('/rest/v1/rpc/save_work_materials',{method:'POST',body:JSON.stringify({p_work_id:workId,p_request_id:requestId,p_values:values})});}
  async listWork(jobId: string): Promise<JobWork[]> {
    return this.request('/rest/v1/rpc/list_job_work', { method: 'POST', body: JSON.stringify({ p_job_id: workUuid(jobId) }) });
  }
  async listLeads(): Promise<LeadOption[]> { return this.request('/rest/v1/rpc/list_assignable_leads', { method: 'POST', body: '{}' }); }
  async createWork(jobId: string, requestId: string, values: WorkValues): Promise<{ id: string }> {
    return this.request('/rest/v1/rpc/create_job_work', { method: 'POST', body: JSON.stringify({ p_job_id: jobId, p_request_id: requestId, p_values: values }) });
  }
  async updateWork(jobId: string, workId: string, patch: WorkPatch): Promise<{ id: string }> {
    return this.request('/rest/v1/rpc/update_job_work', { method: 'POST', body: JSON.stringify({ p_job_id: jobId, p_work_id: workId, p_patch: patch }) });
  }
  async updateWorkBatch(jobId: string, requestId: string, changes: WorkChange[]): Promise<WorkBatchResult> {
    return this.request('/rest/v1/rpc/update_job_work_batch', { method: 'POST', body: JSON.stringify({ p_job_id: jobId, p_request_id: requestId, p_changes: changes }) });
  }
}
