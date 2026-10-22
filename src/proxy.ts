import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import { appConfig, secureSessionCookies } from './lib/config';

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });
  response.headers.set('Cache-Control', 'private, no-store');
  const env = appConfig();
  if (!env) return response;
  const client = createServerClient(env.url, env.publishableKey, {
    cookieOptions: { httpOnly: true, sameSite: 'lax', secure: secureSessionCookies(), path: '/' },
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll: updates => {
        for (const { name, value } of updates) request.cookies.set(name, value);
        response = NextResponse.next({ request });
        for (const { name, value, options } of updates) response.cookies.set(name, value, options);
        response.headers.set('Cache-Control', 'private, no-store');
      }
    }
  });
  // Refresh only; every page/action still verifies active app membership itself.
  await client.auth.getClaims();
  return response;
}

export const config = { matcher: ['/', '/login', '/account/:path*', '/queue/:path*', '/jobs/:path*'] };
