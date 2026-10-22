import Link from 'next/link';
import { currentSession } from '../../lib/session';

export async function QueueNavigation() {
  const session = await currentSession();
  if (!session || !session.actor.roles.some(role => role === 'pm' || role === 'lead')) return null;
  return <Link href="/queue">Lead queues</Link>;
}
