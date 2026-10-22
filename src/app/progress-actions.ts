'use server';
import { revalidatePath } from 'next/cache';
import { visitSession } from '../lib/visit-session';
import { progressInput, type ProgressResult } from '../domain/progress.ts';
import { AppError } from '../domain/access.ts';
export type ProgressState = { message: string; uncertain?: boolean; saved?: boolean; result?: ProgressResult };
export async function workProgressAction(_previous: ProgressState,form: FormData): Promise<ProgressState> {
  let result: ProgressResult;
  try { const {actor,gateway}=await visitSession(); result=await gateway.progress(progressInput(actor,form)); }
  catch(error) { return {message:error instanceof AppError?error.message:'The action was not confirmed. Keep your draft and retry.',uncertain:!(error instanceof AppError)||['connection_failed','save_failed'].includes(error.code)}; }
  revalidatePath('/jobs/'+result.job_id);revalidatePath('/jobs');revalidatePath('/schedule');revalidatePath('/queue');
  return {message:'Saved.',saved:true,result};
}
