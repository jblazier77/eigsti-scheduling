# Development plan

This is the current queue. Detailed historical decisions and verification records remain in decisions.md and status.md; older pending/application statements there are superseded by the checkpoints below.

## Verified checkpoint

- Latest user-confirmed GitHub backup: **fe13f1e**, phase-0-foundation, clean/up-to-date before the current D64–D68 batch.
- Applied database migrations: **0001–0016**. Never rerun applied migrations or their bundles.
- 0014: user confirmed **48 checks, 0 failed, synthetic fixtures removed**. Calendar views, commitments, moving dates and simplified calendar cards passed the user's reported desktop review.
- Core jobs, contacts/files, work/lead ownership, queues, optional-date scheduling/staffing, rain/filler tags, scopes/trades, material availability, one-save quick work and subcontractor commitments are implemented.
- No production deployment or pilot release is claimed.

## Current development batch: UI simplicity before pilot testing

D62: independent phone-first simplification, less whitespace, understandable buttons/icons and fewer everyday expanders. Compact spacing/navigation; always-visible scope labels; PM keeps all scope choices while readers see selected scopes; inline crew/material pencils; compact subcontractor contact rows; direct contact notes; linked job/queue titles instead of redundant links; no empty history accordion. Existing permissions, field values, command/retry behavior and one Save/Cancel flows are preserved.

Implemented locally: final combined batch has **190 Node checks and TypeScript passing**. **No SQL update**. Actual phone/tablet review and a final successful release build remain pending; see current status for the successful earlier build and final Windows EPERM. Automated Chrome screenshot capture was unavailable, so no visual acceptance is claimed. Batch is uncommitted; see ui-simplicity.md.

D61 employee management is implemented/applied (0016, reported expected 33-check success), user-reported name editing and deactivate/reactivate controls worked, and code is backed up as 0b5b259. Existing-session access revocation, role forgery, actual concurrent/fault and device checks remain separate. D60 archive/restore remains applied and accepted; handoff notes remain removed.

## Pilot preparation D63 implemented locally

Prepared hosting/Node configuration, isolated build command, preview/data-mode safeguards, employee/subcontractor session refresh coverage, encrypted database/Auth/private-file packages and verification/extraction tools, read-only readiness SQL, anonymous hosted-access checks and secret-free CI. See pilot-handoff.md for the single grouped owner/operator checklist. No new schema migration. Actual provisioning, live backup, daily offsite execution, managed restore, device/concurrency checks and pilot approval remain pending.

## Remaining initial pilot queue, in order

1. Save/push D62/D63; complete final production build in ordinary PowerShell or prepared CI, then grouped UI review. No SQL rerun.
2. Keep manual pilot provisioning/reset; verify admin access, deactivation and reactivation. Automated email workflows remain deferred.
3. Consolidated phone/tablet usability, role/access, leads-helping-on-other-work, concurrent scheduling and uncertain-save/fault checks. Reconcile legacy scenarios with planning-only work rather than reintroducing completion reporting.
4. Operational readiness: export and isolated database/auth/private-file restore drill, recovery instructions, realistic load/performance checks.
5. Hosting and limited pilot rollout: access without this computer running, final environment/security/operating checks, release candidate and pilot acceptance.

## Deferred or removed

