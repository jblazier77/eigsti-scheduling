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

## Additional job contacts (migration 0002 applied in test)

Cookie-authenticated Server Actions add/edit/archive contacts with independent live membership and PM checks. No application REST contact endpoint or administrative key is introduced. Direct employee-token SELECT on `job_contacts` follows `private.can_read_job(job_id)` and excludes archived rows. The client filters the parent job plus contact ID; SQL mutations match both IDs and refuse cross-job spoofing. Authenticated users have SELECT only; all raw writes are denied.

- Create RPC: `create_job_contact(p_job_id,p_request_id,p_values)`. Values have name/relationship/phone/email/notes string keys; the UI supplies empty strings for optional fields. Same actor/request/payload returns the original ID without a second contact or audit. A changed job/payload conflicts. A replay never restores an archived contact.
- Update RPC: `update_job_contact(p_job_id,p_contact_id,p_patch)`. Only changed allowed text fields; empty optional fields clear values, empty name is invalid. Phone actions are recomputed or cleared atomically. Updates have last-save-wins semantics for submitted fields and do not deduplicate audit events.
- Removal RPC: `archive_job_contact(p_job_id,p_contact_id)`. PM-only soft archive; repeat is safe and does not duplicate archive history. No public restore/delete command.
- Name max 100, relationship/trade max 100, phone max 40 with optional ten-digit US format/+1, email max 254, notes max 1000 with multiline text. Only name is required in the UI. Maximum 100 active contacts per job; create checks the count while holding the parent job lock.

Each successful mutation audits the real employee and identifies the contact without copying contact values into the audit event. Before 0002 is applied, a missing-table/schema-cache result shows an unavailable contact section and preserves the rest of the job page. Other failures propagate normally. The company trade directory, subcontractor commitments and files are separate future work. Six Node checks cover validation, role boundaries, scoped transport, narrow patching and interrupted/missing-schema behavior; 60 SQL checks and recorded contact browser acceptance passed per user.

References reviewed 2026-10-20:

- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/database/functions
- https://supabase.com/docs/guides/storage/security/access-control
- https://supabase.com/docs/reference/javascript/auth-getuser
- https://supabase.com/docs/reference/javascript/auth-signinwithpassword
- https://github.com/supabase/auth/blob/master/openapi.yaml

Exact Next.js/Supabase packages are installed and locked. See local-app.md for current full-build filesystem limits and the actual Auth/browser tests still required.

## Private files (migration 0003 applied in test)

prepareFileAction accepts only job/request IDs and small name/size/mime metadata, verifies Auth/profile, and reserves the pending job_files row through begin_job_file. An employee-token Storage client then obtains an insert-only signed URL for the generated job UUID/file UUID path. No administrative key or employee token is returned to the browser. Browser PUT sends bytes directly to that capability; the existing 32 KB Server Action limit stays unchanged.

finishFileAction reauthorizes and calls finish_job_file. SQL matches job/file/owner, expected byte size/MIME against storage.objects metadata, then atomically publishes/audits once. A retry first tries finalization, and reissues a capability only for an upload-pending response. It never overwrites an existing object. This validates metadata, not binary content. Archive is soft, idempotent and audited; PM any/assigned lead own only. No direct table write, Storage overwrite or Storage deletion is granted by this feature.

GET /jobs/[id]/files/[fileId]/download verifies Auth/profile and ready-file RLS, then returns a no-store/no-referrer 303 to a forced-download signed URL with 60-second TTL. Already issued URLs remain bearer capabilities until expiry; new URLs always recheck access. Upload capabilities last two hours and can outlive an account change, but final publication requires current access. No byte stream traverses the application server. Pending/archived files cannot be downloaded through this route.

See job-files.md for limits, source references, original HEIC behavior, orphan/archived byte retention and required actual Storage/phone tests. Migration 0003 and its 66 metadata/RLS SQL assertions passed per user, as did the full build and desktop upload/download/refresh/removal/helper upload denial. 40 Node tests and TypeScript pass. Phone, fault/retry and remaining access/expiry acceptance remain pending.

## Work ownership (migration 0004 prepared, not applied)

list_assignable_leads returns active lead ID/name only to PMs. list_job_work(p_job_id) returns authorized job work plus assigned lead names. create_job_work(p_job_id,p_request_id,p_values) requires description and nullable responsible_lead, deduplicates canonical actor/request payload, validates open parent/active lead and enforces 100 total entries under job lock. update_job_work(p_job_id,p_work_id,p_patch) accepts only changed description/responsible_lead, locks job/work and validates new lead, preserving other fields. Active PM only; no direct writes. Work identity and audit actor/field history remain; no full before/after snapshot or history viewer. Work ownership derives job access through existing RLS but reserves no dates/helpers. Cookie Server Actions reverify live membership; UI forms retain uncertain saves, and creates retain the request UUID. See work-ownership.md for pending SQL/browser/concurrency checks.

## Contact creation scope update (0005 prepared; not applied)

