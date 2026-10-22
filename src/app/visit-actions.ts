'use server';
import { revalidatePath } from 'next/cache';
import { visitSession } from '../lib/visit-session';
import { requirePlanner, validateVisit, visitId, type Visit, type VisitValues } from '../domain/visits.ts';
import { AppError } from '../domain/access.ts';
export type VisitState = { message: string; uncertain?: boolean; visit?: Visit };
export async function saveVisitAction(_previous: VisitState, form: FormData): Promise<VisitState> {
  let visit: Visit;
  try {
    const { actor, gateway } = await visitSession(); requirePlanner(actor);
    const work = visitId(form.get('workId')), request = visitId(form.get('requestId'));
    const id = form.get('visitId') ? visitId(form.get('visitId')) : null;
    const operation = form.get('operation');
    if (operation === 'card') {
      if (!id) throw new AppError('invalid_input', 400, 'Choose a saved visit.');
      const values = validateVisit(Object.fromEntries(form.entries()));
      const rawFields = form.get('fields');
      if (typeof rawFields !== 'string' || rawFields.length > 300) throw new AppError('invalid_input', 400, 'Check the visit changes.');
      const fields: unknown = JSON.parse(rawFields);
      if (!Array.isArray(fields) || fields.some(key => typeof key !== 'string' || !Object.hasOwn(values,key))) throw new AppError('invalid_input',400,'Check the visit changes.');
      const mode = form.get('helpersMode');
      if (mode !== 'changed' && mode !== 'unchanged') throw new AppError('invalid_input',400,'Check the selected helpers.');
      const helpers = mode === 'changed' ? form.getAll('helper').map(visitId).sort() : null;
      if (helpers && (helpers.length>20 || new Set(helpers).size!==helpers.length)) throw new AppError('invalid_input',400,'Check the selected helpers.');
      if (!fields.length && helpers === null) throw new AppError('invalid_input',400,'No visit changes to save.');
      visit = await gateway.saveVisitCard(work,id,request,Object.fromEntries(fields.map(key => [key,values[key as keyof VisitValues]])),helpers);
    } else if (operation === 'staff') {
      if (!id) throw new AppError('invalid_input', 400, 'Choose a saved visit.');
      const helpers = form.getAll('helper').map(visitId);
      if (helpers.length > 20 || new Set(helpers).size !== helpers.length) throw new AppError('invalid_input', 400, 'Check the selected helpers.');
      visit = await gateway.staffVisit(id, request, helpers);
    } else if (operation === 'cancel') {
      if (!id) throw new AppError('invalid_input', 400, 'Choose a saved visit.');
      visit = await gateway.saveVisit(work, id, request, { state: 'cancelled' });
    } else if (operation === 'save') {
      const values = validateVisit(Object.fromEntries(form.entries()));
      let patch: Partial<VisitValues> = values;
      if (id) {
        // Only changed fields are submitted. The baseline is untrusted and selects fields only;
        // all values/permissions/relationships are enforced again by the SQL command.
        const raw = form.get('fields');
        if (typeof raw !== 'string' || raw.length > 300) throw new AppError('invalid_input', 400, 'Reload the visit.');
        const fields: unknown = JSON.parse(raw);
        if (!Array.isArray(fields) || !fields.length || fields.some(key => typeof key !== 'string' || !Object.hasOwn(values, key))) throw new AppError('invalid_input', 400, 'No visit changes to save.');
        patch = Object.fromEntries(fields.map(key => [key, values[key as keyof VisitValues]]));
      }
      visit = await gateway.saveVisit(work, id, request, patch);
    } else throw new AppError('invalid_input', 400, 'Choose a visit action.');
  } catch (error) {
    return { message: error instanceof AppError ? error.message : 'The save was not confirmed. Keep this form and retry.', uncertain: !(error instanceof AppError) || ['connection_failed', 'save_failed'].includes(error.code) };
  }
  revalidatePath('/schedule'); revalidatePath('/jobs/' + visit.job_id);
  return { message: 'Visit saved.', visit };
}
