'use server';

import { revalidatePath } from 'next/cache';
import { workSession } from '../lib/work-session';
import { createWork, updateWork, updateWorkCard, workUuid, type JobWork } from '../domain/work.ts';
import { AppError } from '../domain/access.ts';
import type { FormState } from './actions';

function payload(form: FormData, maxLength = 8000): unknown {
  const raw = form.get('values');
  try { if (typeof raw !== 'string' || raw.length > maxLength) throw new Error(); return JSON.parse(raw); }
  catch { throw new AppError('invalid_input', 400, 'Check the work details.'); }
}
function failure(error: unknown): FormState {
  return { message: error instanceof AppError ? error.message : 'The save was not confirmed. Your details are still here.', uncertain: !(error instanceof AppError) || ['connection_failed', 'save_failed'].includes(error.code) };
}
export async function createWorkAction(_previous: FormState, form: FormData): Promise<FormState> {
  let jobId: string;
  try {
    const { gateway, actor } = await workSession(true);
    jobId = workUuid(form.get('jobId'));
    await createWork(actor, jobId, form.get('requestId'), payload(form), gateway);
  } catch (error) { return failure(error); }
  revalidatePath('/jobs'); revalidatePath('/jobs/' + jobId);
  return { message: 'Work portion added.', jobId };
}
export async function updateWorkAction(_previous: FormState, form: FormData): Promise<FormState> {
  let jobId: string;
  try {
    const { gateway, actor } = await workSession(true);
    jobId = workUuid(form.get('jobId'));
    await updateWork(actor, jobId, form.get('workId'), payload(form), gateway);
  } catch (error) { return failure(error); }
  revalidatePath('/jobs'); revalidatePath('/jobs/' + jobId);
  return { message: 'Work and lead saved.', jobId };
}

export type WorkCardState = FormState & { work?: JobWork[] };
export async function updateWorkCardAction(_previous: WorkCardState, form: FormData): Promise<WorkCardState> {
  let jobId: string;
  let work: JobWork[];
  try {
    const { gateway, actor } = await workSession(true);
    jobId = workUuid(form.get('jobId'));
    const result = await updateWorkCard(actor, jobId, form.get('requestId'), payload(form, 20000), gateway);
    work = result.work;
  } catch (error) { return failure(error); }
  revalidatePath('/jobs'); revalidatePath('/jobs/' + jobId);
  return { message: 'Work and leads saved.', jobId, work };
}
