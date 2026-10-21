import { AppError, requireActive, hasRole, type Actor } from './access.ts';
import { uuidPattern } from './jobs.ts';

export const FILE_BUCKET = 'eigsti-job-files';
export const MAX_FILE_BYTES = 10 * 1024 * 1024;
export const FILE_TYPES = { pdf: 'application/pdf', jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp', heic: 'image/heic', heif: 'image/heif' } as const;
export const FILE_ACCEPT = '.pdf,.jpg,.jpeg,.png,.webp,.heic,.heif';
export type FileInput = { name: string; size: number; mime: string };
export type JobFile = { id: string; job_id: string; filename: string; byte_size: number; mime_type: string; object_path: string; status: 'pending' | 'ready' | 'archived'; created_by: string; created_at: string };

export function fileUuid(value: unknown): string {
  if (typeof value !== 'string' || !uuidPattern.test(value)) throw new AppError('invalid_input', 400, 'Invalid file or job identifier.');
  return value;
}

export function requireFileWriter(actor: Actor | null) {
  requireActive(actor);
  if (!hasRole(actor, 'pm') && !hasRole(actor, 'lead')) throw new AppError('not_allowed', 403, 'A project manager or assigned lead account is required.');
}

export function validateFile(input: unknown): FileInput {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new AppError('invalid_input', 400, 'Choose a photo or PDF.');
  const obj = input as Record<string, unknown>;
  if (Object.keys(obj).some(key => !['name', 'size', 'mime'].includes(key))) throw new AppError('invalid_input', 400, 'Unexpected file details.');
  if (typeof obj.name !== 'string' || !obj.name.trim() || obj.name.length > 180 || /[\u0000-\u001f\u007f/\\]/.test(obj.name) || obj.name.trim().startsWith('.')) throw new AppError('invalid_input', 400, 'Use a filename of up to 180 characters without slashes or control characters.');
  if (typeof obj.size !== 'number' || !Number.isSafeInteger(obj.size) || obj.size < 1 || obj.size > MAX_FILE_BYTES) throw new AppError('invalid_input', 400, 'Choose a nonempty file of 10 MB or less.');
  const name = obj.name.trim();
  const extension = name.split('.').pop()?.toLowerCase() as keyof typeof FILE_TYPES;
  const expected = Object.hasOwn(FILE_TYPES, extension) ? FILE_TYPES[extension] : undefined;
  if (!expected || typeof obj.mime !== 'string' || (obj.mime !== '' && obj.mime !== 'application/octet-stream' && obj.mime.toLowerCase() !== expected)) throw new AppError('invalid_input', 400, 'Choose a PDF, JPEG, PNG, WebP, HEIC or HEIF file with a matching file type.');
  return { name, size: obj.size, mime: expected };
}

export function filePath(jobId: string, fileId: string): string {
  return fileUuid(jobId).toLowerCase() + '/' + fileUuid(fileId).toLowerCase();
}

export type FileCommands = {
  beginFile(jobId: string, requestId: string, input: FileInput): Promise<{ id: string }>;
  finishFile(jobId: string, fileId: string): Promise<{ id: string }>;
  archiveFile(jobId: string, fileId: string): Promise<{ id: string }>;
};
export async function beginFile(actor: Actor | null, jobId: unknown, requestId: unknown, input: unknown, gateway: FileCommands) {
  requireFileWriter(actor);
  return gateway.beginFile(fileUuid(jobId), fileUuid(requestId), validateFile(input));
}
export async function finishFile(actor: Actor | null, jobId: unknown, fileId: unknown, gateway: FileCommands) {
  requireFileWriter(actor);
  return gateway.finishFile(fileUuid(jobId), fileUuid(fileId));
}
export async function archiveFile(actor: Actor | null, jobId: unknown, fileId: unknown, gateway: FileCommands) {
  requireFileWriter(actor);
  return gateway.archiveFile(fileUuid(jobId), fileUuid(fileId));
}
