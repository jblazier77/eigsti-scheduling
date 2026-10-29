import Link from 'next/link';
import { signOutAction } from '../actions';
import { QueueNavigation } from './queue-navigation';
import { ScheduleNavigation } from './schedule-navigation';
import { SignOutButton } from './sign-out-button';
import { TradeNavigation } from './trade-navigation';
import {PricingNavigation} from './pricing-navigation';
import {EmployeeNavigation} from './employee-navigation';
import {workspaceLabel} from '../../lib/config';
export function Shell({title,children,compactTitle=false}:{title:string;children:React.ReactNode;compactTitle?:boolean}) {
  return <div className="app-shell"><header className="app-header"><div className="header-row"><Link className="wordmark" href="/jobs">EIGSTI <span>CONSTRUCTION</span></Link><form action={signOutAction}><SignOutButton/></form></div>{compactTitle?<p className="page-context">{title}</p>:<h1>{title}</h1>}</header><div className="test-strip">{workspaceLabel()}</div><main id="main">{children}</main><footer className="app-footer"><Link href="/jobs">Jobs</Link><QueueNavigation/><ScheduleNavigation/><TradeNavigation/><PricingNavigation/><EmployeeNavigation/><Link href="/account">My account</Link></footer></div>;
}
