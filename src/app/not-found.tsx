import Link from 'next/link';
export default function NotFound() {
  return <main id="main" className="standalone"><p className="eyebrow">EIGSTI SCHEDULING</p><h1>Job unavailable.</h1><p>This job is unavailable to your account or could not be found.</p><Link className="button primary" href="/jobs">Back to my jobs</Link></main>;
}
