import type { SupabaseConfig } from '../server/supabase.ts';
import { validateConfig } from '../server/supabase.ts';

export function appConfig(): SupabaseConfig | null {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return null;
  const environment = process.env.EIGSTI_ENVIRONMENT;
  if (!['test', 'development', 'production'].includes(environment ?? '')) throw new Error('Set the application environment explicitly.');
  const expected = process.env.EIGSTI_EXPECTED_PROJECT_REF;
  if (!expected || !/^[a-z]{20}$/.test(expected)) throw new Error('Set the expected Supabase project reference.');
  const config = { url, publishableKey: key, environment } as SupabaseConfig;
  const origin = validateConfig(config);
  if (new URL(origin).hostname !== `${expected}.supabase.co`) throw new Error('Supabase project does not match the expected environment.');
  return config;
}

export function secureSessionCookies() {
  return process.env.NODE_ENV === 'production' || process.env.EIGSTI_ENVIRONMENT === 'production';
}
