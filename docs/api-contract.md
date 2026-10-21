# Initial backend contract

State: importable TypeScript modules and passing isolated request tests. The Request/Response jobs handler is wired into the Next.js /api/jobs route; no hosted deployment exists. Test project connection, PM/helper profiles and initial browser sign-in, create/persistence/logout and unassigned helper denial checks are complete. Migration 0001 is applied in the isolated Free test project, and user reported 35 database checks, 0 failed.

`src/server/jobs-handler.ts` exports a Request/Response handler for the future Next.js route. It requires Supabase configuration and an employee Bearer token. Tests inject a fake network transport; application code has no synthetic-user bypass.

| Request | Enforcement |
| --- | --- |
| GET jobs, no scope | Active employee; PM filters responsible_pm=self; lead/helper rely on database RLS |
| GET jobs, scope=all | Active PM only; deterministic created/id order, 50 rows/page |
| POST jobs | Active PM; JSON max 8192 bytes; only requestId/customer/phone/address; one create_job RPC |
| No token | 401 before transport |
| Valid Auth token without active app profile | 403; cached role claims are insufficient |
| Unsupported method | 405; PATCH/DELETE not exposed |

PM editing uses the cookie-authenticated `updateJobAction` Server Action, not a new REST PATCH endpoint. Every submission verifies Auth and live app membership, then requires an active PM. Only title/customer_name/phone/address/scope/access_notes strings are accepted. The client compares against the original form and sends only changed fields; the server independently validates keys, UUID, phone, lengths and text. Empty optional scope/access notes clear those fields. No automatic title regeneration on contact/address edits. `update_job(p_job_id,p_patch)` already exists in migration 0001 and atomically updates fields plus audit history; no new migration is needed. Other fields, lifecycle and PM assignment are not accepted.

An uncertain update retains the form and offers a separate-tab link to inspect saved values. Updates have no creation-style request UUID/deduplication: a manual repeat save wins again for the submitted fields and creates another audit event. This must not be described as exactly-once or as protection against conflicting edits to the same field.

Retain the form's request UUID after uncertain failure and resend unchanged. SQL create_job locks actor/request and creates job + work + audit + retry record atomically; changed payload with reused key conflicts. Sequential creation/retry behavior passed the user-run database suite; simultaneous multi-connection behavior still requires testing.

`password-auth.ts` delegates password/refresh to Supabase Auth, then validates live membership. No public signup, Google route, password storage or admin secret. The Next.js layer now adds cookie persistence/refresh and sign-out. Recovery, invitation acceptance, user administration and real Auth/browser checks remain required.

`supabase.ts` uses employee token and public key, rejects administrative keys/insecure remote origins, disables caching and returns controlled errors. No tokens or raw SQL details are logged.

Phone input proposal: formatted ten-digit US numbers, optional +1; readable input retained. International numbers/extensions are not implemented. Private job entitlements must be maintained from actual visit participants in Phase 2; they never reserve staff.

## Additional job contacts (migration 0002 pending)

Cookie-authenticated Server Actions add/edit/archive contacts with independent live membership and PM checks. No application REST contact endpoint or administrative key is introduced. Direct employee-token SELECT on `job_contacts` follows `private.can_read_job(job_id)` and excludes archived rows. The client filters the parent job plus contact ID; SQL mutations match both IDs and refuse cross-job spoofing. Authenticated users have SELECT only; all raw writes are denied.

- Create RPC: `create_job_contact(p_job_id,p_request_id,p_values)`. Values have name/relationship/phone/email/notes string keys; the UI supplies empty strings for optional fields. Same actor/request/payload returns the original ID without a second contact or audit. A changed job/payload conflicts. A replay never restores an archived contact.
- Update RPC: `update_job_contact(p_job_id,p_contact_id,p_patch)`. Only changed allowed text fields; empty optional fields clear values, empty name is invalid. Phone actions are recomputed or cleared atomically. Updates have last-save-wins semantics for submitted fields and do not deduplicate audit events.
- Removal RPC: `archive_job_contact(p_job_id,p_contact_id)`. PM-only soft archive; repeat is safe and does not duplicate archive history. No public restore/delete command.
- Name max 100, relationship/trade max 100, phone max 40 with optional ten-digit US format/+1, email max 254, notes max 1000 with multiline text. Only name is required in the UI. Maximum 100 active contacts per job; create checks the count while holding the parent job lock.

Each successful mutation audits the real employee and identifies the contact without copying contact values into the audit event. Before 0002 is applied, a missing-table/schema-cache result shows an unavailable contact section and preserves the rest of the job page. Other failures propagate normally. The company trade directory, subcontractor commitments and files are separate future work. Six Node checks cover validation, role boundaries, scoped transport, narrow patching and interrupted/missing-schema behavior; SQL execution and browser acceptance remain pending.

References reviewed 2026-10-20:

- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/database/functions
- https://supabase.com/docs/guides/storage/security/access-control
- https://supabase.com/docs/reference/javascript/auth-getuser
- https://supabase.com/docs/reference/javascript/auth-signinwithpassword
- https://github.com/supabase/auth/blob/master/openapi.yaml

Exact Next.js/Supabase packages are installed and locked. See local-app.md for current full-build filesystem limits and the actual Auth/browser tests still required.
