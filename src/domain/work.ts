import { AppError, requirePm, type Actor } from './access.ts';
import { uuidPattern } from './jobs.ts';

export type WorkValues = { description: string; responsible_lead: string | null };
export type WorkPatch = Partial<WorkValues>;
export type JobWork = WorkValues & { id: string; job_id: string; lead_name: string | null; completion: 'open' | 'completed' };
export type LeadOption = { id: string; display_name: string };
export type WorkGateway = {
  createWork(jobId: string, requestId: string, values: WorkValues): Promise<{ id: string }>;
  updateWork(jobId: string, workId: string, patch: WorkPatch): Promise<{ id: string }>;
};
export function workUuid(value: unknown): string {
  if (typeof value !== 'string' || !uuidPattern.test(value)) throw new AppError('invalid_input', 400, 'Invalid job, work or lead identifier.');
  return value.toLowerCase();
}
export function validateWork(input: unknown, partial = false): WorkPatch {
  if (!input || typeof input !== 'object' || Array.isArray(input) || !Object.keys(input).length) throw new AppError('invalid_input', 400, 'Enter the work details.');
  if (!partial && (!Object.hasOwn(input, 'description') || !Object.hasOwn(input, 'responsible_lead'))) throw new AppError('invalid_input', 400, 'Enter the work details.');
  const patch: WorkPatch = {};
  for (const [key, value] of Object.entries(input)) {
    if (key === 'description') {
      if (typeof value !== 'string' || !value.trim() || value.length > 1000 || /[\u0000-\u001f\u007f]/.test(value)) throw new AppError('invalid_input', 400, 'Describe the work using 1–1,000 characters on one line.');
      patch.description = value.trim();
    } else if (key === 'responsible_lead') patch.responsible_lead = value === null ? null : workUuid(value);
    else throw new AppError('invalid_input', 400, 'Unexpected work fields.');
  }
  return patch;
}
export function changedWorkFields(original: WorkValues, values: WorkValues): WorkPatch {
  const patch: WorkPatch = {};
  if (values.description.trim() !== original.description) patch.description = values.description.trim();
  if (values.responsible_lead !== original.responsible_lead) patch.responsible_lead = values.responsible_lead;
  return patch;
}
export async function createWork(actor: Actor | null, jobId: unknown, requestId: unknown, input: unknown, gateway: WorkGateway) {
  requirePm(actor);
  return gateway.createWork(workUuid(jobId), workUuid(requestId), validateWork(input) as WorkValues);
}
export async function updateWork(actor: Actor | null, jobId: unknown, workId: unknown, input: unknown, gateway: WorkGateway) {
  requirePm(actor);
  return gateway.updateWork(workUuid(jobId), workUuid(workId), validateWork(input, true));
}
