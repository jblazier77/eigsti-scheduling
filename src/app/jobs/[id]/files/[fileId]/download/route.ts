import { authClient } from '../../../../../../lib/supabase-server';
import { appConfig } from '../../../../../../lib/config';
import { FileSession } from '../../../../../../server/files.ts';
import { AppError } from '../../../../../../domain/access.ts';
import { fileUuid } from '../../../../../../domain/files.ts';

export const dynamic = 'force-dynamic';
export async function GET(_request: Request, { params }: { params: Promise<{ id: string; fileId: string }> }) {
  const headers = { 'Cache-Control': 'private, no-store', 'Referrer-Policy': 'no-referrer', 'X-Content-Type-Options': 'nosniff' };
  try {
    const { id, fileId } = await params;
    fileUuid(id); fileUuid(fileId);
    const config = appConfig();
    if (!config) return new Response('File unavailable.', { status: 503, headers });
    const client = await authClient(true);
    const { data } = await client.auth.getSession();
    if (!data.session) return new Response('Please sign in to download this file.', { status: 401, headers });
    const gateway = new FileSession(config, data.session.access_token);
    await gateway.getActor();
    const file = await gateway.getFile(id, fileId);
    if (!file || file.status !== 'ready') return new Response('File unavailable.', { status: 404, headers });
    return new Response(null, { status: 303, headers: { ...headers, Location: await gateway.signDownload(file) } });
  } catch (error) {
    return new Response('File unavailable. Please sign in or try again.', { status: error instanceof AppError ? error.status : 503, headers });
  }
}
