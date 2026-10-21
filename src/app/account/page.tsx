import { requireSession } from '../../lib/session';
import { Shell } from '../components/shell';
import { PasswordForm } from '../components/password-form';

export const dynamic = 'force-dynamic';
export default async function Account() {
  await requireSession();
  return <Shell title="My account"><section className="card form-card"><h2>Change password</h2><p>Enter your current password and choose a new one. Keep your password private.</p><PasswordForm /></section></Shell>;
}
