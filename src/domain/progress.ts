import { AppError } from './access.ts';
import { requirePlanner, validDate, visitId, type Visit } from './visits.ts';
import type { Actor } from './access.ts';
export type ProgressCommand = 'finish_visit' | 'complete_work' | 'record_return' | 'resolve_return' | 'reopen_work' | 'plan_return';
export type ReturnWork = { id: string; source_visit_id: string | null; owner_name: string; note: string; due_date: string | null; state: 'open' | 'done'; planned_count: number };
export type WorkProgress = { id: string; job_id: string; description: string; responsible_lead: string | null; lead_name: string | null; completion: 'open' | 'completed'; remaining_note: string; planned_count: number; returns: ReturnWork[] };
export type ProgressInput = { workId: string; visitId: string | null; followUpId: string | null; requestId: string; command: ProgressCommand; values: Record<string, unknown> };
export type ProgressResult = { job_id: string; work_id: string; result_id: string; visit: Visit | null };
export function progressInput(actor: Actor, form: FormData): ProgressInput {
  requirePlanner(actor);
  const command = form.get('command');
  if (!['finish_visit','complete_work','record_return','resolve_return','reopen_work'].includes(String(command))) throw new AppError('invalid_input',400,'Choose a work action.');
  const input: ProgressInput = { workId:visitId(form.get('workId')),visitId:form.get('visitId')?visitId(form.get('visitId')):null,followUpId:form.get('followUpId')?visitId(form.get('followUpId')):null,requestId:visitId(form.get('requestId')),command:command as ProgressCommand,values:{} };
  if (command==='finish_visit' || command==='record_return') {
    const raw = form.get('note');
    if (typeof raw!=='string' || raw.length>2000 || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(raw)) throw new AppError('invalid_input',400,'Use a remaining-work note up to 2,000 characters.');
    const note=raw.trim();
    const needsReturn=command==='record_return' || form.get('needsReturn')==='yes';
    if (needsReturn && !note) throw new AppError('invalid_input',400,'Briefly describe what needs a return trip.');
    const due=form.get('dueDate');
    if (due && !validDate(due)) throw new AppError('invalid_input',400,'Check the optional follow-up date.');
    input.values={note,due_date:due||null,...(command==='finish_visit'?{needs_return:needsReturn}:{reopen:form.get('reopen')==='yes'})};
  }
  return input;
}
