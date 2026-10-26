'use client';

import { useActionState, useState } from 'react';
import { signInAction, type FormState } from '../actions';

const initial: FormState = { message: '' };

export function SignInForm({ notice = '' }: { notice?: string }) {
  const [state, action, pending] = useActionState(signInAction, initial);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  return <form action={action} className="stack">
    <div><label htmlFor="email">Email address</label><input id="email" name="email" type="email" autoComplete="username" value={email} onChange={e => setEmail(e.target.value)} maxLength={254} required /></div>
    <div><label htmlFor="password">Password</label><input id="password" name="password" type="password" autoComplete="current-password" value={password} onChange={e => setPassword(e.target.value)} maxLength={1024} required /></div>
    {(state.message || notice) && <p className="form-message" role="alert">{state.message || notice}</p>}
    <button className="button primary full" disabled={pending}>{pending ? 'Signing in…' : 'Sign in'}</button>
  </form>;
}