- Dedicated handoff-note feature: **removed by user**, D60.
- SMTP/DNS, automated email invitations and self-service forgotten-password emails: post-pilot (user's Phase 2 list), see post-pilot.md.
- Google integration, notifications, daily completion/check-off screens and a separate return-work workflow are outside the authorized initial UI scope.

## Operating rules

Keep the carpenter-facing UI concise: inline edits, minimal clicks, one Save/Cancel per context. Dates/times are optional; multiple date-only jobs per day are supported. Expected material dates never assert actual delivery. A Lead account can coordinate one work entry and be helping crew on another; responsibility stays with the assigned work/coordinating lead. PM defaults to My jobs and can select All jobs. Calendar views are Day/Week/Two weeks/Month.

Use the user's ordinary PowerShell for a reliable backend-connected dev server. Stop dev before production builds. Run automated checks during development; group user acceptance into useful batches. Keep applied SQL immutable and use guarded new migrations with synthetic fixtures removed before commit. Record only observed browser/database/build results. Do not claim outstanding phone, concurrency, restore or pilot checks from automated unit tests.

## Next development batch after October 25 team review

User requested recording these items now and implementing them after tonight's local testing, together with the remaining review feedback. No implementation or SQL application is claimed. Restore drill and paid hosting are deferred while local review continues. Latest user-confirmed pushed checkpoint is fe13f1e, clean/up-to-date. Live encrypted backup and OneDrive web download verification passed; database restore remains unverified.

- D64: Unified job creation/details page. At the top show the minimum required job fields with Save job immediately below. Show the remaining usual scope, contacts, work, schedule and attachments sections below so optional information can be entered in the same creation flow. Allow a minimal save or saving additional supplied information without navigating through a separate short creation screen. Reuse the details layout/components; preserve drafts, permissions and safe save/retry behavior. Design how unsaved related records and uploads are handled before implementation; do not imply a record exists before confirmed creation.
- D65: Simple PM job priority. Provide a small editable priority number on customer job cards in the PM job list. Lower numbers sort first; blank priorities follow numbered jobs. Leads see the same saved job priority/order within the jobs they may access. Use a stable existing order for equal/blank numbers. Keep a single job-level value, PM editing, simple numeric entry and no scoring, categories or separate priority workflow. Show the same priority near the top of the job-details card/page so the lead can see it without returning to the list. This orders job lists; do not reorder a lead's explicit work queue or calendar dates.

## October 26 additions to the next review batch (queued, not implemented)

- D66: PM landing dashboard keeps My jobs and adds a compact, prominent Help needed summary for the PM's own jobs. Show each affected job/task, planned date when available, helpers requested/assigned and remaining shortfall, with a direct link or inline staffing edit. Include undated requests as Undated without reserving staff. Count distinct eligible assigned helpers, excluding the coordinating lead; show partial as well as entirely unfilled requests. Clear when filled and retain existing visibility rules. Reuse the staffing-warning logic; no notifications, completion reporting or separate dashboard workflow.
- D67: Optional approximate duration in days for every work task, entered during Add work and editable later by PM and authorized lead. Use a compact Estimated days field; support fractional days (for example 0.5). Missing remains unknown rather than zero. Show on the work card. Estimate is planning information, not actual time tracking or automatic calendar/staff booking. Validate positive values and retain estimates through scheduling edits.
- D68: Simplify saved work into concise, complete cards. Make the work/task name bold and prominent, with clearly discoverable in-place editing. Show applicable saved description, responsible lead, estimated days, date/time, requested/assigned help and shortfall, materials/readiness/expected date and notes in a compact readable layout. Use direct clickable fields or an accessible small pencil, one Save/Cancel per edit context, and retain drafts/error feedback. Avoid routine expand arrows, duplicate planning/staffing save buttons and another page for ordinary edits. Keep role/access boundaries; no new Finish/Complete controls.

These extend D64/D65. Implementation authorized October 26; see current batch result below.

## Current batch result: D64–D68

Implemented locally with 199 Node tests and successful isolated production build. Full-page job setup, numeric priority/order/detail marker, own-job help dashboard, fractional estimated days and bold directly editable work cards are prepared. One guarded 0017 SQL batch with 56 checks is ready, not applied; browser acceptance and commit/push are pending. See planning-review.md. Restore drill and paid hosting remain deferred by owner while local team testing continues.

0017 corrected guarded batch APPLIED, user confirmed 56 checks and 0 failed on October 26. Do not rerun it. D64–D68 grouped local UI review and commit/push remain pending.

D68 revision authorized October 26: remove click-to-edit/expansion modes from active work. Every authorized work card exposes its work/lead/days/material/date/crew inputs together with one Save/Cancel. Remove separate bulk, material and date/crew editors on job details. New guarded 0018 (27 checks) is prepared, not applied; see unified-work-editor.md. No automatic rename from material to task.

0018 APPLIED: user confirmed the expected guarded result (27 checks, 0 failed, synthetic fixtures removed). This supersedes earlier pending/application-failure notes. Do not rerun 0018 or earlier updates. Combined work-card browser acceptance, ordinary-PowerShell final build confirmation and commit/push remain pending.

D65 refinement implemented: PM edits priority directly on each job card; auto-save on blur/Enter and re-sort after confirmed save. No edit-mode button or SQL update. Read-only users retain the numeric badge. Local typecheck and 14 focused checks pass; browser acceptance and commit/push pending.

Work-card helper selector refined: explicit Assign helper dropdown beside Helpers needed for scheduled work, assigned names/shortfall visible, one Save and existing permission/booking checks. No new SQL; TypeScript and 15 focused tests pass. Await user review.

D69: correct undated first-save helper workflow and PM multi-select. Implemented locally for job work cards and Add work on existing jobs. No manual helper count prerequisite; selected people determine minimum spaces. One guarded 0019 with 25 checks is prepared, not applied. 211 Node tests and TypeScript pass. Named-helper selection on the full new-job draft remains separate, not claimed here. See first-save-helpers.md.

0019 APPLIED: user confirmed 25 checks, 0 failed on October 26. The guarded batch passed and removed synthetic fixtures before commit. Do not rerun 0019 or earlier updates. Final local validation: 211 Node tests, TypeScript and isolated production build passed. PM multi-select browser acceptance and saving/pushing the current local changes remain pending.


## D70: Add employee from the app (October 26)
Administrator-only Add employee is implemented locally with name/email/temporary password/roles (Helper default). It creates a confirmed Auth account without email delivery, then enrolls the app profile through a service-role-only RPC. Existing employee edits and role/deactivation protections remain. A dedicated server-only SUPABASE_ADMIN_KEY was configured privately from the matching-project operator credential; no operator database URL or backup passphrase is used by the app. No key or password is returned, logged, placed in client bundles or profile/audit tables.

Auth and profile writes are separate transactions: an interrupted enrollment may leave an Auth-only account with no app access. The unchanged request can recover that account using deterministic ID and server-signed metadata, without resetting its password, adopting an existing email account, overwriting a profile or deleting accounts. Active administrator authority is checked before provisioning, again before enrollment, and under the database enrollment lock. Password changes remain self-service in My account; forgotten-password resets stay manual and SMTP/invitations stay deferred. Temporary passwords are retained only in the form until success/close; no forced first-login password change is claimed.

0020 is PREPARED, NOT APPLIED: guarded bundle with 12 fictional checks, fixture rollback before commit. Local verification and live browser acceptance tracked in status.md. Restart dev after private environment configuration. No new live account was created during implementation.

0020 APPLIED: user confirmed the expected guarded result (12 checks, 0 failed, 0020 applied; synthetic fixtures removed) on October 26. Do not rerun 0020 or earlier migrations. Administrator Add employee is ready for grouped browser acceptance: create a fictional helper, confirm Employees and staffing visibility, and verify sign-in with the temporary password. Local tests/build passed; browser acceptance and commit/push remain pending.

## D71: Crew during full new-job setup (October 26)
New-job Add work now loads the scoped active helper/lead directory and shows the same always-visible multi-select helper choices. The responsible lead is excluded and selecting people increases helper spaces without requiring manual count entry. Date remains optional for count-only work; named crew requires a date. Existing employee creation remains in Employees. The same Save job creates all job details, tasks, dates, helpers and contacts in one database transaction; file upload remains post-confirmation with its existing retry behavior.

0021 is prepared, NOT APPLIED, with 15 guarded synthetic checks. It changes only create_job_workspace nested work creation to delegate to the already-applied create_staffed_work; existing workspace receipts, PM/active authority, legacy request guards and database staffing/conflict rules are retained. New backend rejects duplicate/ineligible crew, coordinating lead as helper, missing dates and insufficient spaces. No earlier migration edited or rerun. Live SQL/browser acceptance and commit/push are pending.

0021 APPLIED: user confirmed the expected guarded result (15 checks, 0 failed, 0021 applied; synthetic fixtures removed) on October 26. Do not rerun 0021 or earlier migrations. Full new-job helper multi-select is ready for browser review. 223 Node tests, TypeScript and final isolated production build passed; browser acceptance and commit/push remain pending.

## D72: Scheduled work without an assigned lead (October 26)
User explicitly chose to retain dates and named helpers while the lead is Not assigned yet. Implemented locally for new-job setup, Add work and existing date/card editors. Lead needed is visible on the work card and calendar independently of helper shortfalls. Assigning a responsible lead from the unified work card also fills its unassigned scheduled lead fields in the same save, preserving dates/helpers; a selected helper becoming the coordinating lead is removed from helping duty rather than duplicated. Existing specifically assigned coordinating leads are retained.

0022 is PREPARED, NOT APPLIED: visits.coordinator_id becomes nullable. PM-only null-coordinator creation/clearing uses existing scheduling commands, real helper reservations, conflict validation, receipts and audit. No placeholder person, implied lead booking or extra direct table access. Null-safe authorization is explicit in date, staffing, card, staff-directory and legacy progress commands so other leads cannot edit/claim unassigned scheduled work. Date uniqueness uses null-safe coordinator comparison. Create-work plan coordinator may match a null responsible lead. 28 guarded fictional SQL checks cover full creation, helper visibility, actual timed reservations/conflicts/rollback, later lead assignment, lead clearing, cancellation, and denial of unrelated/helper-lead writes. Live application and grouped UI acceptance remain pending.

0022 APPLIED: user confirmed 28 checks, 0 failed on October 26 after reviewing the Supabase destructive-operation warning. Guarded batch enforces synthetic fixture rollback before commit. Do not rerun 0022 or earlier migrations. PM can retain scheduled dates and named helpers without an assigned lead; Lead needed warning and later assignment are ready for grouped browser acceptance. 228 Node tests, TypeScript and isolated production build passed. Browser acceptance and commit/push remain pending.

## D73: Saturday work (October 26)
User identified Saturday as the date-validation failure and confirmed saving work with a date and no lead otherwise succeeded. D72 browser acceptance for no-lead dated save is recorded; later lead assignment remains separately unconfirmed. Saturday scheduling is now implemented locally alongside Monday-Friday. Sunday remains excluded. Calendar work rendering and actual named-person reservations include Saturdays, including multi-day ranges, and skip Sundays. Existing 7:00 AM-3:30 PM time limits and maximum 31-calendar-day span remain.

0023 is prepared, NOT APPLIED: guarded 16-check fixture-rollback batch. It replaces the workday constraint and private reservation rebuild helper, adds Saturday reservations for existing planned multi-day explicit time blocks, and fails/rolls back if those additions produce a conflict. It does not change named assignments, dates, ownership or history. Date-only entries remain nonexclusive; Sunday stays invalid as a start/end. No prior applied migration edited. Browser review and commit/push pending.

0023 APPLIED: user reported the Saturday update worked as expected after the guarded instructions (16 checks, 0 failed, synthetic fixtures removed). Do not rerun 0023 or earlier migrations. Saturday scheduling is enabled; multi-day work includes Saturdays and skips Sundays. No separate Saturday browser save/calendar confirmation or commit/push is inferred from the SQL acknowledgment. 230 Node tests, TypeScript and isolated production build passed.
