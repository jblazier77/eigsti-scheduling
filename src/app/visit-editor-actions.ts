'use server';
import { randomUUID } from 'node:crypto';
import { visitSession } from '../lib/visit-session';
import { requirePlanner, visitId, type Visit, type StaffOption } from '../domain/visits.ts';
import { AppError } from '../domain/access.ts';
import type { LeadOption } from '../domain/work.ts';
export type VisitEditorData = { visit: Visit; options: StaffOption[]; leads: LeadOption[]; actorId: string; pm: boolean; requests: { dates: string; staff: string; cancel: string } };
export type VisitEditorLoad = { data?: VisitEditorData; message?: string };
export async function loadVisitEditorAction(id: string): Promise<VisitEditorLoad> {
  try {
    const { actor, gateway } = await visitSession(); requirePlanner(actor);
    const visit = await gateway.getVisit(visitId(id));
    const pm = actor.roles.includes('pm');
    if (!pm && visit.coordinator_id !== actor.id) throw new AppError('not_allowed', 403, 'Only a project manager or this visit’s coordinating lead can edit it.');
    if (visit.state !== 'planned') throw new AppError('invalid_input', 400, 'This visit is no longer planned. Refresh to see its current state.');
    const [options, leads] = await Promise.all([gateway.staffOptions(visit.id), pm ? gateway.listLeads() : Promise.resolve([])]);
    return { data: { visit, options, leads, actorId: actor.id, pm, requests: { dates: randomUUID(), staff: randomUUID(), cancel: randomUUID() } } };
  } catch (error) { return { message: error instanceof AppError ? error.message : 'Could not load the visit. Try again.' }; }
}
