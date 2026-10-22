import { SupabaseSession } from './supabase.ts';
import { workUuid, type JobWork, type LeadOption, type WorkPatch, type WorkValues, type WorkChange, type WorkBatchResult } from '../domain/work.ts';

export class WorkSession extends SupabaseSession {
  async workStatus(jobId:string):Promise<{id:string;readiness:string;waiting_until:string|null}[]> {
    return this.request('/rest/v1/work_items?'+new URLSearchParams({select:'id,readiness,waiting_until',job_id:'eq.'+workUuid(jobId),limit:'100'}));
  }
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
