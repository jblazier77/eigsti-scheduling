# Limited pilot handoff

Prepared 2026-10-24. Local implementation is prepared; **real customer data is not approved yet**. This is the single grouped handoff. Do not rerun migrations or guarded bundles 0001-0016.

## Completed without account access

- Phone UI simplification, compact contacts/scopes and inline crew/material editing.
- Vercel Next.js configuration, Node 24 selection and a production environment template.
- Employee/subcontractor session refresh coverage and private cache behavior.
- Explicit Test workspace / Limited pilot labels. Pilot mode requires the production environment; Vercel previews reject production configuration even with a synthetic label.
- Operator-only encrypted recovery packages containing a consistent PostgreSQL dump, database/Auth records, storage inventory and actual private job-file bytes. Contents are authenticated and checksummed before publication. Verification and isolated extraction commands are included.
- Read-only database readiness SQL and an HTTPS hosting check for anonymous data denial, private cache headers and file endpoints.
- Current validation evidence is in status.md. Prepared tooling is not evidence of an actual deployed service, live backup, successful restore or phone acceptance.

## Your part: three grouped sessions

### 1. Company accounts and hosting

Have company-controlled Vercel, Supabase and independent private backup access available, with a named recovery operator. Keep passwords, database URLs, service-role/secret keys and backup passphrases out of chat. No paid account or deployment was created here.

Use Vercel Pro for business hosting. The researched base is $20/month for Vercel plus $25/month for the first Supabase Pro project, before usage, backup storage and taxes. Additional Supabase projects in a paid organization can add about $10/month each. Keeping cloud test and restore projects may therefore exceed the earlier $47-49 estimate. Review the actual account quote before upgrading; hosting.md has links and details.

Keep `vglhojtrccygjgupxsrd` isolated for fictional tests. Provision a separate approved pilot project; apply the migration files 0001-0016 once, in order, only to that NEW empty project. Do not copy fictional employee accounts or customer records into the pilot. A clean-project schema application and backup drill remain unverified. If it fails, stop with the error rather than relaxing grants.

In Vercel, import the private `jblazier77/eigsti-scheduling` repository and explicitly choose the reviewed `phase-0-foundation` checkpoint/branch as the production branch. Set Production variables from `hosting-environment.example.txt`, using the PILOT project's actual reference, URL and publishable key. Initially leave `EIGSTI_DATA_MODE=synthetic` while testing fictional data. Do not add database passwords, operator keys or backup passphrases to Vercel. Preview gets only separate test credentials and `EIGSTI_ENVIRONMENT=test`; absent preview credentials should show setup required, never fall back to pilot values.

The supplied Vercel HTTPS address is enough initially. Company DNS and SMTP can wait. Once deployed, supply its public URL and I can run the unauthenticated hosting checks. Supabase Auth's Site URL should match the hosted origin; keep public sign-ups disabled. Individual password login is the pilot workflow; email invites/recovery and Google integration remain deferred. Review production deployment protection so intended employees can reach the login page without Vercel developer accounts.

### 2. Recovery and pilot accounts

A technical recovery operator installs PostgreSQL client tools matching the Supabase server major version, configures the private `.env.ops.local` template, and performs the procedure in `pilot-recovery.md`. Tool installation/database/storage secrets are not available in this session. The privileged storage key belongs ONLY in this separate operator configuration.

Create one verified encrypted backup, store it in the company's separate private backup destination, download it again and verify it. Restore database/Auth and file bytes into an isolated target under operator review, check counts and file hashes, and actually sign in there. Do not use blind pg_restore into a populated Supabase project. Record how long the recovery took. Neither the export nor live restore has run yet.

Configure daily offsite execution and failure monitoring on a company-controlled always-on runner, with 30-day retention and a monthly restore drill. No scheduled backup is enabled by this change. Current archives are FULL copies; the old incremental/dedup cost assumption does not apply. A synced local folder alone does not prove the offsite copy is recoverable.

Manually create individual Auth accounts and matching app profiles for the named pilot users using the existing onboarding procedure in accounts.md. Have at least one active admin and PM; verify a second recovery administrator is available. No shared staff login. Users change their temporary password in My account. Existing Employees manages profiles; it does not create Auth identities or send emails.

Run `database/pilot/readiness.sql` on the intended project as its owner. It is read-only; no migration bundle is involved. All ten results should say PASS. Keep the result with the release record. A capability check does not prove the SQL file history/checksums or runtime access rules by itself.

### 3. One grouped review and release decision

Use a real phone and desktop/tablet with FICTIONAL jobs first, on the hosted origin:

- PM creates a window job with an optional Tuesday date, help needed and In stock materials in one save; no time is required. Check saved values after signing out/in.
- Lead has their own work and helps a different lead on another entry. Both appear correctly in personal schedule; helper sees only their named assignments. An explicit time overlap must be rejected; date-only jobs may share a day.
- PM sees a staffing warning until enough named helpers are assigned. Check Day/Week/Two weeks/Month, rain/filler filters and subcontractor date flags.
- Add/download/preview/remove a photo and PDF. Check iPhone photo format if used; compact navigation must not cover Save/Cancel or the last row.
- In a separate already-signed-in session, deactivate a test user as admin, then try reads, direct job/file URLs and a write. Access must be denied on the next request. Reactivate and sign in again. Non-admins cannot manage Employees.
- Two sessions edit the same staffing/employee record. Confirm stale/conflicting edits are rejected and a failed/uncertain save preserves the draft without claiming success. Retry the same operation without creating duplicates. Refresh data after a confirmed save.
- PM archives and restores the SAME job for later punch-list work. History/files/contacts remain and no daily completion controls are required.

Record observed outcomes, including failures, in `pilot-release-record.md`; do not infer them from unit tests. Keep the existing planning method available during a small pilot. Only after recovery, hosting, access and device checks pass and the owner accepts the limited rollout, set Production `EIGSTI_DATA_MODE=pilot` and redeploy. That switch changes the workspace label; it does not itself certify readiness.

## Save this local batch before a shutdown or deployment

In ordinary PowerShell, from the project folder (not SQL Editor):

```powershell
$eigstiGit = "C:\Users\jrbla\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe"
& $eigstiGit add .
if ($LASTEXITCODE -ne 0) { throw "Staging failed. Stop here." }
& $eigstiGit diff --cached --name-only
```

Check that no private `.env.local`/`.env.ops.local`, recovery archive or customer files appear. The two blank example environment files are intentional. Then:

```powershell
& $eigstiGit commit -m "Prepare pilot hosting, encrypted recovery and compact phone UI"
if ($LASTEXITCODE -ne 0) { throw "Commit failed. Stop here." }
& $eigstiGit push
if ($LASTEXITCODE -ne 0) { throw "Backup failed. Stop here." }
& $eigstiGit status
```

Expected final status: up to date, nothing to commit. Git writes are restricted in this agent workspace, so a new pushed checkpoint is not claimed. Stop the app with Ctrl+C in the PowerShell running Next dev, answer Y if asked, then shut down normally.
