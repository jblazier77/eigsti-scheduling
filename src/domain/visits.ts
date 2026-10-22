import { AppError, requireActive, type Actor } from './access.ts';
import { uuidPattern } from './jobs.ts';

export type VisitSlot = 'day' | 'all_day' | 'morning' | 'afternoon' | 'timed';
export type VisitValues = { start_date: string; end_date: string; slot: VisitSlot; start_time: string | null; end_time: string | null; coordinator_id: string; required_helpers: number; certainty: 'tentative' | 'confirmed' };
export type Visit = VisitValues & { id: string; work_item_id: string; job_id: string; job_title: string; description: string; state: 'planned' | 'completed' | 'cancelled'; updated_at: string; day_conflicts: number; participants: { id: string; name: string; duty: 'leading' | 'helping' }[] };
export type StaffOption = { id: string; name: string; busy: boolean };
export function visitId(value: unknown): string {
  if (typeof value !== 'string' || !uuidPattern.test(value)) throw new AppError('invalid_input', 400, 'Check the visit or person selected.');
  return value.toLowerCase();
}
export function requirePlanner(actor: Actor | null): asserts actor is Actor {
  requireActive(actor);
  if (!actor.roles.some(role => role === 'pm' || role === 'lead')) throw new AppError('not_allowed', 403, 'A project manager or coordinating lead is required.');
}
export function validDate(value: unknown): value is string {
  if (typeof value !== 'string' || !/^20\d{2}-\d{2}-\d{2}$/.test(value)) return false;
  const d = new Date(value + 'T12:00:00Z');
  return Number.isFinite(d.getTime()) && d.toISOString().slice(0, 10) === value;
}
// Date arithmetic only: UTC noon is a neutral calculation anchor, never the displayed instant.
export function addDays(date: string, count: number): string {
  const value = new Date(date + 'T12:00:00Z'); value.setUTCDate(value.getUTCDate() + count); return value.toISOString().slice(0, 10);
}
export function companyToday(now = new Date()): string {
  const parts = new Intl.DateTimeFormat('en-US', { timeZone: 'America/Chicago', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(now);
  return ['year', 'month', 'day'].map(type => parts.find(part => part.type === type)!.value).join('-');
}
export function monday(date: string): string { return addDays(date, -((new Date(date + 'T12:00:00Z').getUTCDay() + 6) % 7)); }
export function dateLabel(date: string): string { return new Intl.DateTimeFormat('en-US', { timeZone: 'UTC', weekday: 'short', month: 'short', day: 'numeric' }).format(new Date(date + 'T12:00:00Z')); }
export function visitOnDay(visit: Visit, date: string): boolean {
  const day = new Date(date + 'T12:00:00Z').getUTCDay();
  return day !== 0 && day !== 6 && date >= visit.start_date && date <= visit.end_date;
}
export function slotLabel(visit: Pick<VisitValues, 'slot' | 'start_time' | 'end_time'>): string {
  return visit.slot === 'timed' ? `${visit.start_time?.slice(0, 5)}–${visit.end_time?.slice(0, 5)}` : { day: 'No time set', all_day: 'All day · 7:00–3:30', morning: 'Morning · 7:00–noon', afternoon: 'Afternoon · noon–3:30' }[visit.slot];
}
export function validateVisit(raw: Record<string, unknown>): VisitValues {
  const fail = () => { throw new AppError('invalid_input', 400, 'Use weekday dates up to 31 calendar days apart and times within 7:00 AM–3:30 PM.'); };
  if (!validDate(raw.start_date) || !validDate(raw.end_date)) return fail();
  const start = raw.start_date, end = raw.end_date;
  const weekdays = [start, end].every(d => { const day = new Date(d + 'T12:00:00Z').getUTCDay(); return day > 0 && day < 6; });
  if (!weekdays || end < start || end > addDays(start, 30) || !['day', 'all_day', 'morning', 'afternoon', 'timed'].includes(String(raw.slot))) return fail();
  const slot = raw.slot as VisitSlot;
  let startTime: string | null = null, endTime: string | null = null;
  if (slot === 'timed') {
    if (start !== end || typeof raw.start_time !== 'string' || typeof raw.end_time !== 'string' || !/^\d{2}:\d{2}$/.test(raw.start_time) || !/^\d{2}:\d{2}$/.test(raw.end_time)) return fail();
    startTime = raw.start_time; endTime = raw.end_time;
    if ([startTime, endTime].some(t => Number(t.slice(3)) > 59) || startTime < '07:00' || endTime > '15:30' || endTime <= startTime) return fail();
  }
  const count = raw.required_helpers;
  if (typeof count !== 'string' || !/^\d{1,2}$/.test(count) || Number(count) > 20 || !['tentative', 'confirmed'].includes(String(raw.certainty))) return fail();
  return { start_date: start, end_date: end, slot, start_time: startTime, end_time: endTime, coordinator_id: visitId(raw.coordinator_id), required_helpers: Number(count), certainty: raw.certainty as VisitValues['certainty'] };
}
export function visitPatch(before: VisitValues, after: VisitValues): Partial<VisitValues> {
  return Object.fromEntries(Object.entries(after).filter(([key, value]) => before[key as keyof VisitValues] !== value && !(key.endsWith('_time') && before[key as keyof VisitValues]?.toString().slice(0, 5) === value)));
}
export function valuesFromVisit(visit: VisitValues): VisitValues {
  return { start_date: visit.start_date, end_date: visit.end_date, slot: visit.slot, start_time: visit.start_time?.slice(0,5) ?? null, end_time: visit.end_time?.slice(0,5) ?? null, coordinator_id: visit.coordinator_id, required_helpers: visit.required_helpers, certainty: visit.certainty };
}
export function selectedHelpers(visit: Visit): string[] { return visit.participants.filter(p => p.duty === 'helping').map(p => p.id).sort(); }
export function chooseVisitHelper(values: VisitValues, helpers: string[], id: string, checked: boolean) {
  const next = (checked ? [...new Set([...helpers,visitId(id)])] : helpers.filter(x => x!==id)).sort();
  if (next.length>20) throw new AppError('invalid_input',400,'A visit supports up to 20 helpers.');
  return { helpers: next, values: { ...values, required_helpers: Math.max(values.required_helpers,next.length) } };
}
export function visitCardChange(before: Visit, after: VisitValues, helpers: string[]) {
  const normalized = helpers.map(visitId).sort();
  if (normalized.length > 20 || new Set(normalized).size !== normalized.length) throw new AppError('invalid_input',400,'Check the selected helpers.');
  return { patch: visitPatch(valuesFromVisit(before),after), helpers: JSON.stringify(selectedHelpers(before)) === JSON.stringify(normalized) ? null : normalized };
}
