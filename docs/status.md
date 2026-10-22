# Current status

Updated 2026-10-22. Initial app, PM editing and additional job contacts have passed the checks recorded below. Phase 0 exit and remaining Phase 1 work are still pending. No production deployment.

## Checkpoint

- Workspace: C:\Users\jrbla\OneDrive\Projects\ChatGPT\Eigsti Scheduling
- Branch: phase-0-foundation
- Latest confirmed uploaded commit: 6285665 (lead queues and database/browser checks). Visits/staffing/calendar code is local and uncommitted. 0008 is applied with 60 checks/0 failed; new shared-card 0009 is prepared, unapplied.
- Private origin: https://github.com/jblazier77/eigsti-scheduling.git
- Test Supabase project: vglhojtrccygjgupxsrd, Free plan in Eigsti Construction organization.
- User PowerShell manages commits/pushes because agent Git writes remain restricted.
- Final shared-card production build passed and a79c78e was pushed. Dev restarted for ownership checks. User most recently returned to Josh/PM to restore Test Lead on the cabinet portion; both cabinet and countertop portions are now assigned to Test Lead after queue acceptance.
- Keep .env.local ignored. No passwords, tokens or administrative secrets are recorded here.

## Verified implementation

- New local slice: ordered per-lead work queues with PM-any/lead-own access, Up/Down, one Save/Cancel, canonical request retries, latest committed full-order saves and ownership/completion/job-lifecycle membership triggers. 63 Node tests/TypeScript pass. User confirmed 0007 applied, 58 SQL checks/0 failed, full build and core PM/lead/helper desktop acceptance. Concurrent, phone and fault acceptance remain pending. See lead-queues.md.

- Standalone individual password sign-in/sign-out; cookie session handling and live account checks; no Google integration.
- PM My Jobs/All Jobs, three-field create plus default work item, authorized job details and phone/directions links.
- PM editing of title/customer/phone/address/scope/access notes; narrow updates preserve unrelated fields. Optional notes clear; invalid phone retains form; cancel discards changes.
- Additional contacts for a single job, including customer-side/site/trade contacts. Name required; relationship, US phone, email and shared notes optional. PM add/edit/archive, authorized job readers, call/text/email links, narrow changes, audited soft removal and retry-safe creation. Maximum 100 active contacts per job.
- Private attachments are implemented locally with original HEIC/HEIF, PDF/JPEG/PNG/WebP, a 10 MiB/file limit, private direct upload, scoped download and soft archive. Migration 0003, 66 SQL checks, full build and basic desktop Storage/browser checks passed per user. Real iPhone acceptance remains pending. See job-files.md.
- Work ownership/lead assignment is prepared locally; migration 0004 is applied in the test project; user confirmed 58 checks, 0 failed and a full production build before the inline editor change. Queues now pass the desktop checks below; visits/staffing, global trade directory and complete account administration are not implemented. Email invitations/self-service recovery moved to the post-pilot list by user decision; manual onboarding/reset is the limited-pilot provision.
- Signed-in own-password changes are implemented locally at /account for all active roles, with explicit current-password reauthentication, live membership checks and logout after success. Full build and core helper browser checks passed per user; see accounts.md. Cancel, phone and fault acceptance remain pending. Signed-in password changes are pushed as e95f6ea. Email recovery/invitations are deferred; phone admin account management remains initial scope.

## Database and automated evidence

- User reported migration 0003 success in the test project on 2026-10-21, then 66 checks, 0 failed after correcting assertion 37 to a top-level WITH ... INSERT ... SELECT. The initial nested data-modifying CTE failed with PostgreSQL 0A000. Test-only correction; migration is applied and must not be rerun.
- Applied migration 0001: user reported SQL success and 35 checks, 0 failed.
- Applied migration 0002: user reported SQL success and 60 contact checks, 0 failed.
- Both SQL suites use synthetic transaction fixtures and roll them back. Cloud SQL evidence is user reported; the agent did not run a local database.
- Do not edit or rerun these applied migrations on the existing project. Future functional SQL changes require new ordered migrations.
- Latest automated Node suite: 63 passed, including five work ownership/action tests, six account/password checks, six file checks and prior contact removal regressions. TypeScript passed after work ownership changes. User reported 58 work SQL checks passed and the original work routes built successfully. The inline editor change passed Node/TypeScript; its full build remains pending; inline Cancel/Save/refresh and lead read-only browser checks passed. User confirmed 0005 applied, 32 SQL checks with no failures and full production build after inline work/contact changes. Lead contact creation/refresh and helper direct-create denial passed. Auth SDK transport is mocked for automated password tests; separate real helper password-change browser checks passed per user.
- Latest full production build including /account and file upload/download routes passed in user PowerShell. No new agent cleanup attempt is made due prior Windows/OneDrive issues.
- Fixture generator and prototype structural smoke checks previously passed. Those are separate from real database/browser evidence.
- PostgreSQL version/full TAP transcripts, clean-reset repeat and simultaneous multi-connection tests remain pending. Earlier sequential retry and stale-form checks are not concurrent-transaction proof.

