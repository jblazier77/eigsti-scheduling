import Link from 'next/link';
import { currentSession } from '../../lib/session';
export async function ScheduleNavigation() {
  const session = await currentSession();
  return session?.actor.roles.some(role => ['pm', 'lead', 'helper'].includes(role)) ? <Link href="/schedule">Schedule</Link> : null;
}
