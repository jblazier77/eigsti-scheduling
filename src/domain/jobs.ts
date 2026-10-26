import { AppError, requirePm, type Actor } from './access.ts';
import type { JobClassification } from './job-classification.ts';

export type CreateJobInput = { requestId: string; customer: string; phone: string; address: string };
export type ValidJobInput = CreateJobInput & { phoneAction: string };
export const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function requiredText(value: unknown, label: string, max: number): string {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > max || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(value)) {
    throw new AppError('invalid_input', 400, `${label} is required and must be no more than ${max} characters.`);
  }
  return value.trim();
}

export function normalizePhone(value: string): string {
  // US customer numbers are the first-release convention; readable input is retained.
  const digits = value.replace(/\D/g, '');
  const normalized = digits.length === 10 ? '+1' + digits : digits.length === 11 && digits[0] === '1' ? '+' + digits : null;
  if (!normalized || !/^[+()\d\s.\-]+$/.test(value)) {
    throw new AppError('invalid_input', 400, 'Enter a 10-digit US phone number, with optional +1.');
  }
  return normalized;
}

export function validateCreateJob(input: unknown): ValidJobInput {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new AppError('invalid_input', 400, 'Enter the job details.');
  const obj = input as Record<string, unknown>;
  if (Object.keys(obj).some(key => !['requestId', 'customer', 'phone', 'address'].includes(key))) {
    throw new AppError('invalid_input', 400, 'Unexpected job fields.');
  }
  const requestId = requiredText(obj.requestId, 'Request identifier', 36);
  if (!uuidPattern.test(requestId)) throw new AppError('invalid_input', 400, 'Invalid request identifier.');
  const customer = requiredText(obj.customer, 'Customer name', 100);
  const phone = requiredText(obj.phone, 'Phone number', 40);
  const address = requiredText(obj.address, 'Job address', 300);
  return { requestId, customer, phone, phoneAction: normalizePhone(phone), address };
}

export type JobSummary = {
  id: string; customer_name: string; phone: string; phone_action: string;
  address: string; title: string; responsible_pm: string | null; lifecycle: string; priority?:number|null;
} & Partial<JobClassification>;
export type JobsGateway = {
  createJob(input: ValidJobInput): Promise<JobSummary>;
  listJobs(query: { responsiblePm?: string; limit: number; offset: number; rainDay?:boolean; filler?:boolean; archived?:boolean }): Promise<JobSummary[]>;
};

export async function createJob(actor: Actor | null, input: unknown, gateway: JobsGateway) {
  requirePm(actor);
  // Atomic creation and retry deduplication happen in the database RPC, not here.
  return gateway.createJob(validateCreateJob(input));
}

export async function listJobs(actor: Actor | null, query: { scope?: string; offset?: string; kind?:string;state?:string }, gateway: JobsGateway) {
  if (!actor?.active) throw new AppError(actor ? 'access_disabled' : 'sign_in_required', actor ? 403 : 401, 'Please sign in with an active account.');
  const scope = query.scope ?? 'mine';
  if (scope !== 'mine' && scope !== 'all') throw new AppError('invalid_input', 400, 'Choose My Jobs or All Jobs.');
  if (scope === 'all' && !actor.roles.includes('pm')) throw new AppError('not_allowed', 403, 'All Jobs is available to project managers.');
  const offset = Number(query.offset ?? '0');
  if (!Number.isSafeInteger(offset) || offset < 0 || offset > 100000) throw new AppError('invalid_input', 400, 'Invalid page.');
  const kind=query.kind??'all';
  const state=query.state??'active';
  if(!['active','archived'].includes(state))throw new AppError('invalid_input',400,'Choose active or archived jobs.');
  if(state==='archived')requirePm(actor);
  if(!['all','rain','filler','both'].includes(kind))throw new AppError('invalid_input',400,'Choose a job filter.');
  return gateway.listJobs({ responsiblePm: scope === 'mine' && actor.roles.includes('pm') ? actor.id : undefined, limit: 50, offset,
    ...(kind==='rain'||kind==='both'?{rainDay:true}:{}),...(kind==='filler'||kind==='both'?{filler:true}:{}),...(state==='archived'?{archived:true}:{}) });
}
