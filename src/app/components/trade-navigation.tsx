import Link from 'next/link';
import { currentSession } from '../../lib/session';
export async function TradeNavigation(){
  const session=await currentSession();
  return session?.actor.roles.some(r=>['admin','pm','lead'].includes(r))?<Link href="/subcontractors">Subcontractors</Link>:null;
}
