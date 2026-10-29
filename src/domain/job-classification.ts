import { AppError } from './access.ts';

export const trades = [
  { id: 'roofing', label: 'Roofing' }, { id: 'siding', label: 'Siding' },
  { id: 'windows_doors', label: 'Windows & doors' }, { id: 'framing', label: 'Framing' },
  { id: 'electrical', label: 'Electrical' }, { id: 'plumbing', label: 'Plumbing' },
  { id: 'hvac', label: 'Heating & cooling' }, { id: 'drywall', label: 'Drywall' },
  { id: 'painting', label: 'Painting' }, { id: 'flooring', label: 'Flooring' },
  { id: 'cabinetry', label: 'Cabinetry' }, { id: 'tile', label: 'Tile' },
  { id: 'concrete', label: 'Concrete' }, { id: 'landscaping', label: 'Landscaping' },
  { id: 'general', label: 'General repairs / punch list' }
] as const;
export type Trade = typeof trades[number]['id'];
export type JobClassification = { rain_day: boolean; filler: boolean; whole_house: boolean; trades: Trade[] };
export const emptyClassification: JobClassification = { rain_day: false, filler: false, whole_house: false, trades: [] };
export function validTrades(value: unknown): Trade[] {
  if (!Array.isArray(value) || value.length > trades.length || value.some(v => typeof v !== 'string' || !trades.some(t => t.id === v)) || new Set(value).size !== value.length) throw new AppError('invalid_input', 400, 'Choose each trade once from the list.');
  return [...value].sort() as Trade[];
}
export function classificationPatch(value: unknown): Partial<JobClassification> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new AppError('invalid_input', 400, 'Check the job tags.');
  const result: Partial<JobClassification> = {};
  for (const [key, v] of Object.entries(value)) {
    if (key === 'trades') result.trades = validTrades(v);
    else if (['rain_day', 'filler', 'whole_house'].includes(key) && typeof v === 'boolean') Object.assign(result, { [key]: v });
    else throw new AppError('invalid_input', 400, 'Check the job tags.');
  }
  return result;
}
export function classificationChanges(original: JobClassification, draft: JobClassification): Partial<JobClassification> {
  return Object.fromEntries(Object.keys(emptyClassification).filter(k => JSON.stringify(original[k as keyof JobClassification]) !== JSON.stringify(draft[k as keyof JobClassification])).map(k => [k, draft[k as keyof JobClassification]]));
}
export type Subcontractor = { id: string; name: string; phone: string; phone_action: string | null; email: string; trades: Trade[]; archived_at: string | null; contact_types?: ('vendor'|'subcontractor')[]; notes?:string };
export type SubcontractorValues = Pick<Subcontractor, 'name' | 'phone' | 'email' | 'trades' | 'contact_types' | 'notes'>;
export function subcontractorValues(value: unknown): SubcontractorValues {
  if (!value || typeof value !== 'object' || Array.isArray(value) || Object.keys(value).some(k => !['name','phone','email','trades','contact_types','notes'].includes(k))) throw new AppError('invalid_input',400,'Check the subcontractor details.');
  const v = value as Record<string, unknown>;
  for (const [key,max] of [['name',100],['phone',40],['email',254]] as const) if (typeof v[key] !== 'string' || (v[key] as string).length > max || /[\u0000-\u001f\u007f]/.test(v[key] as string)) throw new AppError('invalid_input',400,'Check the subcontractor details.');
  const name=(v.name as string).trim(), phone=(v.phone as string).trim(), email=(v.email as string).trim();
  if (!name || email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new AppError('invalid_input',400,'Enter a name and valid optional email.');
  if(v.contact_types!==undefined&&(!Array.isArray(v.contact_types)||!v.contact_types.length||v.contact_types.length>2||new Set(v.contact_types).size!==v.contact_types.length||v.contact_types.some(t=>!['vendor','subcontractor'].includes(t))))throw new AppError('invalid_input',400,'Choose Vendor and/or Subcontractor.');
  if(v.notes!==undefined&&(typeof v.notes!=='string'||v.notes.length>2000))throw new AppError('invalid_input',400,'Contact notes must be at most 2,000 characters.');
  return {name,phone,email,trades:validTrades(v.trades),...(v.contact_types!==undefined?{contact_types:v.contact_types as ('vendor'|'subcontractor')[]}:{}),...(v.notes!==undefined?{notes:v.notes as string}:{})};
}
