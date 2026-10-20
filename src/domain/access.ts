export type AccountRole = 'admin' | 'pm' | 'lead' | 'helper';
export type Actor = { id: string; active: boolean; roles: AccountRole[] };
export type JobAccess = { responsiblePm: string | null; leadIds: string[]; helperIds: string[]; lifecycle: 'open' | 'closed' | 'archived' };

export class AppError extends Error {
  code: string;
  status: number;
  constructor(code: string, status: number, message: string) { super(message); this.code = code; this.status = status; }
}

export function requireActive(actor: Actor | null): asserts actor is Actor {
  if (!actor) throw new AppError('sign_in_required', 401, 'Please sign in.');
  if (!actor.active) throw new AppError('access_disabled', 403, 'Your account is not active.');
}

export function hasRole(actor: Actor | null, role: AccountRole): boolean {
  return !!actor?.active && actor.roles.includes(role);
}

export function requirePm(actor: Actor | null): asserts actor is Actor {
  requireActive(actor);
  if (!hasRole(actor, 'pm')) throw new AppError('not_allowed', 403, 'A project manager account is required.');
}

export function canReadJob(actor: Actor | null, access: JobAccess): boolean {
  if (!actor?.active) return false;
  return hasRole(actor, 'pm') ||
    (hasRole(actor, 'lead') && access.leadIds.includes(actor.id)) ||
    (access.lifecycle === 'open' && (hasRole(actor, 'helper') || hasRole(actor, 'lead')) && access.helperIds.includes(actor.id));
}

export function requireJobWrite(actor: Actor | null): asserts actor is Actor { requirePm(actor); }
