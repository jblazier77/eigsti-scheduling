'use client';

import Link from 'next/link';
import { useActionState, useState } from 'react';
import { changePasswordAction } from '../account-actions';

export function PasswordForm() {
  const [values, setValues] = useState({ currentPassword: '', newPassword: '', confirmPassword: '' });
  const [state, action, pending] = useActionState(changePasswordAction, { message: '' });
  return <form action={action} className="stack">
    {([
      ['currentPassword', 'Current password', 'current-password'],
      ['newPassword', 'New password', 'new-password'],
      ['confirmPassword', 'Confirm new password', 'new-password']
    ] as const).map(([name, label, autoComplete]) => <div key={name}><label htmlFor={name}>{label}</label><input id={name} name={name} type="password" autoComplete={autoComplete} value={values[name]} onChange={e => setValues({ ...values, [name]: e.target.value })} required maxLength={name === 'currentPassword' ? 1024 : 72} minLength={name === 'currentPassword' ? 1 : 12} readOnly={pending || !!state.uncertain} /></div>)}
    <p className="muted">Use at least 12 characters. A password manager can help you choose and save a unique password. You will sign in again after the change.</p>
    {state.message && <p className="form-message" role="alert">{state.message}</p>}
    {state.uncertain ? <Link className="button primary full" href="/login">Check sign-in with your new password</Link> : <button className="button primary full" disabled={pending}>{pending ? 'Changing password…' : 'Change password'}</button>}
    <Link className="button full" href="/jobs">Cancel</Link>
  </form>;
}