## User browser evidence

- Ownership/revocation browser acceptance: after an initial test likely cleared both leads, user restored only Test Lead on the cabinet portion, left countertops unassigned, saved, then signed in as Test Lead and confirmed job visibility. PM then cleared the final cabinet assignment; Test Lead saw no jobs and direct job details plus direct new-contact route both showed Job unavailable. User then acknowledged restoring the cabinet assignment as Josh/PM for the next test setup. No application bug or code change was established by the initial empty list. This verifies remaining-portion access and final-ownership revocation; concurrent reassignment, second-lead handoff and phone/fault behavior remain separate.

- Shared-card correction verified: user confirmed Save now completes with the expected button/cursor/field behavior, refresh retains both work descriptions and lead assignments, and a final normal-user production build passed after the fix. Single Cancel had already restored both draft descriptions. Exact final description text after the small retest edit was not recorded. No new SQL was needed for the button fix.

- Shared card: user confirmed 0006 applied, 40 checks/0 failed, full production build and dev restart. Both portions showed one Save/Cancel pair; Cancel reset two drafts correctly. Save appeared to persist both renamed portions, but button/cursor stayed busy. Removed redundant post-action router refresh and clean-disabled wait cursor; show Saved on confirmed clean success. Browser retest/full build after this client correction pending; see work-card-save.md.

- User requested one Save/Cancel pair for the entire Work and leads card after the Countertops add-portion step. Its creation was not explicitly confirmed before the UI request. Implemented a single card draft and new atomic/retry-safe batch RPC in 0006. 58 Node tests and TypeScript pass; 40 SQL checks, full build and browser acceptance pending. See work-card-save.md.

- Lead contact acceptance: user confirmed 0005 applied successfully, 32 checks/0 failed, full production build and dev restart. Test Lead saw Add contact, added Test Site Contact with name only, returned to job, and refresh retained it with no edit/removal controls. Helper direct /contacts/new was blocked and returned to /jobs. Direct lead contact-edit denial, PM compatibility retest and unrelated/reassigned lead browser checks remain pending (SQL covers these boundaries).

- Inline work editor: initial new client-export error cleared after restart guidance. User confirmed Cancel discarded Cancel test without navigation; Save renamed Whole job to Kitchen cabinets while retaining Test Lead, showed success and stayed on the page. Refresh retained both. Test Lead signed in and saw the job with Kitchen cabinets/Test Lead read-only. User then requested leads be able to add job contacts. Implemented role/scoped creation in migration 0005, pending application and 32 SQL checks; edit/removal stays PM-only. See lead-contacts.md.

- Work ownership: user confirmed migration 0004 success, 58 SQL checks with no failures, full production build including new/edit work routes, and dev restart. Screenshot showed Whole job unassigned with PM controls. Created synthetic lead.test@example.com, UID 1a2a2899-001a-40a3-b7ef-824a35b4df22, active lead profile named Test Lead. User confirmed Test Lead appeared and saving its Whole job assignment returned to the job with the lead shown. Refresh persistence and lead-account access checks remain pending. Existing work ID is 4ab35793-a540-48e3-983c-8d20fe4aed57. User requested inline PM work/lead editing to reduce clicks; implemented, browser acceptance pending.

- Password change: helper confirmed mismatched confirmation rejected, wrong current password rejected, correct change redirected to sign-in with success notice, old password rejected, new password signed in successfully, and signed-out /account redirected to sign-in. Passwords remained private. Cancel, real deactivation, phone and interrupted-write/browser tests are still pending.

