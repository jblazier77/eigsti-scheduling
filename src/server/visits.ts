import { WorkSession } from './work.ts';
import type { StaffOption, Visit, VisitValues } from '../domain/visits.ts';
export class VisitSession extends WorkSession {
  async saveVisitCard(workId: string, visitId: string, requestId: string, patch: Partial<VisitValues>, helpers: string[] | null): Promise<Visit> {
    return this.request('/rest/v1/rpc/save_visit_card', { method: 'POST', body: JSON.stringify({ p_work_id: workId, p_visit_id: visitId, p_request_id: requestId, p_patch: patch, p_helpers: helpers }) });
  }
  async saveVisit(workId: string, visitId: string | null, requestId: string, patch: Partial<VisitValues> & { state?: string }): Promise<Visit> {
    return this.request('/rest/v1/rpc/save_visit', { method: 'POST', body: JSON.stringify({ p_work_id: workId, p_visit_id: visitId, p_request_id: requestId, p_patch: patch }) });
  }
  async staffVisit(visitId: string, requestId: string, helpers: string[]): Promise<Visit> {
    return this.request('/rest/v1/rpc/staff_visit', { method: 'POST', body: JSON.stringify({ p_visit_id: visitId, p_request_id: requestId, p_helpers: helpers }) });
  }
  async getVisit(id: string): Promise<Visit> { return this.request('/rest/v1/rpc/get_visit', { method: 'POST', body: JSON.stringify({ p_visit_id: id }) }); }
  async jobVisits(jobId: string): Promise<Visit[]> { return this.request('/rest/v1/rpc/list_job_visits', { method: 'POST', body: JSON.stringify({ p_job_id: jobId }) }); }
  async schedule(start: string, end: string, all: boolean): Promise<Visit[]> { return this.request('/rest/v1/rpc/list_schedule', { method: 'POST', body: JSON.stringify({ p_start: start, p_end: end, p_all: all }) }); }
  async staffOptions(id: string): Promise<StaffOption[]> { return this.request('/rest/v1/rpc/visit_staff_options', { method: 'POST', body: JSON.stringify({ p_visit_id: id }) }); }
}
