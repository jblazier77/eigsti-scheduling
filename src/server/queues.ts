import { WorkSession } from './work.ts';
import type { LeadQueue } from '../domain/queues.ts';

export class QueueSession extends WorkSession {
  async getQueue(leadId: string): Promise<LeadQueue> {
    return this.request('/rest/v1/rpc/get_lead_queue', { method: 'POST', body: JSON.stringify({ p_lead_id: leadId }) });
  }
  async saveQueue(leadId: string, requestId: string, workIds: string[]): Promise<LeadQueue> {
    return this.request('/rest/v1/rpc/save_lead_queue', { method: 'POST', body: JSON.stringify({ p_lead_id: leadId, p_request_id: requestId, p_work_ids: workIds }) });
  }
}
