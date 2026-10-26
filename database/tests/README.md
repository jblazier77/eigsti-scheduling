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

## Work ownership suite (58 checks passed in test, user reported)

After applying 0004 once, run 0004_work_ownership.test.sql. It creates only rolled-back synthetic fixtures, with 58 assertions and a missing/failure guard. Covers PM-only directory/create/update, raw write and forged parent/field denial, active-lead validation, replay/collision, assigned read access, remaining-portion access, reassignment revocation across job/contact/ready-file metadata, live deactivation, narrow patch preservation, no-op audit and 100-work limit. Not actual binary Storage, a concurrent multi-connection test or browser acceptance.

User explicitly confirmed all 58 work ownership checks, 0 failed after successful 0004 application. Original work production build also passed separately. Inline editor and remaining role/portion browser checks remain separate evidence.

## Lead contact creation (32 checks passed in test, user reported)

Run 0005_lead_contact_creation.test.sql after 0005 application. Synthetic data rolls back; a guard rejects failures/missing assertions. Covers authorized/unrelated/revoked/deactivated leads, helpers/admin-only/anonymous denial, own-contact edit/removal denial, attribution, retry/collision, no resurrection, PM compatibility and limit. Existing 0002 helper/inactive create-denial assertions were relaxed only from exact old PM-only message to SQLSTATE 42501 for cross-version compatibility; no rerun of those older assertions is claimed. User confirmed all 32 new checks passed after 0005 application; full build and recorded browser checks also passed separately. See docs/lead-contacts.md.

## Work card save (40 checks passed in test, user reported)

Run 0006_work_card_save.test.sql after 0006. Fixtures roll back and a 40-result guard rejects missing/failed assertions. Covers earlier valid edit/audit/receipt rollback on later invalid lead, cross-job or completed work, role denial, batch validation/count, canonical replay/collision, narrow changes preserving newer fields, old retry preserving a newer save, current retry response and closed-job behavior. No actual multi-connection or browser evidence is claimed.

User confirmed all 40 batch/card SQL checks passed after 0006 application. Full production build and basic card display/Cancel passed separately. Save completion UI correction awaits browser/full-build retest.

## Lead queues (58 checks prepared; NOT executed)

Run 0007_lead_queues.test.sql after 0007. All synthetic fixtures roll back; 58-result guard checks complete pass. Covers roles/raw RPC boundaries, exact membership, malformed/bounded arrays, sequential two-PM latest-save behavior, unrelated contact retention, order/actor history, old retry safety, own-lead save, no-op and automatic membership lifecycle. Not a simultaneous two-connection test. Before pilot race actual queue saves and reassignments on distinct connections and inspect final state/history/contact preservation. See docs/lead-queues.md.

0008_scheduled_visits.test.sql: 60 prepared checks, NOT run; requires 0001-0008. Synthetic fixtures roll back. Tests optional times, explicit conflicts/rollback, roles/rosters/access/retries/calendar/scope; single connection only. Full user build/browser/concurrent/phone acceptance remains separate.

0008 user-reported result: 60 checks/0 failed. New 0009_visit_card_save.test.sql: 38 prepared checks, NOT run, requires 0001-0009; fixtures roll back.

0010_completion_and_returns.test.sql: 60 prepared checks, NOT run. Requires 0001-0010; standalone tests roll back. User bundle database/batches/0010_completion_and_returns.sql wraps new DDL plus this exact suite under a savepoint, rolls back fixtures then commits DDL only after all checks pass. Node packaging test verifies boundaries.

Combined acceptance: database/batches/0010_0011_combined.sql runs 60 completion/return and 51 job-tag/trade assertions, validates every result, and rolls back both fixture suites before committing ordered DDL. 111 checks are prepared, not confirmed executed. Standalone 0011_job_tags_and_trades.test.sql is rollback-only and assumes the schema is already applied; use the combined update for this initial rollout, not both alternatives. See docs/combined-batch.md.

0012_work_planning_and_materials.test.sql adds 42 isolated checks for atomic optional-date creation, retries/rollback/conflicts, material status/estimates, role/ownership/deactivation, RLS and audit. Live execution is pending. Prefer the new guarded 0012 bundle, which removes synthetic fixtures before committing DDL. Prior 0010/0011 are already applied; do not rerun them.

0012 live-check correction: initial test run stopped on protected visits-table SELECT. Test assertions now use the authorized list_job_visits RPC through a temporary invoker-only reader; no table grants or app behavior changed. Regenerated guarded 42-check bundle. Still NOT applied/verified until the revised live run succeeds. Recopy the file, replace the SQL editor text and retry the guarded bundle; do not grant direct table access.

0013_quick_work.test.sql prepares 33 isolated checks for one-save work/date/help/material creation, undated requirements, rollback/idempotency/conflicts, role boundaries and audit. Uses the authorized schedule RPC rather than direct visits reads. Live execution is pending; use only the guarded 0013 bundle after applied 0012.

