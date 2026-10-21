import 'server-only';
import { cache } from 'react';
import { redirect } from 'next/navigation';
import { authClient } from './supabase-server';
import { appConfig } from './config';
import { SupabaseSession } from '../server/supabase.ts';
import { AppError } from '../domain/access.ts';

export const currentSession = cache(async () => {
  const config = appConfig();
  if (!config) return null;
  const client = await authClient();
  const { data, error } = await client.auth.getSession();
  if (error || !data.session) return null;
  // The cookie supplies only the token to send. Identity/roles are never trusted
  // from getSession(): gateway.getActor verifies it with Auth and live RLS profile.
  const gateway = new SupabaseSession(config, data.session.access_token);
  const actor = await gateway.getActor();
  return { actor, gateway };
});

export async function requireSession() {
  let session;
  try { session = await currentSession(); }
  catch (error) {
    if (error instanceof AppError && ['sign_in_required', 'access_disabled'].includes(error.code)) redirect('/login?reason=access');
    throw error;
  }
  if (!session) redirect('/login');
  return session;
}
