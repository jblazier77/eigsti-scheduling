import { SupabaseSession } from './supabase.ts';
import { AppError } from '../domain/access.ts';
import type { MaterialValues,WorkStatus } from '../domain/planning-updates.ts';
import type { VisitValues } from '../domain/visits.ts';
import { workUuid, type JobWork, type LeadOption, type WorkPatch, type WorkValues, type WorkChange, type WorkBatchResult } from '../domain/work.ts';

export class WorkSession extends SupabaseSession {
  async workStatus(jobId:string):Promise<WorkStatus[]> {
    const base={job_id:'eq.'+workUuid(jobId),limit:'100'};
    try{return await this.request('/rest/v1/work_items?'+new URLSearchParams({...base,select:'id,readiness,waiting_until,material_name,material_status,material_expected_on,default_helpers'}));}
    catch(error){if(!(error instanceof AppError)||error.code!=='schema_pending')throw error;}
    try{return await this.request('/rest/v1/work_items?'+new URLSearchParams({...base,select:'id,readiness,waiting_until,material_name,material_status,material_expected_on'}));}
    catch(error){if(!(error instanceof AppError)||error.code!=='schema_pending')throw error;return this.request('/rest/v1/work_items?'+new URLSearchParams({...base,select:'id,readiness,waiting_until'}));}
  }
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
