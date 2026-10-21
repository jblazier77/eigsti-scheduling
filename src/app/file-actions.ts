'use server';

import { revalidatePath } from 'next/cache';
import { redirect, RedirectType } from 'next/navigation';
import { authClient } from '../lib/supabase-server';
import { appConfig } from '../lib/config';
import { FileSession, prepareFileUpload, type UploadPreparation } from '../server/files.ts';
import { AppError } from '../domain/access.ts';
import { archiveFile, fileUuid, finishFile } from '../domain/files.ts';
import type { FormState } from './actions';

export type UploadResult = { ok: true; upload: UploadPreparation } | { ok: false; message: string };
async function fileSession() {
  const config = appConfig();
  if (!config) throw new AppError('schema_pending', 503, 'The app connection is not configured yet.');
  const client = await authClient(true);
  const { data } = await client.auth.getSession();
  if (!data.session) throw new AppError('sign_in_required', 401, 'Please sign in again. Keep this tab open to retain the selected file.');
  const gateway = new FileSession(config, data.session.access_token);
  return { gateway, actor: await gateway.getActor() };
}
function errorMessage(error: unknown): string {
  return error instanceof AppError ? error.message : 'The upload was not confirmed. Keep this tab open and retry.';
}
export async function prepareFileAction(jobId: string, requestId: string, input: unknown): Promise<UploadResult> {
  try {
    const { gateway, actor } = await fileSession();
    const upload = await prepareFileUpload(actor, fileUuid(jobId), fileUuid(requestId), input, gateway);
    if (upload.complete) revalidatePath('/jobs/' + jobId);
    return { ok: true, upload };
  } catch (error) { return { ok: false, message: errorMessage(error) }; }
}
export async function finishFileAction(jobId: string, fileId: string): Promise<{ ok: boolean; message: string }> {
  try {
    const { gateway, actor } = await fileSession();
    await finishFile(actor, jobId, fileId, gateway);
    revalidatePath('/jobs/' + fileUuid(jobId));
    return { ok: true, message: 'File uploaded.' };
  } catch (error) { return { ok: false, message: errorMessage(error) }; }
}
export async function archiveFileAction(_previous: FormState, form: FormData): Promise<FormState> {
  let jobId: string;
  try {
    const { gateway, actor } = await fileSession();
    jobId = fileUuid(form.get('jobId'));
    await archiveFile(actor, jobId, form.get('fileId'), gateway);
  } catch (error) { return { message: errorMessage(error) }; }
  revalidatePath('/jobs/' + jobId);
  redirect('/jobs/' + jobId, RedirectType.replace);
}
