'use client';

import { useActionState, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { signInAction, createJobAction, type FormState } from '../actions';

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

export function NewJobForm({ requestId }: { requestId: string }) {
  const router = useRouter();
  const [state, action, pending] = useActionState(async (previous: FormState, form: FormData): Promise<FormState> => {
    try { return await createJobAction(previous, form); }
    catch { return { message: 'The save was not confirmed. Your details are still here.', uncertain: true }; }
  }, initial);
  useEffect(() => { if (state.jobId) router.push('/jobs/' + encodeURIComponent(state.jobId)); }, [state.jobId, router]);
  const [values, setValues] = useState({ customer: '', phone: '', address: '' });
  const fields = [
    { name: 'customer' as const, label: 'Customer name', max: 100, type: 'text', auto: 'name' },
    { name: 'phone' as const, label: 'Phone number', max: 40, type: 'tel', auto: 'tel' },
    { name: 'address' as const, label: 'Job address', max: 300, type: 'text', auto: 'street-address' }
  ];
  return <form action={action} className="stack">
    <input type="hidden" name="requestId" value={requestId} />
    {fields.map(field => <div key={field.name}><label htmlFor={field.name}>{field.label}</label><input id={field.name} name={field.name} type={field.type} autoComplete={field.auto} required maxLength={field.max} value={values[field.name]} readOnly={pending || state.uncertain} onChange={e => setValues({ ...values, [field.name]: e.target.value })} /></div>)}
    {state.message && <p className="form-message" role="alert">{state.message}</p>}
    {state.uncertain && <p className="muted">Your details are retained. Retry this same save so an interrupted connection cannot create a second job.</p>}
    <button className="button primary full" disabled={pending || !!state.jobId}>{pending ? 'Saving job…' : state.jobId ? 'Job saved. Opening…' : state.uncertain ? 'Retry this save' : 'Create job'}</button>
    <p className="muted">Add scope, contacts and files later. No phase setup needed.</p>
  </form>;
}
