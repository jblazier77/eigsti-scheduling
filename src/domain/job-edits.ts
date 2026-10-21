import { AppError, requirePm, type Actor } from './access.ts';
import { normalizePhone, uuidPattern } from './jobs.ts';

export const jobEditFields = [
  { name: 'title', label: 'Job title', max: 405, required: true },
  { name: 'customer_name', label: 'Customer name', max: 100, required: true },
  { name: 'phone', label: 'Phone number', max: 40, required: true },
  { name: 'address', label: 'Job address', max: 300, required: true },
  { name: 'scope', label: 'Scope', max: 5000, required: false },
  { name: 'access_notes', label: 'Access and preparation', max: 2000, required: false }
] as const;
export type JobEditField = typeof jobEditFields[number]['name'];
export type JobEditValues = Record<JobEditField, string>;
export type JobPatch = Partial<JobEditValues>;
export type JobUpdateGateway = { updateJob(id: string, patch: JobPatch): Promise<{ id: string }> };

// Compare with the original form values, not a new read that might include another PM's edits.
export function changedJobFields(original: JobEditValues, edited: JobEditValues): JobPatch {
  const patch: JobPatch = {};
  for (const field of jobEditFields) {
    const value = field.required ? edited[field.name].trim() : edited[field.name];
    if (value !== original[field.name]) patch[field.name] = value;
  }
  return patch;
}

export function validateJobPatch(input: unknown): JobPatch {
  if (!input || typeof input !== 'object' || Array.isArray(input) || Object.keys(input).length === 0) {
    throw new AppError('invalid_input', 400, 'Change at least one job detail before saving.');
  }
  const patch: JobPatch = {};
  for (const [key, value] of Object.entries(input)) {
    const field = jobEditFields.find(field => field.name === key);
    if (!field || typeof value !== 'string') throw new AppError('invalid_input', 400, 'Unexpected job fields.');
    const invalidControls = field.required ? /[\u0000-\u001f\u007f]/ : /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/;
    if (value.length > field.max || invalidControls.test(value) || (field.required && !value.trim())) {
      throw new AppError('invalid_input', 400, `${field.label}${field.required ? ' is required and' : ''} must be no more than ${field.max} characters and contain valid text.`);
    }
    patch[field.name] = field.required ? value.trim() : value;
    if (field.name === 'phone') normalizePhone(value.trim());
  }
  return patch;
}

export async function updateJob(actor: Actor | null, id: unknown, input: unknown, gateway: JobUpdateGateway) {
  requirePm(actor);
  if (typeof id !== 'string' || !uuidPattern.test(id)) throw new AppError('invalid_input', 400, 'Invalid job identifier.');
  return gateway.updateJob(id, validateJobPatch(input));
}
