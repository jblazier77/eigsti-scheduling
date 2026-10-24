# Current status

Updated 2026-10-24. This page supersedes older pending/checkpoint statements in [the preserved history](history/status-before-pilot-2026-10-24.md).

## Checkpoint

- Latest confirmed committed/pushed code: **0b5b259**, phase-0-foundation (Add verified employee access management). Current D62/D63 changes are LOCAL and uncommitted.
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
