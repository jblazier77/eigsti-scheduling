'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { cookies } from 'next/headers';
import { authClient } from '../lib/supabase-server';
import { appConfig } from '../lib/config';
import { SupabaseSession } from '../server/supabase.ts';
import { validateCreateJob } from '../domain/jobs.ts';
import { classificationPatch } from '../domain/job-classification.ts';
import { updateJob } from '../domain/job-edits.ts';
import { AppError, requirePm } from '../domain/access.ts';
import { signOutWithDeadline } from '../server/sign-out.ts';

export type FormState = { message: string; uncertain?: boolean; jobId?: string };

export async function signInAction(_previous: FormState, form: FormData): Promise<FormState> {
  const email = form.get('email');
  const password = form.get('password');
  if (typeof email !== 'string' || typeof password !== 'string' || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim()) || !password || password.length > 1024) return { message: 'Enter your email address and password.' };
  try {
    const env = appConfig();
    if (!env) return { message: 'The app connection is not configured yet.' };
    const client = await authClient(true);
    const { data, error } = await client.auth.signInWithPassword({ email: email.trim().toLowerCase(), password });
    if (error || !data.session) return { message: error?.status === 429 ? 'Too many attempts. Please try again later.' : 'Could not sign in. Check your details or contact your administrator.' };
    try {
      await new SupabaseSession(env, data.session.access_token).getActor();
    } catch (error) {
      await client.auth.signOut({ scope: 'local' });
      return { message: error instanceof AppError ? error.message : 'Could not verify account access. Please try again.' };
    }
  } catch { return { message: 'Could not connect. Please try again.' }; }
  redirect('/jobs');
}

export async function signOutAction() {
  try {
    await signOutWithDeadline(async signal => {
      const client = await authClient(false, signal);
      await client.auth.signOut({ scope: 'local' });
    });
  } finally {
    // Local sign-out completes even if remote refresh-token revocation fails.
    const jar = await cookies();
    const name = `sb-${process.env.EIGSTI_EXPECTED_PROJECT_REF}-auth-token`;
    for (const cookie of jar.getAll()) if (cookie.name === name || cookie.name.startsWith(name + '.')) jar.delete(cookie.name);
  }
  redirect('/login');
}

export async function createJobAction(_previous: FormState, form: FormData): Promise<FormState> {
  let id: string;
  try {
    const env = appConfig();
    if (!env) return { message: 'The app connection is not configured yet.' };
    const client = await authClient(true);
    const { data } = await client.auth.getSession();
    if (!data.session) return { message: 'Your sign-in expired. Your job details are still on this screen.' };
    const gateway = new SupabaseSession(env, data.session.access_token);
    // Reauthorize on every action, even if a PM form was visible earlier.
    const actor = await gateway.getActor();
    requirePm(actor);
    let rawClassification:unknown;
    try{const text=form.get('classification')??'{}';if(typeof text!=='string'||text.length>6000)throw new Error('Invalid tags');rawClassification=JSON.parse(text);}
    catch{throw new AppError('invalid_input',400,'Check the job tags.');}
    const classification=classificationPatch(rawClassification);
    const job = await gateway.createClassifiedJob(validateCreateJob({ requestId: form.get('requestId'), customer: form.get('customer'), phone: form.get('phone'), address: form.get('address') }), classification);
    id = job.id;
  } catch (error) {
    return { message: error instanceof AppError ? error.message : 'The save was not confirmed. Please retry.', uncertain: !(error instanceof AppError) || ['connection_failed', 'save_failed'].includes(error.code) };
  }
  revalidatePath('/jobs');
  return { message: 'Job saved.', jobId: id };
}

export async function updateJobAction(_previous: FormState, form: FormData): Promise<FormState> {
  let id: string;
  try {
    const env = appConfig();
    if (!env) return { message: 'The app connection is not configured yet.' };
    const client = await authClient(true);
    const { data } = await client.auth.getSession();
    if (!data.session) return { message: 'Your sign-in expired. Your changes are still on this screen.' };
    const gateway = new SupabaseSession(env, data.session.access_token);
    const actor = await gateway.getActor();
    const rawPatch = form.get('patch');
    let patch: unknown;
    try {
      if (typeof rawPatch !== 'string' || rawPatch.length > 16000) throw new Error('Invalid patch');
      patch = JSON.parse(rawPatch);
    } catch { throw new AppError('invalid_input', 400, 'Check the job details.'); }
    const job = await updateJob(actor, form.get('jobId'), patch, gateway);
    id = job.id;
  } catch (error) {
    return { message: error instanceof AppError ? error.message : 'The save was not confirmed. Your changes are still here.', uncertain: !(error instanceof AppError) || ['connection_failed', 'save_failed'].includes(error.code) };
  }
  revalidatePath('/jobs');
  revalidatePath('/jobs/' + id);
  return { message: 'Changes saved.', jobId: id };
}
