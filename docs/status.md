# Current status

Updated 2026-10-21. Initial app, PM editing and additional job contacts have passed the checks recorded below. Phase 0 exit and remaining Phase 1 work are still pending. No production deployment.

## Checkpoint

- Workspace: C:\Users\jrbla\OneDrive\Projects\ChatGPT\Eigsti Scheduling
- Branch: phase-0-foundation
- Latest confirmed uploaded commit: 64609f0 (contacts and removal navigation fix). Prior editing checkpoint: 018a1d2. This subsequent verification documentation is not yet committed.
- Private origin: https://github.com/jblazier77/eigsti-scheduling.git
- Test Supabase project: vglhojtrccygjgupxsrd, Free plan in Eigsti Construction organization.
- User PowerShell manages commits/pushes because agent Git writes remain restricted.
- User stopped dev for the latest successful build. No restart since that build is confirmed. Browser was last signed in as the synthetic helper.
- Keep .env.local ignored. No passwords, tokens or administrative secrets are recorded here.

## Verified implementation

- Standalone individual password sign-in/sign-out; cookie session handling and live account checks; no Google integration.
- PM My Jobs/All Jobs, three-field create plus default work item, authorized job details and phone/directions links.
- PM editing of title/customer/phone/address/scope/access notes; narrow updates preserve unrelated fields. Optional notes clear; invalid phone retains form; cancel discards changes.
- Additional contacts for a single job, including customer-side/site/trade contacts. Name required; relationship, US phone, email and shared notes optional. PM add/edit/archive, authorized job readers, call/text/email links, narrow changes, audited soft removal and retry-safe creation. Maximum 100 active contacts per job.
- No connected staffing/scheduling, private attachments, global trade directory or complete invitation/recovery/account administration yet.

## Database and automated evidence

- Applied migration 0001: user reported SQL success and 35 checks, 0 failed.
- Applied migration 0002: user reported SQL success and 60 contact checks, 0 failed.
- Both SQL suites use synthetic transaction fixtures and roll them back. Cloud SQL evidence is user reported; the agent did not run a local database.
- Do not edit or rerun these applied migrations on the existing project. Future functional SQL changes require new ordered migrations.
- Latest automated Node suite: 34 passed, including removal action navigation, uncertain failure and helper denial regression checks. TypeScript passed.
- Latest full production build AFTER the removal fix passed in user PowerShell: compilation, TypeScript, page generation/optimization and all contact routes.
- Fixture generator and prototype structural smoke checks previously passed. Those are separate from real database/browser evidence.
- PostgreSQL version/full TAP transcripts, clean-reset repeat and simultaneous multi-connection tests remain pending. Earlier sequential retry and stale-form checks are not concurrent-transaction proof.

## User browser evidence

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
- Attachment policy is still proposed: 10 MiB JPEG/PNG/WebP/PDF with iPhone HEIC review pending.
- No paid provisioning or production data authorized. Phase 0 is not complete.
- Prior agent builds encountered Windows cleanup permissions; user builds succeeded. OneDrive bulk-deletion prompts showed generated files but full target lists were not inspected. Do not approve unreviewed bulk deletion.
- Agent loopback/browser access was unavailable in earlier work. User screenshots and confirmations supply the browser evidence.

## Exact next action

Commit/push this final contacts verification documentation through user PowerShell. Code/fix is already uploaded as 64609f0, full final build and removal/helper route retests now passed. Then begin the next bounded Phase 1 item: private job attachments after resolving the pending format/size policy. Account lifecycle and remaining access/session/recovery checks follow. Do not recreate accounts, repeat migrations or duplicate the fictional job.

To pause: Ctrl+C stops dev; commit/push outstanding changes, then close PowerShell/browser. Database data persists independently. To resume: npm.cmd run dev from the workspace and http://127.0.0.1:4310. GitHub is the implementation checkpoint destination; the older Library recovery ZIP predates current work.
