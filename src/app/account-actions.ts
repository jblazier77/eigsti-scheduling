'use server';

import { redirect } from 'next/navigation';
import { cookies } from 'next/headers';
import { authClient } from '../lib/supabase-server';
import { appConfig } from '../lib/config';
import { changeOwnPassword } from '../server/password-change.ts';
import { AppError } from '../domain/access.ts';

export type PasswordState = { message: string; uncertain?: boolean };

export async function changePasswordAction(_previous: PasswordState, form: FormData): Promise<PasswordState> {
  try {
    const config = appConfig();
    if (!config) return { message: 'The app connection is not configured yet.' };
    const client = await authClient(true);
    const { data } = await client.auth.getSession();
    if (!data.session) return { message: 'Your sign-in expired. Please sign in again.' };
    await changeOwnPassword(config, data.session.access_token, form.get('currentPassword'), form.get('newPassword'), form.get('confirmPassword'));
  } catch (error) {
    return { message: error instanceof AppError ? error.message : 'The password change was not confirmed. Sign out and check your new password before retrying.', uncertain: !(error instanceof AppError) || error.code === 'password_change_uncertain' };
  }
  // A successful password change ends this browser's session. Always remove its
  // cookies even if remote logout cannot be reached. Redirect outside the catch.
  try { const client = await authClient(true); await client.auth.signOut({ scope: 'local' }); } catch { /* Clear local cookies below. */ }
  const jar = await cookies();
  const name = `sb-${process.env.EIGSTI_EXPECTED_PROJECT_REF}-auth-token`;
  for (const cookie of jar.getAll()) if (cookie.name === name || cookie.name.startsWith(name + '.')) jar.delete(cookie.name);
  redirect('/login?reason=password-changed');
}
