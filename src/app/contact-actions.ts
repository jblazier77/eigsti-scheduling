'use server';

import { revalidatePath } from 'next/cache';
import { redirect, RedirectType } from 'next/navigation';
import { authClient } from '../lib/supabase-server';
import { appConfig } from '../lib/config';
import { SupabaseSession } from '../server/supabase.ts';
import { AppError, requirePm } from '../domain/access.ts';
import { archiveContact, contactUuid, createContact, updateContact } from '../domain/contacts.ts';
import type { FormState } from './actions';

async function contactSession() {
  const env = appConfig();
  if (!env) throw new AppError('schema_pending', 503, 'The app connection is not configured yet.');
  const client = await authClient(true);
  const { data } = await client.auth.getSession();
  if (!data.session) throw new AppError('sign_in_required', 401, 'Your sign-in expired. Your contact details are still on this screen.');
  const gateway = new SupabaseSession(env, data.session.access_token);
  const actor = await gateway.getActor();
  requirePm(actor);
  return { gateway, actor };
}

function contactPayload(form: FormData): unknown {
  const raw = form.get('values');
  try {
    if (typeof raw !== 'string' || raw.length > 10000) throw new Error('Invalid values');
    return JSON.parse(raw);
  } catch { throw new AppError('invalid_input', 400, 'Check the contact details.'); }
}

function contactFailure(error: unknown): FormState {
  return {
    message: error instanceof AppError ? error.message : 'The save was not confirmed. Your contact details are still here.',
    uncertain: !(error instanceof AppError) || ['connection_failed', 'save_failed'].includes(error.code)
  };
}

function refreshContactPages(jobId: string) {
  revalidatePath('/jobs/' + jobId);
  revalidatePath('/jobs/' + jobId + '/contacts');
}

export async function createContactAction(_previous: FormState, form: FormData): Promise<FormState> {
  let jobId: string;
  try {
    const { gateway, actor } = await contactSession();
    jobId = contactUuid(form.get('jobId'));
    await createContact(actor, jobId, form.get('requestId'), contactPayload(form), gateway);
  } catch (error) { return contactFailure(error); }
  refreshContactPages(jobId);
  return { message: 'Contact added.', jobId };
}

export async function updateContactAction(_previous: FormState, form: FormData): Promise<FormState> {
  let jobId: string;
  try {
    const { gateway, actor } = await contactSession();
    jobId = contactUuid(form.get('jobId'));
    await updateContact(actor, jobId, form.get('contactId'), contactPayload(form), gateway);
  } catch (error) { return contactFailure(error); }
  refreshContactPages(jobId);
  return { message: 'Contact saved.', jobId };
}

export async function archiveContactAction(_previous: FormState, form: FormData): Promise<FormState> {
  let jobId: string;
  try {
    const { gateway, actor } = await contactSession();
    jobId = contactUuid(form.get('jobId'));
    await archiveContact(actor, jobId, form.get('contactId'), gateway);
  } catch (error) { return contactFailure(error); }
  refreshContactPages(jobId);
  // End this action with navigation: re-rendering the archived edit resource
  // before a client effect runs would produce notFound instead of returning to the job.
  redirect('/jobs/' + jobId, RedirectType.replace);
}
