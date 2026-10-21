# Current status

Updated 2026-10-21. Initial app, PM editing and additional job contacts have passed the checks recorded below. Phase 0 exit and remaining Phase 1 work are still pending. No production deployment.

## Checkpoint

- Workspace: C:\Users\jrbla\OneDrive\Projects\ChatGPT\Eigsti Scheduling
- Branch: phase-0-foundation
- Latest confirmed uploaded commit: dea0af9 (contacts final verification; prior contacts/fix 64609f0, PM editing 018a1d2). Current private attachments code/migration/tests/docs are local and not yet committed.
- Private origin: https://github.com/jblazier77/eigsti-scheduling.git
- Test Supabase project: vglhojtrccygjgupxsrd, Free plan in Eigsti Construction organization.
- User PowerShell manages commits/pushes because agent Git writes remain restricted.
- Full attachments build passed in user PowerShell; dev was restarted for browser checks. Browser is currently signed in as the synthetic helper.
- Keep .env.local ignored. No passwords, tokens or administrative secrets are recorded here.

## Verified implementation

- Standalone individual password sign-in/sign-out; cookie session handling and live account checks; no Google integration.
- PM My Jobs/All Jobs, three-field create plus default work item, authorized job details and phone/directions links.
- PM editing of title/customer/phone/address/scope/access notes; narrow updates preserve unrelated fields. Optional notes clear; invalid phone retains form; cancel discards changes.
- Additional contacts for a single job, including customer-side/site/trade contacts. Name required; relationship, US phone, email and shared notes optional. PM add/edit/archive, authorized job readers, call/text/email links, narrow changes, audited soft removal and retry-safe creation. Maximum 100 active contacts per job.
- Private attachments are implemented locally with original HEIC/HEIF, PDF/JPEG/PNG/WebP, a 10 MiB/file limit, private direct upload, scoped download and soft archive. Migration 0003, 66 SQL checks, full build and basic desktop Storage/browser checks passed per user. Real iPhone acceptance remains pending. See job-files.md.
- No connected staffing/scheduling, global trade directory or complete invitation/recovery/account administration yet.

## Database and automated evidence

- User reported migration 0003 success in the test project on 2026-10-21, then 66 checks, 0 failed after correcting assertion 37 to a top-level WITH ... INSERT ... SELECT. The initial nested data-modifying CTE failed with PostgreSQL 0A000. Test-only correction; migration is applied and must not be rerun.
- Applied migration 0001: user reported SQL success and 35 checks, 0 failed.
- Applied migration 0002: user reported SQL success and 60 contact checks, 0 failed.
- Both SQL suites use synthetic transaction fixtures and roll them back. Cloud SQL evidence is user reported; the agent did not run a local database.
- Do not edit or rerun these applied migrations on the existing project. Future functional SQL changes require new ordered migrations.
- Latest automated Node suite: 40 passed, including six file validation/role/retry/scoped signing checks and prior contact removal regressions. TypeScript passed after file changes.
- Latest full production build including file upload/download routes passed in user PowerShell. No new agent cleanup attempt is made due prior Windows/OneDrive issues.
- Fixture generator and prototype structural smoke checks previously passed. Those are separate from real database/browser evidence.
- PostgreSQL version/full TAP transcripts, clean-reset repeat and simultaneous multi-connection tests remain pending. Earlier sequential retry and stale-form checks are not concurrent-transaction proof.

## User browser evidence

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
- Company domain eigsticonstruction.com confirmed. DNS/app subdomain, production hosting/backup/email ownership, pilot participants and phone workflow review remain pending.
- Approved calendar default: Monday-Friday 07:00-15:30, split at noon, America/Chicago; holiday/overtime exceptions remain to define.
- Attachment implementation uses the existing proposed 10 MiB default and adds original HEIC/HEIF following user confirmation of direct iPhone use. Real iPhone picker/upload/download acceptance remains pending. No conversion/scanning service, cleanup/purge or storage-usage warning is implemented.
- No paid provisioning or production data authorized. Phase 0 is not complete.
- Prior agent builds encountered Windows cleanup permissions; user builds succeeded. OneDrive bulk-deletion prompts showed generated files but full target lists were not inspected. Do not approve unreviewed bulk deletion.
- Agent loopback/browser access was unavailable in earlier work. User screenshots and confirmations supply the browser evidence.

## Exact next action

Commit/push the attachments checkpoint through user PowerShell, keeping .env.local ignored. Migration 0003, all 66 SQL checks, full build and basic desktop upload/download/removal/helper upload denial passed. Do not rerun applied migrations. Guide one step at a time. Remaining phone/HEIC, near-limit transfer, retry/fault, assigned-helper and issued-URL expiry checks remain required before pilot. Account lifecycle and remaining access/session/recovery work follow.

To pause: Ctrl+C stops dev; commit/push outstanding changes, then close PowerShell/browser. Database data persists independently. To resume: npm.cmd run dev from the workspace and http://127.0.0.1:4310. GitHub is the implementation checkpoint destination; the older Library recovery ZIP predates current work.
