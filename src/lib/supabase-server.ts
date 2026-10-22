import 'server-only';
import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { appConfig, secureSessionCookies } from './config';
import { AppError } from '../domain/access.ts';

export async function authClient(writable = false, signal?: AbortSignal) {
  const config = appConfig();
  if (!config) throw new AppError('setup_required', 503, 'The app connection has not been configured.');
  const jar = await cookies();
  return createServerClient(config.url, config.publishableKey, {
    ...(signal ? { global: { fetch: (input: RequestInfo | URL, init?: RequestInit) => fetch(input, { ...init, signal: init?.signal ? AbortSignal.any([signal, init.signal]) : signal }) } } : {}),
    cookieOptions: { httpOnly: true, sameSite: 'lax', secure: secureSessionCookies(), path: '/' },
    cookies: {
      getAll: () => jar.getAll(),
      setAll: updates => {
        if (writable) {
          for (const { name, value, options } of updates) jar.set(name, value, options);
        }
        // Page renders cannot set cookies; proxy refreshes and writes them first.
      }
    }
  });
}
