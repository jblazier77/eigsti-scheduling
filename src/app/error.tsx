'use client';

export default function ErrorPage({ reset }: { reset: () => void }) {
  return <main id="main" className="standalone"><p className="eyebrow">EIGSTI SCHEDULING</p><h1>Couldn’t load this screen.</h1><p>Check your connection and try again. A failed load does not confirm a save.</p><button className="button primary" onClick={reset}>Try again</button><a className="button" href="/login">Go to sign in</a></main>;
}
