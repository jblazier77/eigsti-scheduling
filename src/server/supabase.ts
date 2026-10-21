import { AppError, type Actor, type AccountRole } from '../domain/access.ts';
import type { JobsGateway, JobSummary, ValidJobInput } from '../domain/jobs.ts';
import type { JobPatch } from '../domain/job-edits.ts';

export type SupabaseConfig = { url: string; publishableKey: string; environment: 'development' | 'test' | 'production' };
export type JobDetail = JobSummary & { scope: string; access_notes: string };
type Transport = typeof fetch;

export function validateConfig(config: SupabaseConfig) {
  const url = new URL(config.url);
  if (url.username || url.password || url.search || url.hash || (url.pathname !== '/' && url.pathname !== '')) throw new Error('Use a Supabase project origin.');
  const local = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
  if (url.protocol !== 'https:' && !(local && config.environment !== 'production' && url.protocol === 'http:')) throw new Error('HTTPS is required.');
  if (!config.publishableKey || config.publishableKey.startsWith('sb_secret_')) throw new Error('A public project key is required, not an administrative secret.');
  // Legacy service-role JWTs must never be used for employee data requests.
  if (config.publishableKey.split('.').length === 3) {
    try {
      const claims = JSON.parse(Buffer.from(config.publishableKey.split('.')[1], 'base64url').toString());
      if (claims.role !== 'anon') throw new Error('Use an anon project key.');
    } catch { throw new Error('Invalid public project key.'); }
  }
  return url.origin;
}

export class SupabaseSession implements JobsGateway {
  private origin: string;
  private headers: Record<string, string>;
  private transport: Transport;
  constructor(config: SupabaseConfig, token: string, transport: Transport = fetch) {
    this.transport = transport;
    this.origin = validateConfig(config);
    if (!token || /[\r\n]/.test(token)) throw new AppError('sign_in_required', 401, 'Please sign in.');
    this.headers = { apikey: config.publishableKey, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
  }

  private async request(path: string, options: RequestInit = {}) {
    let response: Response;
    try { response = await this.transport(this.origin + path, { ...options, headers: this.headers, cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(15000) }); }
    catch { throw new AppError('connection_failed', 503, 'Could not connect. Your changes have not been confirmed saved.'); }
    if (!response.ok) {
      if (response.status === 401) throw new AppError('sign_in_required', 401, 'Please sign in again.');
      if (response.status === 403) throw new AppError('not_allowed', 403, 'You do not have access to this action.');
      const detail = await response.json().catch(() => null);
      const code = detail?.code;
      if (code === '42501') throw new AppError('not_allowed', 403, 'You do not have access to this action.');
      if (code === '22023') throw new AppError('invalid_input', 400, 'Check the job details.');
      if (code === '23505') throw new AppError('request_conflict', 409, 'This request was already used with different details.');
      if (code === 'P0002') throw new AppError('job_unavailable', 404, 'This job is unavailable.');
      throw new AppError('save_failed', 503, 'The action was not confirmed. Retry using the same request.');
    }
    if (response.status === 204) return null;
    return response.json();
  }

  async getActor(): Promise<Actor> {
    // Auth service verifies the token; never trust a client-supplied role or decoded JWT alone.
    const auth = await this.request('/auth/v1/user');
    if (!auth?.id || typeof auth.id !== 'string' || !/^[a-f0-9-]{36}$/i.test(auth.id)) throw new AppError('sign_in_required', 401, 'Please sign in again.');
    const profiles = await this.request('/rest/v1/app_users?select=id,active,roles&id=eq.' + encodeURIComponent(auth.id));
    const profile = profiles?.[0];
    if (!profile || !profile.active || profile.id !== auth.id) throw new AppError('access_disabled', 403, 'Your account is not active.');
    const roles: AccountRole[] = Array.isArray(profile.roles) ? profile.roles.filter((r: string) => ['admin', 'pm', 'lead', 'helper'].includes(r)) : [];
    return { id: auth.id, active: true, roles };
  }

  async createJob(input: ValidJobInput): Promise<JobSummary> {
    return this.request('/rest/v1/rpc/create_job', { method: 'POST', body: JSON.stringify({ p_request_id: input.requestId, p_customer: input.customer, p_phone: input.phone, p_address: input.address }) });
  }

  async listJobs(query: { responsiblePm?: string; limit: number; offset: number }): Promise<JobSummary[]> {
    const params = new URLSearchParams({ select: 'id,customer_name,phone,phone_action,address,title,responsible_pm,lifecycle', order: 'created_at.desc,id.desc', limit: String(query.limit), offset: String(query.offset), lifecycle: 'neq.archived' });
    if (query.responsiblePm) params.set('responsible_pm', 'eq.' + query.responsiblePm);
    return this.request('/rest/v1/jobs?' + params);
  }

  async getJob(id: string): Promise<JobDetail | null> {
    const params = new URLSearchParams({ select: 'id,customer_name,phone,phone_action,address,title,scope,access_notes,responsible_pm,lifecycle', id: 'eq.' + id, limit: '1' });
    const rows = await this.request('/rest/v1/jobs?' + params);
    return rows[0] ?? null;
  }

  async updateJob(id: string, patch: JobPatch): Promise<JobDetail> {
    return this.request('/rest/v1/rpc/update_job', { method: 'POST', body: JSON.stringify({ p_job_id: id, p_patch: patch }) });
  }
}
