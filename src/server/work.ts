import { SupabaseSession } from './supabase.ts';
import { workUuid, type JobWork, type LeadOption, type WorkPatch, type WorkValues } from '../domain/work.ts';

export class WorkSession extends SupabaseSession {
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
}
