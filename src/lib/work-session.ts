import 'server-only';
import { authClient } from './supabase-server';
import { appConfig } from './config';
import { WorkSession } from '../server/work.ts';
import { AppError, requirePm } from '../domain/access.ts';

export async function workSession(pmOnly = false) {
  const config = appConfig();
  if (!config) throw new AppError('schema_pending', 503, 'The app connection is not configured yet.');
  const client = await authClient();
  const { data } = await client.auth.getSession();
  if (!data.session) throw new AppError('sign_in_required', 401, 'Please sign in again. Your changes have not been saved.');
  const gateway = new WorkSession(config, data.session.access_token);
  const actor = await gateway.getActor();
  if (pmOnly) requirePm(actor);
  return { gateway, actor };
}
