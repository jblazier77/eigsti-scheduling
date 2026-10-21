import { AppError, requirePm, type Actor } from './access.ts';
import { normalizePhone, uuidPattern } from './jobs.ts';

export const contactFields = [
  { name: 'name', label: 'Contact name', max: 100, required: true },
  { name: 'relationship', label: 'Relationship or trade', max: 100, required: false },
  { name: 'phone', label: 'Phone number', max: 40, required: false },
  { name: 'email', label: 'Email address', max: 254, required: false },
  { name: 'notes', label: 'Contact notes', max: 1000, required: false }
] as const;
export type ContactField = typeof contactFields[number]['name'];
export type ContactValues = Record<ContactField, string>;
export type ContactPatch = Partial<ContactValues>;
export type JobContact = ContactValues & { id: string; job_id: string; phone_action: string | null };
export const emptyContact: ContactValues = { name: '', relationship: '', phone: '', email: '', notes: '' };
export type ContactsGateway = {
  createContact(jobId: string, requestId: string, values: ContactValues): Promise<{ id: string }>;
  updateContact(jobId: string, contactId: string, patch: ContactPatch): Promise<{ id: string }>;
  archiveContact(jobId: string, contactId: string): Promise<{ id: string }>;
};

export function contactUuid(value: unknown): string {
  if (typeof value !== 'string' || !uuidPattern.test(value)) throw new AppError('invalid_input', 400, 'Invalid contact or job identifier.');
  return value;
}

export function validateContact(input: unknown, partial = false): ContactPatch {
  if (!input || typeof input !== 'object' || Array.isArray(input) || !Object.keys(input).length) throw new AppError('invalid_input', 400, 'Enter the contact details.');
  if (!partial && contactFields.some(field => !Object.hasOwn(input, field.name))) throw new AppError('invalid_input', 400, 'Enter the contact details.');
  const patch: ContactPatch = {};
  for (const [key, value] of Object.entries(input)) {
    const field = contactFields.find(field => field.name === key);
    if (!field || typeof value !== 'string') throw new AppError('invalid_input', 400, 'Unexpected contact fields.');
    const controls = field.name === 'notes' ? /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/ : /[\u0000-\u001f\u007f]/;
    if (value.length > field.max || controls.test(value) || (field.required && !value.trim())) throw new AppError('invalid_input', 400, `${field.label}${field.required ? ' is required and' : ''} must be no more than ${field.max} characters and contain valid text.`);
    const text = field.name === 'notes' ? value : value.trim();
    if (field.name === 'phone' && text) normalizePhone(text);
    if (field.name === 'email' && text && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(text)) throw new AppError('invalid_input', 400, 'Enter a valid email address or leave it empty.');
    patch[field.name] = text;
  }
  return patch;
}

export function changedContactFields(original: ContactValues, values: ContactValues): ContactPatch {
  const patch: ContactPatch = {};
  for (const field of contactFields) {
    const value = field.name === 'notes' ? values[field.name] : values[field.name].trim();
    if (value !== original[field.name]) patch[field.name] = value;
  }
  return patch;
}

export async function createContact(actor: Actor | null, jobId: unknown, requestId: unknown, input: unknown, gateway: ContactsGateway) {
  requirePm(actor);
  return gateway.createContact(contactUuid(jobId), contactUuid(requestId), validateContact(input) as ContactValues);
}
export async function updateContact(actor: Actor | null, jobId: unknown, contactId: unknown, input: unknown, gateway: ContactsGateway) {
  requirePm(actor);
  return gateway.updateContact(contactUuid(jobId), contactUuid(contactId), validateContact(input, true));
}
export async function archiveContact(actor: Actor | null, jobId: unknown, contactId: unknown, gateway: ContactsGateway) {
  requirePm(actor);
  return gateway.archiveContact(contactUuid(jobId), contactUuid(contactId));
}
