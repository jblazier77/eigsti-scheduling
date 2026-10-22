import 'server-only';
import { authClient } from './supabase-server';
import { appConfig } from './config';
import { QueueSession } from '../server/queues.ts';
import { AppError } from '../domain/access.ts';

export async function queueSession() {
  const config = appConfig();
  if (!config) throw new AppError('schema_pending', 503, 'The app connection is not configured yet.');
  const client = await authClient();
  const { data } = await client.auth.getSession();
  if (!data.session) throw new AppError('sign_in_required', 401, 'Please sign in again. Your queue order has not been saved.');
  const gateway = new QueueSession(config, data.session.access_token);
  const actor = await gateway.getActor();
  return { gateway, actor };
}
