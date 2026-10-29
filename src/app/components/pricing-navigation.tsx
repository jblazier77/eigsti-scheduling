import Link from 'next/link';
import {currentSession} from '../../lib/session';
export async function PricingNavigation(){const s=await currentSession();return s?.actor.active&&s.actor.roles.some(r=>['pm','lead','admin'].includes(r))?<Link href="/pricing">Pricing</Link>:null;}
