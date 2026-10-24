import Link from 'next/link';
import {currentSession} from '../../lib/session';
export async function EmployeeNavigation(){const session=await currentSession();return session?.actor.roles.includes('admin')?<Link href="/employees">Employees</Link>:null;}
