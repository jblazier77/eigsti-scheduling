import { createClient } from '@supabase/supabase-js';
import { AppError } from '../domain/access.ts';
import { SupabaseSession, validateConfig, type SupabaseConfig } from './supabase.ts';

export function validatePasswordChange(current: unknown, password: unknown, confirmation: unknown) {
  if (typeof current !== 'string' || !current || current.length > 1024) throw new AppError('invalid_input', 400, 'Enter your current password.');
  if (typeof password !== 'string' || password.length < 12 || new TextEncoder().encode(password).length > 72) throw new AppError('invalid_input', 400, 'Use at least 12 characters and at most 72 bytes for your new password.');
  if (password !== confirmation) throw new AppError('invalid_input', 400, 'The new passwords do not match.');
  if (password === current) throw new AppError('invalid_input', 400, 'Choose a password different from your current password.');
  return { current, password };
}

// An isolated, non-persistent session proves the current password even when the
// project's optional current-password setting is disabled. No email/actor input
// is accepted from the form, and no temporary tokens are returned to the caller.
export async function changeOwnPassword(config: SupabaseConfig, token: string, current: unknown, password: unknown, confirmation: unknown, transport: typeof fetch = fetch) {
  const input = validatePasswordChange(current, password, confirmation);
  validateConfig(config);
  const actor = await new SupabaseSession(config, token, transport).getActor();
  const client = createClient(config.url, config.publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    global: { fetch: (url, init) => transport(url, { ...init, cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(15000) }) }
  });
  let temporarySession = false;
  try {
    const identity = await client.auth.getUser(token);
    if (identity.error || identity.data.user?.id !== actor.id || !identity.data.user.email) throw new AppError('sign_in_required', 401, 'Please sign in again before changing your password.');
    const verified = await client.auth.signInWithPassword({ email: identity.data.user.email, password: input.current });
    temporarySession = !!verified.data.session;
    if (verified.error || !verified.data.session) throw new AppError('password_check_failed', 401, verified.error?.status === 429 ? 'Too many attempts. Please try again later.' : 'Could not verify your current password. Check it and try again.');
    if (verified.data.user?.id !== actor.id) throw new AppError('sign_in_required', 401, 'Please sign in again before changing your password.');
    // Re-read live membership after reauthentication; cookie roles are not used.
    await new SupabaseSession(config, verified.data.session.access_token, transport).getActor();
    const changed = await client.auth.updateUser({ password: input.password, current_password: input.current });
    if (changed.error) {
      if (changed.error.status === 429) throw new AppError('try_later', 429, 'Too many attempts. Please try again later.');
      if (changed.error.code === 'weak_password') throw new AppError('invalid_input', 400, 'Choose a stronger password that meets your company account requirements.');
      if (changed.error.code === 'same_password') throw new AppError('invalid_input', 400, 'Choose a password different from your current password.');
      if (!changed.error.status || changed.error.status >= 500) throw new AppError('password_change_uncertain', 503, 'The password change was not confirmed. Sign out and try signing in with the new password before retrying.');
      throw new AppError('password_change_failed', 400, 'Could not change your password. Sign in again and retry, or contact your administrator.');
    }
    if (changed.data.user?.id !== actor.id) throw new AppError('password_change_uncertain', 503, 'The password change was not confirmed. Sign out and check your new password.');
  } finally {
    // Best effort remote cleanup; this client never writes browser cookies.
    if (temporarySession) { try { await client.auth.signOut({ scope: 'local' }); } catch { /* Do not mask the password result. */ } }
  }
}
