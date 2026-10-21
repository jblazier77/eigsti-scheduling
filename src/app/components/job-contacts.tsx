import Link from 'next/link';
import { AppError } from '../../domain/access.ts';
import type { SupabaseSession } from '../../server/supabase.ts';

export async function JobContacts({ jobId, isPm, gateway }: { jobId: string; isPm: boolean; gateway: SupabaseSession }) {
  let contacts;
  try { contacts = await gateway.listContacts(jobId); }
  catch (error) {
    if (!(error instanceof AppError) || error.code !== 'schema_pending') throw error;
    return <section className="card"><h3>Additional job contacts</h3><p className="muted">Additional contacts are temporarily unavailable. Please try again later.</p></section>;
  }
  return <section className="card">
    <div className="section-heading"><h3>Additional job contacts</h3>{isPm && contacts.length < 100 && <Link className="button" href={'/jobs/' + jobId + '/contacts/new'}>Add contact</Link>}</div>
    {!contacts.length && <p className="muted">{isPm ? 'Add a spouse, site contact or trade contact for this job.' : 'No additional contacts added yet.'}</p>}
    {contacts.map(contact => <article className="contact-entry" key={contact.id}>
      <div className="section-heading"><div><h3>{contact.name}</h3>{contact.relationship && <p className="muted">{contact.relationship}</p>}</div>{isPm && <Link className="button" href={'/jobs/' + jobId + '/contacts/' + contact.id + '/edit'}>Edit<span className="sr-only"> {contact.name}</span></Link>}</div>
      {contact.phone && <p>{contact.phone}</p>}
      {contact.phone_action && <div className="two-actions"><a className="button primary" href={'tel:' + contact.phone_action}>Call<span className="sr-only"> {contact.name}</span></a><a className="button" href={'sms:' + contact.phone_action}>Text<span className="sr-only"> {contact.name}</span></a></div>}
      {contact.email && <p className="contact-email"><a href={'mailto:' + encodeURIComponent(contact.email)}>{contact.email}</a></p>}
      {contact.notes && <p className="preserve-lines">{contact.notes}</p>}
    </article>)}
    {contacts.length >= 100 && isPm && <p className="muted">This job has 100 additional contacts. Remove an outdated contact before adding another.</p>}
  </section>;
}
