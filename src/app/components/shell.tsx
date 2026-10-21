import Link from 'next/link';
import { signOutAction } from '../actions';

export function Shell({ title, children }: { title: string; children: React.ReactNode }) {
  return <div className="app-shell"><header className="app-header"><div className="header-row"><Link className="wordmark" href="/jobs">EIGSTI <span>CONSTRUCTION</span></Link><form action={signOutAction}><button className="text-button">Sign out</button></form></div><p className="eyebrow">YOUR WORK. YOUR PLAN.</p><h1>{title}</h1></header><div className="test-strip">TEST WORKSPACE · Use fictional customer information</div><main id="main">{children}</main><footer className="app-footer"><Link href="/jobs">Jobs</Link><Link href="/account">My account</Link><span>Eigsti Scheduling</span></footer></div>;
}
