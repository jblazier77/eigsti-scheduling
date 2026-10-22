import {redirect} from 'next/navigation';
import {appConfig} from '../../lib/config';
import {SignInForm} from '../components/forms';
export const dynamic='force-dynamic';
export default async function Login({searchParams}:{searchParams:Promise<{reason?:string}>}) {
  if(!appConfig())redirect('/');
  const {reason}=await searchParams;
  return <div className="login-shell"><div className="wordmark">EIGSTI <span>CONSTRUCTION</span></div><main id="main" className="welcome"><h1>Sign in</h1><p className="intro">Your jobs, crew and schedule.</p><div className="card"><SignInForm notice={reason==='password-changed'?'Password changed. Sign in with your new password.':reason==='access'?'Please sign in with an active app account.':''}/></div><p className="footnote">Need access? Contact your administrator.</p><p className="test-note">Test workspace / Fictional jobs only</p></main></div>;
}
