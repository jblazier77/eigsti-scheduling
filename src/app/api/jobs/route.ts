import { jobsHandler } from '../../../server/jobs-handler.ts';
import { appConfig } from '../../../lib/config';

export const dynamic = 'force-dynamic';
async function handle(request: Request) {
  const config = appConfig();
  if (!config) return Response.json({ code: 'setup_required', message: 'The app connection is not configured.' }, { status: 503, headers: { 'Cache-Control': 'no-store' } });
  return jobsHandler(config)(request);
}
export const GET = handle;
export const POST = handle;