At user request, create_job_contact also permits active leads with current target-job access. Permission is checked before replay and again after parent job lock. Existing canonical retry, 100-contact limit, validation, audit identity and archive-replay behavior retained. No role change for update_job_contact/archive_job_contact: PM only, even for a contact added by the lead. New-contact route/action and Add contact control are updated; target authorization remains SQL enforced. See lead-contacts.md for pending 32 SQL checks and browser acceptance.

## Work card atomic save (0006 prepared; not applied)

update_job_work_batch(p_job_id,p_request_id,p_changes) accepts 1-100 unique work_id/patch entries and canonicalizes order/patches. Active PM only. Parent lock and existing update_job_work commands make row changes/audits one transaction; any error rolls everything back. Actor/request replay returns receipt plus current authorized work without reapplying old patches; changed payload conflicts. updateWorkCardAction sends one employee RPC, revalidates only after success and returns current work to the card. The form bounds serialized changes to 20,000 UTF-8 bytes within the existing 32 KB action limit; uncertain requests retain frozen payload/UUID for retry. See work-card-save.md and the pending 40 SQL checks.

## Lead queues (0007 prepared; not applied)

get_lead_queue(p_lead_id) returns target lead ID/name, current revision and ordered open owned work/job context. save_lead_queue(p_lead_id,p_request_id,p_work_ids) accepts the complete unique membership array (max 500), no expected revision. Active PM or target active lead only. Membership/order writes serialize on a company advisory lock and queue row; latest committed order wins, changed membership is a controlled reload conflict, and old actor/request retries return current order without replay. Immutable private events retain final order/revision/actor. Direct raw access/private helper execution revoked. No dates or staffing are reserved. Queue Server Action checks live session/role and input bounds, sends one RPC and revalidates only after success. See lead-queues.md for pending SQL/build/browser/concurrency evidence.

## Scheduled visits (0008 prepared, not applied)

Employee-authenticated RPCs: save_visit(work UUID, nullable visit UUID, request UUID, narrow patch JSON); staff_visit(visit UUID, request UUID, complete helper UUID array); get_visit(visit UUID); list_job_visits(job UUID); list_schedule(start date, end date, all boolean default false); visit_staff_options(visit UUID). Exact SQL argument names are in 0008. Raw visits/participants/bookings/events are inaccessible to employees. Server routes: /schedule (day default, week toggle, PM My/All), /visits/[id] (PM/current coordinator), plus inline create and scoped summaries on job details. Date-only day slot has no hours; explicit slots reserve participants. 23P01 maps to a definite conflict retaining existing assignments, uncertain transport errors preserve same-request retry. See scheduled-visits.md.

0009 prepared: save_visit_card(p_work_id UUID,p_visit_id UUID,p_request_id UUID,p_patch JSONB,p_helpers UUID[] nullable). One atomic shared-draft command. NULL helpers omits roster; empty array explicitly removes names (PM only when occupied); patch omits unchanged fields. Canonical receipt and full rollback on conflict. Existing RPCs remain compatible.

0010 prepared: list_job_progress(p_job_id UUID) and work_progress_command(p_work_id UUID,p_visit_id UUID nullable,p_follow_up_id UUID nullable,p_request_id UUID,p_command TEXT,p_values JSONB). Explicit commands finish_visit/complete_work/record_return/resolve_return/reopen_work/plan_return. Current PM/coordinator/owner scope and exact parents validated in SQL. Return result contains job/work/result IDs and optional authorized visit. Raw follow-ups/history denied. See completion-and-returns.md.

## Job classification and trade directory (0011, local/pending acceptance)

PM: create_classified_job(uuid,text,text,text,jsonb) atomically creates ordinary job/default work plus optional rain_day/filler/whole_house/trades. save_job_classification(uuid,uuid,jsonb) accepts only narrow classification fields and canonical known trades. Both verify a live PM profile, use actor/request receipts and reject changed retry payloads; old retries never replay edits. Raw job writes remain denied. New columns inherit existing job-read RLS.

Directory: subcontractors select is active PM/admin/lead only and excludes archived rows. save_subcontractor(uuid nullable,uuid,jsonb) is PM/admin-only: name/phone/email/trades narrow patch or archive:true by itself. Create requires the four validated fields; only name must be nonempty. Stable request receipts and private before/after events retain history. Helpers/anonymous/disabled accounts cannot browse/manage the directory; admin alone cannot classify jobs. Job scopes do not imply subcontractor assignment.

Private raster preview: GET /jobs/{jobId}/files/{fileId}/preview verifies current Auth/live membership and exact RLS-visible ready file metadata, then signs and retrieves the exact private object server-side. Only JPEG/PNG/WebP, canonical paths, bounded recorded file size and matching upstream Content-Type are accepted. Returns inline bytes with private/no-store, nosniff, no-referrer and sandbox headers; no signed URL or employee token is placed in gallery markup. Anonymous returns 401; hidden/archived/pending/unsupported files are unavailable. Existing forced original-download route remains available for authorized PDF/HEIC and other supported originals. No new SQL.
