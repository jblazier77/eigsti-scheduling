# Pilot recovery procedure

Prepared tooling; a LIVE export/restore has NOT passed. Do this in the isolated fictional-data project first. Do not enter real customer data until the release record is accepted.

## Scope and safeguards

`backup:create` exports the full PostgreSQL database in custom format, including app/private schemas, Auth records and ACLs. A held repeatable-read snapshot supplies BOTH the dump snapshot and the file inventory. Every physical object in the `eigsti-job-files` bucket is downloaded, including retained/archived files; every ready app-file record must match an object and its size. Other buckets, provider settings, root encryption keys, external credentials, cluster-global roles/passwords and hosting settings are NOT captured. Use a dedicated Eigsti project and maintain provider configuration/recovery material separately in the company password manager.

The archive uses authenticated AES-256-GCM encryption with a scrypt-derived key. Database bytes, file bytes and manifests are encrypted together. A file is published only after complete extraction/authentication and SHA-256 checks pass. The package contains sensitive Auth recovery information; it is not a customer-friendly data export and must remain operator-only. Passphrase length is at least 32 characters; use a randomly generated password-manager secret kept separately from backups.

No script changes database grants, drops a database, restores into a live project or deletes source files. Operator commands never use the web app's employee credentials. Privileged secrets are not imported into Next.js. Individual app requests continue using their own identities and row policies.

Current tooling is for a small pilot: at most 10,000 file objects, 10 MiB each, and 64 GiB of total archive content. Allow roughly four times the package size in temporary/output disk space during creation/verification. PostgreSQL commands and object downloads have timeouts. Do not run an unattended long export against heavy production load without measuring it.

## Private setup once

1. Install `psql`, `pg_dump` and `pg_restore` matching the server's major version. They are not installed in this agent environment. Session-pooler port 5432 is supported; transaction-pooler port 6543 is rejected. Direct database host requires working network/IP support.
2. Copy the blank `.env.ops.example` to ignored `.env.ops.local` in the local checkout. Set source reference, its database connection, separate source storage secret, randomly generated passphrase and an absolute private output directory OUTSIDE this repository. Use password-manager/operator setup; do not paste secrets into chat. Database-URL password characters must be URL-encoded.
3. Set the provider root certificate through `EIGSTI_DB_ROOT_CERT` as needed. Connections require `sslmode=verify-full`; do not fix certificate failures by disabling verification. Protect the private directory with the operator's OS access controls; Windows mode bits alone do not establish a private ACL.
4. Keep `.env.ops.local` off Vercel, source control, shared/public folders and support logs. `backup:check` checks configuration/tool availability only, not database access or backup completeness.

Commands below run in ordinary PowerShell from the project folder, never SQL Editor:

```powershell
npm.cmd run backup:check
npm.cmd run backup:create
```

Only a zero exit status plus the final JSON with `integrity_verified: true` confirms a verified package was published. Keep its full path, project reference, run ID, SHA-256 and timestamp in the private recovery log. Output deliberately says `database_restore_verified: false`. Do not treat a `.partial` file as a backup.

```powershell
npm.cmd run backup:verify -- "C:\PrivateCompanyBackups\RUN.eigsti-backup"
```

Use the ACTUAL path from backup:create, not the example. Upload the encrypted package to an approved separate private company backup store. Download it to another approved private location and rerun backup:verify; compare SHA-256 to the creation report. Source availability or a local sync icon is not proof of offsite recovery. No cloud backup account/upload/scheduler has been configured here.

Daily backup scheduling belongs on an always-on company runner with private operator secrets, failure monitoring and last-success checks; it must not depend on Josh's laptop being awake. Recovery-point target is no more than 24 hours; measured restore time is still unknown. Retain 30 days of complete verified archives and test recovery monthly. The current package is a full copy on each run, not incremental/deduplicated storage. Recalculate storage/transfer costs from measured archive sizes. No automatic expiry/deletion is implemented; do not delete retained bytes based on current app removals.

## Isolated restore drill

