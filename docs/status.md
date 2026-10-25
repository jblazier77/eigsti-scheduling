# Current status

Updated 2026-10-24. This page supersedes older pending/checkpoint statements in [the preserved history](history/status-before-pilot-2026-10-24.md).

## Checkpoint

- Latest confirmed committed/pushed code: **078ef7d**, phase-0-foundation (Prepare pilot hosting, recovery tools and compact phone UI). Subsequent backup diagnostic/query fixes and checkpoint notes are local and uncommitted.
- Isolated fictional-data Supabase project: **vglhojtrccygjgupxsrd**; migrations **0001-0016 applied** by user-reported guarded results. Do not rerun applied migrations or bundles.
- No production host, paid provisioning, real-customer pilot release or daily offsite schedule is claimed.
- User reported employee name editing/deactivate/reactivate worked. Hosted existing-session revocation and other unreported checks remain pending.

## Prepared locally

D62 compact phone UI: visible selected scopes, PM scope choices, inline crew/material pencils, compact subcontractor contacts, direct notes, linked job/queue headings and smaller spacing/bottom navigation. Existing role/data/command behavior is retained; actual phone/tablet acceptance remains pending.

D63 pilot preparation: Vercel configuration/Node 24, test/pilot label with preview-production guard, employee/subcontractor cookie-refresh coverage, independent operator-only encrypted database/Auth/private-file packages, archive verification/extraction, read-only readiness SQL, anonymous HTTPS host checks and secret-free GitHub CI. No new schema migration. See [one grouped handoff](pilot-handoff.md), [recovery procedure](pilot-recovery.md) and [release record](pilot-release-record.md).

## Verified this session

- **190 Node checks pass, 0 failed**, including recovery corruption/wrong-key/path/checksum/missing-file handling, snapshot-to-export/file pipeline with injected transports, host failure/denial cases and session/config regressions.
- **TypeScript passes** for the final source.
- A fresh isolated production build completed compilation, TypeScript and page generation before the final preview-guard/build-runner refinement.
- The final isolated repeat compiled and typechecked but was blocked by Windows **EPERM mkdir** during _not-found prerender. Earlier old-cache clearing also hit EPERM. This is not recorded as a final successful production build. Ordinary-PowerShell or prepared Linux CI must complete the release build.
- Native rename is rejected even for a fresh temporary file in this agent sandbox. Recovery package tests verify content; the positive pipeline test injects the atomic publisher. Actual native publication, PostgreSQL export, offsite copy and managed restore are NOT verified.
- No customer data, provider password, service-role key or backup passphrase was accessed for this work.

## Next grouped work

1. Save/push this batch in ordinary PowerShell; check prepared CI (not yet run remotely).
2. Company hosting/pilot project/environment and independent backup account access; review actual cost before upgrading.
3. Operator live export/offsite/isolated restore and daily runner setup; read-only readiness SQL.
4. One consolidated hosted phone/access/staffing/concurrent-save review, owner acceptance and Production pilot-mode switch.

All account/operator/device instructions are in pilot-handoff.md. Keep the existing planning process available and use fictional data until the release gates are accepted. SMTP/email invites/self-service recovery remain deferred; no Google integration or daily completion-reporting UI.

## Pilot setup evidence, October 24

User confirmed commit 078ef7d pushed to phase-0-foundation. Provided GitHub screenshot reports Validate scheduling app succeeded, including npm ci, tests and the full production build; this resolves the earlier final-build gate for that commit. User reported all ten read-only database readiness checks PASS. Supabase server_version is 17.11 and user supplied successful psql/pg_dump/pg_restore 17.11 output from C:/Program Files/PostgreSQL/17/bin. Vercel Hobby team eigsti-construction and repository installation/import settings are prepared, but Create Project/deployment is on hold until Pro activation; unsubmitted variable entries are not assumed durable. Local operator configuration is ignored by Git; no connection password/storage secret has been supplied in chat. Actual backup/publication/offsite/restore and pilot approval remain pending.

Backup setup follow-up: owner selected private OneDrive storage for encrypted archives alongside the existing OneDrive-hosted private settings (outside the Git code directory for archives). Cloud sync/download verification remains pending; no independent account-failure protection or always-on scheduler is inferred. The first user-run backup:create failed with the old generic message; no complete package is confirmed. Local checks found valid configuration, all three executable paths, root certificate and output directory present. Added fixed-code diagnostics, credential-safe stage reporting and a read-only source probe; all nine targeted recovery/diagnostic tests pass. Diagnostic and notes are local/uncommitted after 078ef7d. Await ordinary-PowerShell connection/snapshot diagnostic results.

Latest user diagnostic: secure database connection PASSED after the secure password update; do not request another password reset. The held snapshot failed with a previously unclassified error. Found an operator-query defect: unknown text marker concatenated to jsonb can resolve to jsonb concatenation. Both sides now explicitly cast to text; timeout/format/schema/value failures also have fixed credential-safe codes. No migration/grant/source-data change. Live snapshot recheck and complete export/restore remain pending.

## First live encrypted backup succeeded

User supplied successful ordinary-PowerShell diagnostic and backup:create output on October 24, 2026 (archive UTC timestamp October 25). Secure connection, held read-only snapshot and file inventory passed. Full database export, database archive inspection, private file-byte copying, encryption, archive verification and native final publication completed. Report: format 1, project vglhojtrccygjgupxsrd, 3 archive files, 1 storage object, integrity_verified=true, database_restore_verified=false. This supersedes earlier pending live-export/native-publication statements. Detailed archive identity remains in the private operator output, not this release record. OneDrive cloud download verification, isolated restore/sign-in, daily runner, hosted deployment and pilot acceptance remain pending. No password reset or schema migration is needed for this result.

OneDrive cloud-copy verification: user downloaded the published archive through OneDrive web to Downloads and ran verify-backup.mjs successfully. Format 1, same run ID, 3 files and 1 storage object; SHA-256 exactly matches original creation report. integrity_verified=true; database_restore_verified=false. Cloud download/integrity gate passed; isolated restore, daily runner and hosted pilot gates remain pending.
