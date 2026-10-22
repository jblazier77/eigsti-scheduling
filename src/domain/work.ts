import { AppError, requirePm, type Actor } from './access.ts';
import { uuidPattern } from './jobs.ts';

export type WorkValues = { description: string; responsible_lead: string | null };
export type WorkPatch = Partial<WorkValues>;
export type WorkChange = { work_id: string; patch: WorkPatch };
export type JobWork = WorkValues & { id: string; job_id: string; lead_name: string | null; completion: 'open' | 'completed' };
export type WorkBatchResult = { id: string; work: JobWork[] };
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

export function validateWorkChanges(input: unknown): WorkChange[] {
  if (!Array.isArray(input) || input.length < 1 || input.length > 100) throw new AppError('invalid_input', 400, 'Change at least one work portion before saving.');
  if (new TextEncoder().encode(JSON.stringify(input)).length > 20000) throw new AppError('invalid_input', 400, 'These edits are too large for one save. Shorten the work descriptions before saving.');
  const seen = new Set<string>();
  return input.map(change => {
    if (!change || typeof change !== 'object' || Array.isArray(change) || Object.keys(change).length !== 2 || !Object.hasOwn(change, 'work_id') || !Object.hasOwn(change, 'patch')) throw new AppError('invalid_input', 400, 'Check the work changes.');
    const work_id = workUuid(change.work_id);
    if (seen.has(work_id)) throw new AppError('invalid_input', 400, 'A work portion appears more than once.');
    seen.add(work_id);
    return { work_id, patch: validateWork(change.patch, true) };
  }).sort((a, b) => a.work_id.localeCompare(b.work_id));
}

export function changedWorkCard(original: JobWork[], values: Record<string, WorkValues>): WorkChange[] {
  return original.filter(item => item.completion === 'open').flatMap(item => {
    const patch = changedWorkFields(item, values[item.id] ?? item);
    return Object.keys(patch).length ? [{ work_id: item.id, patch }] : [];
  });
}

export async function updateWorkCard(actor: Actor | null, jobId: unknown, requestId: unknown, input: unknown, gateway: { updateWorkBatch(jobId: string, requestId: string, changes: WorkChange[]): Promise<WorkBatchResult> }) {
  requirePm(actor);
  return gateway.updateWorkBatch(workUuid(jobId), workUuid(requestId), validateWorkChanges(input));
}
