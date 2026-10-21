import { notFound, redirect } from 'next/navigation';
import { requireSession } from '../../../../../../lib/session';
import { uuidPattern } from '../../../../../../domain/jobs.ts';
import { Shell } from '../../../../../components/shell';
import { ContactForm } from '../../../../../components/contact-form';

export const dynamic = 'force-dynamic';
export default async function EditContact({ params }: { params: Promise<{ id: string; contactId: string }> }) {
  const { actor, gateway } = await requireSession();
  if (!actor.roles.includes('pm')) redirect('/jobs');
  const { id, contactId } = await params;
  if (!uuidPattern.test(id) || !uuidPattern.test(contactId)) notFound();
  const contact = await gateway.getContact(id, contactId);
  if (!contact) notFound();
  const { name, relationship, phone, email, notes } = contact;
  return <Shell title="Edit job contact"><div className="form-intro"><h2>Contact details</h2><p>Changes apply to this job's contact.</p></div><div className="card form-card"><ContactForm jobId={id} contactId={contactId} original={{ name, relationship, phone, email, notes }} /></div></Shell>;
}
