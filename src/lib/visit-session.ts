import 'server-only';
import { authClient } from './supabase-server';
import { appConfig } from './config';
import { VisitSession } from '../server/visits.ts';
import { AppError } from '../domain/access.ts';
export async function visitSession() {
  const config = appConfig();
  if (!config) throw new AppError('schema_pending', 503, 'The app connection is not configured yet.');
  const client = await authClient(); const { data } = await client.auth.getSession();
  if (!data.session) throw new AppError('sign_in_required', 401, 'Please sign in again. Your visit changes have not been confirmed saved.');
  const gateway = new VisitSession(config, data.session.access_token);
  return { gateway, actor: await gateway.getActor() };
}