0014_subcontractor_commitments.test.sql contains 48 prepared rollback-only checks for optional promises, atomic contact creation, idempotency, scoped roles, calendar isolation and archived history. Prefer the one-time guarded 0014 bundle after 0013; no live 0014 results are claimed yet.

0014 is APPLIED in isolated vglhojtrccygjgupxsrd: user confirmed 48 checks, 0 failed and synthetic fixtures removed after schema commit. Do not rerun the 0014 bundle or older updates. This supersedes earlier pending-0014 notes.

0015_job_archive.test.sql: 35 prepared checks for archive guards, preservation, restore/additional work, stale retries, roles, calendar/queue behavior and private history. Live execution remains pending; use the guarded 0015 bundle after 0014.

0015 is APPLIED: user confirmed expected guarded result (35 checks, 0 failed, synthetic fixtures removed). Do not rerun its bundle or previous updates; earlier prepared/pending statements are superseded.

0016_employee_management.test.sql: 33 prepared rollback-only checks for role boundaries, live deactivation, reactivation/retry safety, stale edits, self-protection, staffing-role eligibility, private snapshots and profile-data minimization. Live SQL results are pending. Prefer guarded 0016 after applied 0015.

0016 application reported successful by user following the expected 33-check guarded update. Do not rerun 0016 or earlier bundles. Employee-screen/browser verification remains separate and pending.

0017_planning_review.test.sql: 53 prepared rollback-only checks for priority/estimates, PM/lead/helper boundaries, partial/filled help and atomic setup/retry. Live results pending. Prefer the guarded 0017 batch.

0017 is now APPLIED: user confirmed 56 checks, 0 failed on October 26. Earlier pending statements are superseded. Do not rerun its bundle or older updates. Browser acceptance remains separate.

0018_unified_work_editor is PREPARED, NOT APPLIED. Use the guarded database/batches/0018_unified_work_editor.sql once after applied 0017. It contains 27 synthetic rollback-only checks and an atomic whole-work-card save command. Never rerun applied 0001–0017.

0018 APPLIED: user confirmed the expected guarded result (27 checks, 0 failed, synthetic fixtures removed). This supersedes earlier pending/application-failure notes. Do not rerun 0018 or earlier updates. Combined work-card browser acceptance, ordinary-PowerShell final build confirmation and commit/push remain pending.

0019_first_save_helpers is PREPARED, NOT APPLIED. Use database/batches/0019_first_save_helpers.sql once after applied 0018. It contains 25 guarded rollback-only checks for scoped staff lookup, atomic first-save staffing, retry/rollback and role boundaries. Do not rerun 0001–0018.

0020_employee_accounts: prepared, not applied. Service-only enrollment for administrator-created Auth accounts. Use guarded database/batches/0020_employee_accounts.sql once after applied 0019; 12 checks and fixture cleanup. Do not rerun 0001-0019.

0020 APPLIED: user confirmed the expected guarded result (12 checks, 0 failed, 0020 applied; synthetic fixtures removed) on October 26. Do not rerun 0020 or earlier migrations. Administrator Add employee is ready for grouped browser acceptance: create a fictional helper, confirm Employees and staffing visibility, and verify sign-in with the temporary password. Local tests/build passed; browser acceptance and commit/push remain pending.

0021_new_job_helpers prepared, not applied: 15 guarded checks, fixtures rolled back before commit. Apply once after applied 0020. Full new-job crew selection, same authenticated PM command and existing receipts.

0021 APPLIED: user confirmed the expected guarded result (15 checks, 0 failed, 0021 applied; synthetic fixtures removed) on October 26. Do not rerun 0021 or earlier migrations. Full new-job helper multi-select is ready for browser review. 223 Node tests, TypeScript and final isolated production build passed; browser acceptance and commit/push remain pending.

0022_unassigned_scheduled_work is prepared, not applied. Apply guarded batch once after applied 0021; 28 checks and synthetic cleanup. PM may retain scheduled date/helper crew without a lead.

0022 APPLIED: user confirmed 28 checks, 0 failed on October 26 after reviewing the Supabase destructive-operation warning. Guarded batch enforces synthetic fixture rollback before commit. Do not rerun 0022 or earlier migrations. PM can retain scheduled dates and named helpers without an assigned lead; Lead needed warning and later assignment are ready for grouped browser acceptance. 228 Node tests, TypeScript and isolated production build passed. Browser acceptance and commit/push remain pending.

0023_saturday_work prepared, not applied: 16 guarded checks. Apply once after applied 0022. Saturday scheduling and multi-day reservations, with Sunday excluded.

0023 APPLIED: user reported the Saturday update worked as expected after the guarded instructions (16 checks, 0 failed, synthetic fixtures removed). Do not rerun 0023 or earlier migrations. Saturday scheduling is enabled; multi-day work includes Saturdays and skips Sundays. No separate Saturday browser save/calendar confirmation or commit/push is inferred from the SQL acknowledgment. 230 Node tests, TypeScript and isolated production build passed.
