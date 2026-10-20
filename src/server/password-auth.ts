import { AppError, type Actor } from '../domain/access.ts';
import { SupabaseSession, validateConfig, type SupabaseConfig } from './supabase.ts';

type SessionResult = { accessToken: string; refreshToken: string; expiresIn: number; actor: Actor };

// No password database or custom hashing. Supabase Auth performs credential checks.
// No public signup route. An active app_users entry is also required after login.
async function exchange(config: SupabaseConfig, grant: 'password' | 'refresh_token', body: object, transport: typeof fetch): Promise<SessionResult> {
  const origin = validateConfig(config);
  let response: Response;
  try {
    response = await transport(`${origin}/auth/v1/token?grant_type=${grant}`, {
      method: 'POST', headers: { apikey: config.publishableKey, 'Content-Type': 'application/json' },
      body: JSON.stringify(body), cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(15000)
    });
  } catch { throw new AppError('connection_failed', 503, 'Could not connect. Please try again.'); }
  if (response.status === 429) throw new AppError('try_later', 429, 'Too many attempts. Please try again later.');
  if (!response.ok) throw new AppError('sign_in_failed', response.status >= 500 ? 503 : 401, 'Could not sign in. Check your details or contact your administrator.');
  const session = await response.json();
  if (typeof session.access_token !== 'string' || !session.access_token || typeof session.refresh_token !== 'string' || !session.refresh_token || !Number.isFinite(session.expires_in) || session.expires_in <= 0) {
    throw new AppError('sign_in_failed', 503, 'Could not establish a session.');
  }
  // Profile is re-read live; stale role claims cannot re-enable a deactivated account.
  const actor = await new SupabaseSession(config, session.access_token, transport).getActor();
  return { accessToken: session.access_token, refreshToken: session.refresh_token, expiresIn: session.expires_in, actor };
}

export async function signInWithPassword(config: SupabaseConfig, email: string, password: string, transport: typeof fetch = fetch) {
  if (typeof email !== 'string' || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim()) || typeof password !== 'string' || password.length < 1 || password.length > 1024) {
    throw new AppError('invalid_input', 400, 'Enter your email address and password.');
  }
  return exchange(config, 'password', { email: email.trim().toLowerCase(), password }, transport);
}

export async function refreshSession(config: SupabaseConfig, refreshToken: string, transport: typeof fetch = fetch) {
  if (typeof refreshToken !== 'string' || !refreshToken || refreshToken.length > 4096) throw new AppError('sign_in_required', 401, 'Please sign in again.');
  return exchange(config, 'refresh_token', { refresh_token: refreshToken }, transport);
}