- Attachments: user confirmed upload returned to the job and listed the test file, download opened correctly and matched the original, file remained after refresh, removal succeeded and remained removed after refresh. Unassigned helper direct upload route was blocked. This is actual desktop Storage/browser evidence; file format and size were not recorded. Assigned-helper download, anonymous download, URL expiry, transfer interruption/retry, invalid/oversize input and real phone/HEIC acceptance remain unverified in the browser.
- Josh admin/PM account: initial sign-in, job create/detail, refresh persistence, logout protected-route redirect and sign-in again passed.
- Fictional job: 2b2fa044-12b5-4ce8-9f6a-e2de614a84f2 (Test Customer One). Phone was changed to 309-555-0102 during two-tab checks; another tab's scope-only save preserved it.
- PM editing: scope/access note save/refresh, clear optional notes, cancel and invalid phone 555 checks passed.
- Synthetic helper helper.test@example.com, UID 8d91ac92-7ff3-4a2c-ac04-b7ca31d82184: empty assignment list/no create button; direct job detail, new-job and job-edit access denied.
- Contact Test Spouse (dbb6527e-0bae-4998-a0f8-04c7b6ea65b6): add/call-text display, refresh, clear notes, invalid phone and cancel preserving saved phone 309-555-0103 passed. Original removal archived it but showed Job unavailable at its edit URL.
- Fix in 64609f0: archive ends in a server redirect to the job, with a separate action state that preserves framework navigation. No SQL change.
- On resume, user confirmed Test Spouse absent, created Test Removal, then confirmed removal returned to the job without error and remained absent after refresh. Main customer contact retention was requested but not separately explicitly confirmed.
- Helper contact create and edit routes both blocked and returned to /jobs. The tested edit URL referred to an archived contact; SQL fixtures separately cover active contact permissions.
- Actual call/text/email dispatch, live assigned-helper browser reads, contact same-field conflict behavior, session expiry, live deactivation and phone usability remain unverified. No test messages/calls were sent.

## Constraints and pending inputs

- Baseline: Eigsti Architecture and Development Handoff v1.0 (previously read in full), one development chat and repository records.
- Company domain eigsticonstruction.com confirmed; someone else manages DNS. Custom SMTP is off. User deferred email invitations/self-service password recovery to post-pilot (their Phase 2 list); manual provisioning/reset is permitted for the pilot. App URL, production hosting/backup ownership, pilot participants and phone review remain pending.
- Approved calendar default: Monday-Friday 07:00-15:30, split at noon, America/Chicago; holiday/overtime exceptions remain to define.
- Attachment implementation uses the existing proposed 10 MiB default and adds original HEIC/HEIF following user confirmation of direct iPhone use. Real iPhone picker/upload/download acceptance remains pending. No conversion/scanning service, cleanup/purge or storage-usage warning is implemented.
- No paid provisioning or production data authorized. Phase 0 is not complete.
- Prior agent builds encountered Windows cleanup permissions; user builds succeeded. OneDrive bulk-deletion prompts showed generated files but full target lists were not inspected. Do not approve unreviewed bulk deletion.
- Agent loopback/browser access was unavailable in earlier work. User screenshots and confirmations supply the browser evidence.

## Exact next action

Run final production build in normal user PowerShell after stopping dev, then commit/push all outstanding visit, inline card, sign-out and documentation changes. Applied 0008 passed 60 SQL checks; 0009 passed 38 SQL checks. Latest Node suite: 79 passed, TypeScript passed. Core desktop checks passed as recorded below. Do not rerun applied 0001-0009. Latest uploaded checkpoint remains 6285665 until the new push is confirmed. Phone, real concurrent database, fault and recovery checks remain separate pilot gates.

To pause: Ctrl+C stops dev; commit/push outstanding changes, then close PowerShell/browser. Database data persists independently. To resume: npm.cmd run dev from the workspace and http://127.0.0.1:4310. GitHub is the implementation checkpoint destination; the older Library recovery ZIP predates current work.

## Queue acceptance checkpoint, 2026-10-22

User confirmed 0007 applied; corrected test-only integer assertions, then 58 checks/0 failed; full production build including /queue passed. PM two-row display, Up/Down, Cancel, Save/idle and refresh passed. Test Lead saw the PM order and saved a new order retained after refresh. Helper direct /queue blocked and redirected to /jobs. PM unassigned countertops: only cabinets remained. Reassignment appended countertops after cabinets. Both portions now belong to Test Lead. These are desktop/user-reported checks; simultaneous database races and phone/fault acceptance are not established.

## Visits/staffing/calendar prepared, 2026-10-22

User clarified no mandatory time slots: a lead may place several jobs on a day. Implemented default date-only plans with shared-day workload warnings, optional reserved half/all-day or timed slots, PM roster replacement, coordinating-lead vacancy filling, helper access maintenance, cancellation, day list and weekly calendar. 70 Node tests and TypeScript pass. New 0008 and its 60 SQL checks, full build, browser, phone and real concurrent database acceptance are pending. Existing 0001-0007 unchanged. See scheduled-visits.md.

