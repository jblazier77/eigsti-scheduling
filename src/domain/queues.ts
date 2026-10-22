import { AppError, hasRole, requireActive, type Actor } from './access.ts';
import { workUuid } from './work.ts';

export type QueueItem = { id: string; job_id: string; description: string; job_title: string; customer_name: string; readiness: 'ready' | 'waiting_date' | 'waiting_unknown'; waiting_until: string | null };
export type LeadQueue = { lead_id: string; lead_name: string; revision: number; items: QueueItem[] };
export type QueueGateway = { getQueue(leadId: string): Promise<LeadQueue>; saveQueue(leadId: string, requestId: string, workIds: string[]): Promise<LeadQueue> };

export function requireQueueAccess(actor: Actor | null, target: unknown): string {
  requireActive(actor);
  const leadId = workUuid(target);
  if (!hasRole(actor, 'pm') && !(hasRole(actor, 'lead') && actor.id === leadId)) throw new AppError('not_allowed', 403, 'You can only open your own lead queue.');
  return leadId;
}
export function validateQueueOrder(input: unknown): string[] {
  if (!Array.isArray(input) || input.length > 500) throw new AppError('invalid_input', 400, 'Check the queue order.');
  const ids = input.map(workUuid);
  if (new Set(ids).size !== ids.length) throw new AppError('invalid_input', 400, 'Each work portion must appear exactly once.');
  return ids;
}
export function moveQueueItem(ids: string[], id: string, direction: -1 | 1): string[] {
  const from = ids.indexOf(id), to = from + direction;
  if (from < 0 || to < 0 || to >= ids.length) return [...ids];
  const next = [...ids]; [next[from], next[to]] = [next[to], next[from]]; return next;
}
export async function readQueue(actor: Actor | null, leadId: unknown, gateway: QueueGateway) {
  return gateway.getQueue(requireQueueAccess(actor, leadId));
}
export async function saveQueue(actor: Actor | null, leadId: unknown, requestId: unknown, input: unknown, gateway: QueueGateway) {
  return gateway.saveQueue(requireQueueAccess(actor, leadId), workUuid(requestId), validateQueueOrder(input));
}
