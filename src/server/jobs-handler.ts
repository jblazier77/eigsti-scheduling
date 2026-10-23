import { AppError } from '../domain/access.ts';
import { createJob, listJobs } from '../domain/jobs.ts';
import { SupabaseSession, type SupabaseConfig } from './supabase.ts';

const responseHeaders = { 'Cache-Control': 'no-store', 'Content-Type': 'application/json; charset=utf-8', 'X-Content-Type-Options': 'nosniff' };

// Framework-neutral Request/Response adapter for the future Next.js route.
// Bearer token only; no cookies or permissive CORS, and no synthetic-user bypass.
export function jobsHandler(config: SupabaseConfig, transport: typeof fetch = fetch) {
  return async (request: Request): Promise<Response> => {
    try {
      if (!['GET', 'POST'].includes(request.method)) return new Response(JSON.stringify({ code: 'method_not_allowed' }), { status: 405, headers: { ...responseHeaders, Allow: 'GET, POST' } });
      const auth = request.headers.get('Authorization')?.match(/^Bearer (\S+)$/i);
      if (!auth) throw new AppError('sign_in_required', 401, 'Please sign in.');
      const session = new SupabaseSession(config, auth[1], transport);
      const actor = await session.getActor();
      let result;
      if (request.method === 'POST') {
        if (!(request.headers.get('Content-Type') ?? '').toLowerCase().startsWith('application/json')) throw new AppError('invalid_input', 415, 'Use a JSON request.');
        // Bound streaming input; Content-Length alone is untrusted.
        if (!request.body) throw new AppError('invalid_input', 400, 'Enter the job details.');
        const reader = request.body.getReader();
        let size = 0;
        let body = '';
        const decoder = new TextDecoder();
        try {
          while (true) {
            const next = await reader.read();
            if (next.done) break;
            size += next.value.byteLength;
            if (size > 8192) { await reader.cancel(); throw new AppError('invalid_input', 413, 'Job details are too long.'); }
            body += decoder.decode(next.value, { stream: true });
          }
          body += decoder.decode();
        } finally { reader.releaseLock(); }
        let input: unknown;
        try { input = JSON.parse(body); } catch { throw new AppError('invalid_input', 400, 'Check the job details.'); }
        result = await createJob(actor, input, session);
      } else {
        const url = new URL(request.url);
        result = await listJobs(actor, { scope: url.searchParams.get('scope') ?? undefined, offset: url.searchParams.get('offset') ?? undefined,state:url.searchParams.get('state')??undefined }, session);
      }
      return new Response(JSON.stringify(result), { status: 200, headers: responseHeaders });
    } catch (error) {
      const known = error instanceof AppError;
      return new Response(JSON.stringify({ code: known ? error.code : 'unexpected_error', message: known ? error.message : 'The action could not be completed.' }), { status: known ? error.status : 500, headers: responseHeaders });
    }
  };
}