## 0008 applied and inline visit revision, 2026-10-22

User reported SQL migration success, 60 checks/0 failed and full build. Two date-only visits persisted after refresh and appeared in PM day/week views; shared-day notice did not block save. Cabinet visit f0140e1b-9f05-40e5-872a-591ef9d0902d now requires 1 helper; actual helper assignment remains unconfirmed. User requested inline editing throughout to reduce clicks. Job/schedule visit cards now expand date/help/staffing/cancellation controls; lazy scoped reads, independent request identities and local Cancel. Existing deep links redirect to job card. No new SQL; applied 0008 is unchanged. Next verify inline display and staffing, then full user build and commit/push. New UI browser/build checks remain pending. See D40 and scheduled-visits.md.

## Combined visit card prepared, 2026-10-22

User confirmed inline controls open on job details, then reported Test Helper unselectable and requested one Save instead of dates/staffing saves. Exact disabled-checkbox gate was not observed. Shared draft now uses current helper need, adds capacity on selection and leaves saved-time busy flags informational until final transaction validation. New 0009 combines date/need/roster changes atomically, preserving lead roster restrictions and old-retry safety. 77 Node tests/TypeScript pass; 38 SQL checks prepared, unapplied. Named helper acceptance and post-inline full build remain pending. No applied migration changed. See visit-card-save.md.

## Combined card verified; sign-out retest pending

User reported 0009 applied, 38 checks/0 failed and full build. Cabinet inline editor now permits Test Helper and shows one Save/Cancel pair. Save/refresh retained Test Helper helping with 0 helper spaces vacant. User then reported sign-out seemed locked. Root cause unconfirmed; bounded auth logout to 8 seconds with cancellation, read-only SDK cookies, guaranteed current-project cookie clearing and pending button feedback. Other project cookies remain untouched. Remote logout remains best effort on outage. Retest sign-out, helper personal schedule and assigned job access next; then remaining lead protection, Cancel/conflict and final build. All visit changes still await Git commit/push; latest uploaded checkpoint 6285665. No SQL rerun needed.

## Helper schedule investigation

After restarting dev, user confirmed sign-out reached /login. User then reported no helper entries in day/week schedule, including other weeks checked. No root cause established; a date-filter assumption did not resolve it. Need compare saved visit dates, participant identity and helper profile against the signed-in test account before modifying access rules. User requests empty calendar wording No jobs scheduled; wording changed locally. Combined Test Helper selection and saved/refresh persistence were previously user-confirmed; helper personal schedule and assigned job reads remain unverified.

## Helper and lead browser checks confirmed

User clarified the helper had not actually been assigned during the empty-schedule investigation. After saving the assignment, the helper schedule showed the job. Helper opened the job and confirmed read-only details with no editing controls. This resolves the reported empty schedule as missing assignment; no access/query defect was established. Read-only diagnostic screenshot showed two planned entries for October 23, both described as countertop installation, then only leading participants; do not retain the earlier assumed October 26/cabinet distinction as actual data evidence. User then signed in as Test Lead: existing Test Helper checkbox was disabled, enforcing no removal of named staffing. Editing Helpers needed and Plan then Cancel restored both saved values. Sign-out reached login after local dev restart; exact cause of prior stall remains unproven. Remaining immediate checks: explicit time conflict and restoration, final normal-user build after sign-out/wording changes, commit/push all local visit work. Phone, simultaneous database races and fault acceptance remain separate pilot gates.

## Explicit overlap and restored state confirmed

As PM, user set one of the same-day entries to Morning and saved, then attempted Morning on the other and confirmed the scheduling conflict message. Cancel discarded the rejected draft; first entry was returned to No time set and saved. User confirmed both entries show No time set in a newly opened job page. This supplies fresh-page persistence evidence despite uncertainty about the browser refresh control. Existing helper assignment/personal schedule/read-only access, lead locked helper selection and whole-card Cancel checks passed earlier. Final build after sign-out/wording edits and Git commit/push are next; not yet claimed complete.

Final user production build passed after all visit-card, sign-out and empty-calendar wording changes (including /schedule and /visits/[id]). Database suites 0008: 60/0 and 0009: 38/0, Node 79/0, TypeScript and recorded core desktop checks passed. Next action is commit/push all outstanding changes through user PowerShell. Not yet backed up beyond uploaded 6285665.
