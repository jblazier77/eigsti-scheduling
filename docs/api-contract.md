# Initial backend contract

State: importable TypeScript modules and passing isolated request tests. The Request/Response jobs handler is now wired into the Next.js /api/jobs route; no hosted deployment exists. Initial browser screens are implemented with server-rendered session handling, but the test project publishable key and employee Auth/profile setup are still pending. Migration 0001 is applied in the isolated Free test project, and user reported 35 database checks, 0 failed.

`src/server/jobs-handler.ts` exports a Request/Response handler for the future Next.js route. It requires Supabase configuration and an employee Bearer token. Tests inject a fake network transport; application code has no synthetic-user bypass.

| Request | Enforcement |
| --- | --- |
| GET jobs, no scope | Active employee; PM filters responsible_pm=self; lead/helper rely on database RLS |
| GET jobs, scope=all | Active PM only; deterministic created/id order, 50 rows/page |
| POST jobs | Active PM; JSON max 8192 bytes; only requestId/customer/phone/address; one create_job RPC |
| No token | 401 before transport |
| Valid Auth token without active app profile | 403; cached role claims are insufficient |
| Unsupported method | 405; PATCH/DELETE not exposed |

Retain the form's request UUID after uncertain failure and resend unchanged. SQL create_job locks actor/request and creates job + work + audit + retry record atomically; changed payload with reused key conflicts. Sequential creation/retry behavior passed the user-run database suite; simultaneous multi-connection behavior still requires testing.

`password-auth.ts` delegates password/refresh to Supabase Auth, then validates live membership. No public signup, Google route, password storage or admin secret. The Next.js layer now adds cookie persistence/refresh and sign-out. Recovery, invitation acceptance, user administration and real Auth/browser checks remain required.

`supabase.ts` uses employee token and public key, rejects administrative keys/insecure remote origins, disables caching and returns controlled errors. No tokens or raw SQL details are logged.

Phone input proposal: formatted ten-digit US numbers, optional +1; readable input retained. International numbers/extensions are not implemented. No contacts/files endpoints exist. Private job entitlements must be maintained from actual visit participants in Phase 2; they never reserve staff.

References reviewed 2026-10-20:

- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/database/functions
- https://supabase.com/docs/guides/storage/security/access-control
- https://supabase.com/docs/reference/javascript/auth-getuser
- https://supabase.com/docs/reference/javascript/auth-signinwithpassword
- https://github.com/supabase/auth/blob/master/openapi.yaml

Exact Next.js/Supabase packages are installed and locked. See local-app.md for current full-build filesystem limits and the actual Auth/browser tests still required.