Provision a disposable, separate Supabase environment compatible with the source. Verify its project reference differs from the source before ANY restore. Stop writes only in that target. Preserve a target backup if it is not empty. Do not experiment with pg_restore against the pilot/source.

Extract to a NEW private folder outside the checkout:

```powershell
npm.cmd run backup:prepare-restore -- "C:\PrivateCompanyBackups\RUN.eigsti-backup" "C:\PrivateCompanyRecovery\NEW-RUN"
```

The parent directory must already exist. Extraction authenticates first, never connects to a database, and never overwrites an existing destination. An extraction failure is NOT a verified recovery; any partial destination must be treated as private unverified material and removed after diagnosis.

A PostgreSQL/Supabase operator must inspect `pg_restore --list` and the current provider migration guidance before applying a recovery plan. The full archive is not a blind import into an already initialized managed Supabase database: managed auth/storage schemas, ownership/ACL role mappings, extensions, provider encryption/root keys and service settings require review. Source Auth password hashes are sensitive; restoring their rows alone does not prove users can sign in on another project. Use the provider-supported roles/schema/data migration path or an operator-reviewed same-version recovery target, with existing app/private migrations and policy objects reconciled. Do not claim readiness until an actual compatible restore is demonstrated. The extraction helper intentionally does NOT automate database restoration or storage upload.

Restore job-file BYTES through the target Storage API into the private bucket using immutable `job-id/file-id` keys from the manifest, checking sizes/hashes. Database metadata rows alone do not recreate files. Reconcile `storage.objects` metadata and app file statuses with the actual target bytes; do not bypass Storage by writing random files to its database tables. Make the final target match the snapshot. Do not enable overwrite/delete on the source to make a restore easier.

Then verify every manifest file hash, source/target counts, identities/relationships, queues, visits/staffing and commitments. Sign in as fictional admin/PM/lead/helper, open one whole job, download its photo/PDF and exercise unauthorized direct URLs. Record target reference, archive run/hash, counts, failures, elapsed time and operator in pilot-release-record.md. Destroy the isolated test resources and private decrypted working copies only after the operator approves cleanup. Retain the encrypted recovery archive and separate passphrase.

## Evidence limits

Automated tests exercise encrypted binary round trips, corruption, wrong keys, unsafe paths, manifest mismatch, incomplete downloads, inventory mismatch and no publication after a failed file copy. A synthetic end-to-end export uses injected PostgreSQL/storage/publisher transports. Native rename is denied by this agent's Windows sandbox even for a fresh temporary file; actual atomic publication must be checked in ordinary PowerShell. None of these tests prove a LIVE PostgreSQL export, offsite upload, native publication on the operator machine or managed Supabase restore.

Provider references, checked 2026-10-24:

- https://supabase.com/docs/guides/platform/backups
- https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
- https://supabase.com/docs/guides/platform/clone-project

## Current pilot storage choice and troubleshooting

Owner selected their existing private OneDrive for the pilot, with encrypted archives in C:/Users/jrbla/OneDrive/Eigsti Scheduling Backups outside the Git checkout. The private .env.ops.local is already under their OneDrive project folder; owner accepted retaining the generated passphrase there. Verify actual cloud presence/download and access controls. This choice supersedes the separate password-manager copy as a required step for this pilot; it does not establish resilience against losing that OneDrive account. Daily execution and managed restore remain pending.

For connection/snapshot diagnosis, run node scripts/ops/diagnose-backup.mjs in ordinary PowerShell from the project folder. It reads the source and rolls back the snapshot; no export or restore occurs. Native diagnostic text is mapped to fixed codes/messages rather than printed, and backup:create now identifies the stage that failed. Do not paste the private settings or run native commands that expose connection strings in arguments.

## Live operator evidence

The first live full database/private-file backup and native publication succeeded in ordinary PowerShell. The owner then downloaded the encrypted archive from OneDrive web and successfully verified the downloaded copy, matching the original SHA-256, 3 archive files and 1 storage object. This supersedes earlier pending export/publication/cloud-copy statements. No isolated database restore or restored-user sign-in has been demonstrated.
