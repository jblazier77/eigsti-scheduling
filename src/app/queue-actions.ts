'use server';

import { revalidatePath } from 'next/cache';
import { queueSession } from '../lib/queue-session';
import { saveQueue, type LeadQueue } from '../domain/queues.ts';
import { AppError } from '../domain/access.ts';

export type QueueState = { message: string; uncertain?: boolean; membershipChanged?: boolean; queue?: LeadQueue; saved?: boolean };
export async function saveQueueAction(_previous: QueueState, form: FormData): Promise<QueueState> {
  let queue: LeadQueue;
  try {
    const { actor, gateway } = await queueSession();
    const raw = form.get('order');
    let order: unknown;
    try { if (typeof raw !== 'string' || raw.length > 20000) throw new Error(); order = JSON.parse(raw); }
    catch { throw new AppError('invalid_input', 400, 'Check the queue order.'); }
    queue = await saveQueue(actor, form.get('leadId'), form.get('requestId'), order, gateway);
  } catch (error) {
    return { message: error instanceof AppError ? error.message : 'The save was not confirmed. Your order is retained for retry.', uncertain: !(error instanceof AppError) || ['connection_failed', 'save_failed'].includes(error.code), membershipChanged: error instanceof AppError && error.code === 'queue_membership_changed' };
  }
  revalidatePath('/queue');
  return { message: 'Queue saved.', queue };
}
