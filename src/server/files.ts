import { createClient } from '@supabase/supabase-js';
import { SupabaseSession, validateConfig, type SupabaseConfig } from './supabase.ts';
import { AppError, type Actor } from '../domain/access.ts';
import { FILE_BUCKET, beginFile, filePath, fileUuid, requireFileWriter, type FileInput, type JobFile } from '../domain/files.ts';

export class FileSession extends SupabaseSession {
  private storage;
  private storageOrigin: string;
  constructor(config: SupabaseConfig, token: string, transport: typeof fetch = fetch) {
    super(config, token, transport);
    this.storageOrigin = validateConfig(config);
    this.storage = createClient(this.storageOrigin, config.publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
      global: { headers: { Authorization: 'Bearer ' + token }, fetch: (url, init) => transport(url, { ...init, cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(15000) }) }
    }).storage.from(FILE_BUCKET);
  }
  async listFiles(jobId: string): Promise<JobFile[]> {
    return this.request('/rest/v1/job_files?' + new URLSearchParams({ select: '*', job_id: 'eq.' + fileUuid(jobId), status: 'neq.archived', order: 'created_at.desc,id.desc', limit: '100' }));
  }
  async getFile(jobId: string, fileId: string): Promise<JobFile | null> {
    const rows = await this.request('/rest/v1/job_files?' + new URLSearchParams({ select: '*', job_id: 'eq.' + fileUuid(jobId), id: 'eq.' + fileUuid(fileId), limit: '1' }));
    return rows[0] ?? null;
  }
  async beginFile(jobId: string, requestId: string, input: FileInput): Promise<{ id: string }> {
    return this.request('/rest/v1/rpc/begin_job_file', { method: 'POST', body: JSON.stringify({ p_job_id: jobId, p_request_id: requestId, p_filename: input.name, p_mime: input.mime, p_size: input.size }) });
  }
  async finishFile(jobId: string, fileId: string): Promise<{ id: string }> {
    return this.request('/rest/v1/rpc/finish_job_file', { method: 'POST', body: JSON.stringify({ p_job_id: jobId, p_file_id: fileId }) });
  }
  async archiveFile(jobId: string, fileId: string): Promise<{ id: string }> {
    return this.request('/rest/v1/rpc/archive_job_file', { method: 'POST', body: JSON.stringify({ p_job_id: jobId, p_file_id: fileId }) });
  }
  async signUpload(path: string): Promise<string> {
    const { data, error } = await this.storage.createSignedUploadUrl(path, { upsert: false });
    if (error || !data) throw new AppError('connection_failed', 503, 'The upload could not be started. Keep this tab open and retry.');
    return this.scopedUrl(data.signedUrl, '/storage/v1/object/upload/sign/' + FILE_BUCKET + '/' + path);
  }
  async signDownload(file: JobFile): Promise<string> {
    const { data, error } = await this.storage.createSignedUrl(filePath(file.job_id, file.id), 60, { download: file.filename });
    if (error || !data) throw new AppError('file_unavailable', 404, 'This file is unavailable.');
    return this.scopedUrl(data.signedUrl, '/storage/v1/object/sign/' + FILE_BUCKET + '/' + file.object_path);
  }
  private scopedUrl(value: string, expectedPath: string): string {
    const url = new URL(value);
    if (url.origin !== this.storageOrigin || decodeURIComponent(url.pathname) !== expectedPath) throw new AppError('invalid_storage_url', 503, 'Could not verify the file connection.');
    return url.href;
  }
}

export type UploadPreparation = { fileId: string; complete: boolean; signedUrl?: string; mime?: string };
type UploadGateway = Pick<FileSession, 'beginFile' | 'finishFile' | 'archiveFile' | 'getFile' | 'signUpload'>;

export async function prepareFileUpload(actor: Actor | null, jobId: string, requestId: string, input: unknown, gateway: UploadGateway): Promise<UploadPreparation> {
  requireFileWriter(actor);
  const reserved = await beginFile(actor, jobId, requestId, input, gateway);
  const file = await gateway.getFile(jobId, reserved.id);
  if (!file || file.object_path !== filePath(jobId, reserved.id) || file.status === 'archived') throw new AppError('file_unavailable', 404, 'This upload is unavailable. Choose a new file to start again.');
  if (file.status === 'ready') return { fileId: file.id, complete: true };
  // A previous transfer may have succeeded while its response was lost. Confirm
  // before issuing another upload ticket. Never overwrite an existing object.
  try { await gateway.finishFile(jobId, file.id); return { fileId: file.id, complete: true }; }
  catch (error) { if (!(error instanceof AppError) || error.code !== 'upload_pending') throw error; }
  return { fileId: file.id, complete: false, signedUrl: await gateway.signUpload(file.object_path), mime: file.mime_type };
}
