import { redirect } from 'next/navigation';
import { appConfig } from '../lib/config';

export const dynamic = 'force-dynamic';
export default function Home() {
  if (appConfig()) redirect('/jobs');
  return <div className="login-shell"><div className="wordmark">EIGSTI <span>CONSTRUCTION</span></div><main id="main" className="welcome"><p className="eyebrow">SCHEDULING · TEST SETUP</p><h1>A place for<br />the next step.</h1><p className="intro">The first app screens are ready for a test connection.</p><div className="card"><h2>Connect the test project</h2><p>Add the project URL and publishable key to <code>.env.local</code>, then restart the development server.</p><p className="muted">No customer information is loaded. No employee sign-in is enabled until the test connection is configured.</p></div><p className="footnote">Eigsti Scheduling · Development checkpoint</p></main></div>;
}
