# Isolated database verification

The corrected schema was applied to the isolated Free Supabase test project vglhojtrccygjgupxsrd. User reported **35 checks, 0 failed** from SQL Editor. Local PostgreSQL/Docker remain unavailable. Node tests are separate evidence; real Auth, REST/Storage, clean-reset repetition and multi-connection concurrency checks remain pending.

When a synthetic-only Supabase test instance is available:

1. Record instance/project identity and verify it is not production. Use the same schema/migration path intended for production.
2. Apply `database/migrations/0001_jobs_and_access.sql` to an empty application schema. It requires Supabase's `auth.users`, `auth.uid()`, `anon` and `authenticated` roles.
3. Run `database/tests/0001_jobs_and_access.test.sql` with a privileged test connection and pgTAP available. It creates reserved-domain synthetic identities in a transaction and rolls them back. The script captures all 35 assertions in a temporary table and raises an exception on any failure or missing assertion; inspect its checks/failed summary. Retain complete TAP output when running from a CLI.
4. Capture PostgreSQL version, migration checksum and complete pass/fail output. Then repeat from a clean reset.
5. Add two-connection tests: simultaneous same-request CreateJob gives one job/work/audit; different requests remain separate; concurrent narrow patches to scope and phone both persist. A single-connection pgTAP retry is not proof of concurrency behavior.
6. Before Phase 1 exit, test actual Supabase Auth password/invite/recovery sessions, direct REST API reads/writes, and private Storage authorization/uploads on phones.

Account provisioning is deliberately not public: no user signup/role promotion RPC exists. Initial company admin/PM app profiles must be provisioned through an authorized technical process, then the phone invite/user administration flow can be implemented with separate administrative secrets kept server-side. Database Auth rows in this test are fixtures only, not usable employee accounts.

Helper `private.job_access` records are information-access entitlements, not staff reservations. Phase 2 must derive and revoke these from real visit participants transactionally before helper schedules are enabled. No UI may grant broad access just because a helper has free time.

## Contact suite (60 checks passed in test, user reported)

On 2026-10-21, after migration 0002 succeeded, the user ran this suite in Supabase SQL Editor and reported 60 checks, no failures. This is user-reported cloud database evidence, not a local agent SQL execution. Actual contact browser verification remains pending.

After migration 0002 succeeds, run `0002_job_contacts.test.sql` in a separate SQL Editor query. It has 60 pgTAP assertions and an end guard that rejects missing or failed assertions. It creates only reserved-domain synthetic identities and rolls back the entire fixture, leaving the actual Josh/helper accounts and saved test job unchanged.

Covers assigned helper/lead contact reads; unrelated, closed-job, revoked, inactive, uninvited, admin-only and anonymous denial; raw-write restrictions; PM cross-job commands; creation replay/collision; input validation; forged job/contact relationships and actor fields; narrow patches; clearing optional values; archive persistence/replay; old-create replay after archive; live deactivation; 100-contact limit and atomic rejection. Node transport tests do not establish these SQL results. Multi-connection retry/limit tests, full clean setup and actual app/REST contact checks remain separate.

## File suite (66 checks passed in test, user reported)

On 2026-10-21 user confirmed 66 checks, 0 failed after a test-only correction to assertion 37: the data-modifying WITH clause must be at the top level of INSERT ... SELECT. Migration 0003 was already applied and was not changed. Full production build and basic actual desktop file upload/download/removal/helper upload-route denial also passed separately; phone/fault/expiry acceptance remains pending.

After migration 0003 succeeds, run 0003_job_files.test.sql in a separate SQL query. All synthetic Auth/app/job/file/Storage metadata fixtures roll back. It covers private bucket configuration, assigned ready-file metadata/object reads, hidden pending/unrelated data, helper/anonymous/admin-only/inactive denial, live revocation/closure, lead-own removal, forged parent paths, validation/limits, request replay, publication after matching size/MIME, mismatch/missing-object rejection, immutable storage overwrite boundary and retained archive history.

Storage metadata rows simulate uploaded objects. They do NOT prove any bytes exist, prove binary safety or exercise HTTP capabilities. Real signed upload/download, near-limit file size, retry/fault behavior, expiration and phone HEIC tests are still required. Do not interpret fixture metadata as an actual restored file or completed backup.

## Work ownership suite (58 checks prepared; NOT executed)

After applying 0004 once, run 0004_work_ownership.test.sql. It creates only rolled-back synthetic fixtures, with 58 assertions and a missing/failure guard. Covers PM-only directory/create/update, raw write and forged parent/field denial, active-lead validation, replay/collision, assigned read access, remaining-portion access, reassignment revocation across job/contact/ready-file metadata, live deactivation, narrow patch preservation, no-op audit and 100-work limit. Not actual binary Storage, a concurrent multi-connection test or browser acceptance.
