'use client';
import { useFormStatus } from 'react-dom';
export function SignOutButton() {
  const { pending } = useFormStatus();
  return <button className="text-button" disabled={pending} aria-busy={pending}>{pending ? 'Signing out...' : 'Sign out'}</button>;
}
