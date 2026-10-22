import { notFound, redirect } from 'next/navigation';
import { requireSession } from '../../../lib/session';
import { visitSession } from '../../../lib/visit-session';
import { uuidPattern } from '../../../domain/jobs.ts';
import { AppError } from '../../../domain/access.ts';
export const dynamic = 'force-dynamic';
// Existing visit links open the same inline job card instead of another editing screen.
export default async function VisitPage({ params }: { params: Promise<{ id: string }> }) {
  await requireSession(); const { id } = await params;
  if (!uuidPattern.test(id)) notFound();
  const { gateway } = await visitSession();
  let visit;
  try { visit = await gateway.getVisit(id); }
  catch (error) { if (error instanceof AppError && ['not_allowed', 'job_unavailable'].includes(error.code)) redirect('/jobs'); throw error; }
  if (!visit) notFound();
  redirect('/jobs/' + visit.job_id + '#visit-' + visit.id);
}