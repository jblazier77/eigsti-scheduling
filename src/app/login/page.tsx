import { redirect } from 'next/navigation';
import { appConfig } from '../../lib/config';
import { SignInForm } from '../components/forms';

export const dynamic = 'force-dynamic';
export default async function Login({ searchParams }: { searchParams: Promise<{ reason?: string }> }) {
  if (!appConfig()) redirect('/');
  const { reason } = await searchParams;
  return <div className="login-shell"><div className="wordmark">EIGSTI <span>CONSTRUCTION</span></div><main id="main" className="welcome"><p className="eyebrow">SCHEDULING</p><h1>Ready for<br />what’s next.</h1><p className="intro">Sign in to see your jobs and plan your work.</p><div className="card"><h2>Welcome back</h2><SignInForm notice={reason === 'password-changed' ? 'Password changed. Sign in with your new password.' : reason === 'access' ? 'Please sign in with an active app account.' : ''} /></div><p className="footnote">Individual app accounts · Contact your administrator for access.</p><p className="test-note">Test workspace · Fictional jobs only</p></main></div>;
}
