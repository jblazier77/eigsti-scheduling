# Migration contract

`0001_jobs_and_access.sql` was corrected after a CASE-expression parse error and applied through the isolated Supabase test-project SQL Editor. User subsequently reported 35 checks, 0 failed from the database suite. Further functional changes now require a new migration; do not silently edit this applied migration. It requires Supabase Auth schemas and roles. It creates users, jobs, default work, audit/retry records, private information-access entitlements, read RLS and PM-only create/update commands. It grants no raw operational writes to employee roles.

Run `database/tests/` against an isolated Supabase instance before use. Node request tests do not prove SQL correctness or database authorization. Next: apply from empty, run all pgTAP and multi-connection tests, repeat clean setup; then add contacts/private files, account provisioning and the Next.js interface. Visit/staffing tables belong to Phase 2. Every migration must include its access boundary.

Apply identical ordered migrations in isolated test and production. Do not manually patch the production schema. Seed production with configuration only; demo records belong exclusively to local/test. Recovery and backward compatibility are separate from migration execution.

## 0002: additional job contacts (applied in test)

On 2026-10-21 the user reported successful application in the isolated test project, then 60 checks with no failures from the contact SQL suite. Full contacts production build also passed in normal user PowerShell. Browser verification remains pending. The setup instructions below are a reference for a fresh environment; do not rerun this applied migration on the same project. Further functional database changes require a new migration.

Apply `0002_job_contacts.sql` once, after 0001, through a new SQL Editor query in test project `vglhojtrccygjgupxsrd`. It runs in a transaction and adds no seed data or account changes. SHA-256 at preparation: `84a57017a9ec4ba63ee3d100f0fbe6c0550c683d85ef003f7058ee23e7998c6d`.

Adds `job_contacts` with job-based read RLS, authenticated SELECT only, and PM-only create/update/archive RPCs. Names are required; relationship/trade, US phone, email and shared notes are optional. Independent SQL validation, parent job/contact matching, audit events, narrow patches and creation retry deduplication are enforced. Removal archives without erasing history; replaying an old create does not restore a removed contact. Maximum 100 active contacts per job, enforced under a parent-row lock; the read client loads all 100. This is job-local contact information, including customer-side or trade contacts, not the company trade directory or subcontractor schedule.

After success, run `database/tests/0002_job_contacts.test.sql` (60 assertions, all fixtures rolled back). Neither this migration nor its SQL tests have been run by the agent. Do not rerun 0001 on the existing project. Do not drop tables as a retry strategy; inspect any SQL error first.

## 0003: private job files (applied in test)

Apply 0003_job_files.sql once after 0001/0002 in the same isolated test project. It creates a NEW private bucket eigsti-job-files with 10 MiB and MIME restrictions, job_files metadata, job/owner read/write checks, immutable object paths, restrictive Storage object boundaries and begin/finish/archive commands. Do not create the bucket manually first. A conflicting existing bucket causes the transaction to fail safely rather than overwrite its settings.

Prepared SHA-256: 66e04b2441ad17fdd3e9d6dfccff6b4ec1ba123e09529c687ecac676a8ff6dd5. No seed data or secrets. On 2026-10-21 user confirmed successful application, 66 SQL checks with 0 failures, full production build and basic desktop Storage upload/download/removal/helper upload denial. Do not rerun this applied migration; the preceding setup description is for fresh environments only. Phone, retry/fault and other remaining acceptance checks are recorded in docs/job-files.md, along with signed URL lifetimes and cleanup/recovery limits.

## 0004: work portions and lead ownership (applied in test)

Apply 0004_work_ownership.sql once after 0001-0003 in the isolated test project. Adds scoped lead/work read RPCs, PM-only retry-safe creation and narrow description/lead edits on open work/jobs. Existing work RLS automatically derives job access from ownership; raw writes remain denied. No seed data, role changes, emails or staff reservations. Prepared SHA-256: 469b2a638c2c960af44281a545cd33ba4249f6ccd1a211e6728f4eb10f0c6a82. User confirmed application, all 58 SQL checks passed and the original work build passed. Do not rerun this applied migration on the existing project. Inline editor Cancel/Save/refresh and full build passed; remaining portion/reassignment acceptance is pending. See docs/work-ownership.md.

## 0005: assigned lead contact creation (applied in test)

Replaces create_job_contact with PM-or-authorized-lead creation; repeats job scope authorization after the parent row lock. All validation/retry/audit/limit/archive-replay behavior retained; edit/archive and raw writes unchanged. SHA-256: 2a084f504f6d5f05d9f20fe8879d858dbe0ece87800fa77c7aa78691eecb0b86. User confirmed successful application, 32 SQL checks with no failures, full production build, lead add/refresh/no edit controls and helper direct-create denial. Do not rerun this applied migration; fresh environments apply it once after 0004. No old migration was changed. See docs/lead-contacts.md.

## 0006: atomic Work and leads card save (applied in test)

Adds update_job_work_batch: PM-only, 1-100 unique narrow row patches, parent job lock, existing per-work authorization/validation, all-or-none mutation/audit, canonical actor/request receipt and current work response on retry without replaying old edits. No old migration edited. SHA-256: a717a49ebe12998dc071bdf056eb4463a5dda80228cbd25381aa3efbaed93309. Apply once after 0005 in isolated test, then run 40-check suite and full normal-user build/browser acceptance. See docs/work-card-save.md.

0006 evidence: user confirmed successful application, 40 SQL checks/0 failed and full production build. Shared-card Cancel passed; client save-button completion correction awaits browser/full-build retest. Do not rerun applied 0006; subsequent correction changes only client code/styles.

0006 final checkpoint: user confirmed shared-card Cancel, corrected Save completion, refresh persistence and final production build passed. No SQL changed after application. Commit/push pending.

## 0007: ordered lead queues (prepared; NOT applied)

Private queue state/event snapshots, get/save employee RPCs, membership triggers on ownership/completion and job lifecycle, existing-work backfill, full-order validation and stable request receipts. PM-any/lead-own; raw writes and helper/admin-only access denied. One company-wide mutation advisory lock precedes queue row locks; reads remain lock-free. No paid service/employee fixtures/dates/staffing. Prepared SHA-256: 5e080ac2d88727e66ff696adba6dfe5c1c7488e0d3bf836fa2523dae09818d1e. Apply once after 0001-0006 in test, run new 58-check suite, full user build and browser/concurrent acceptance. See docs/lead-queues.md.

0008_scheduled_visits.sql: prepared, NOT applied. After applied 0001-0007 only. Visits, date-only plans/optional reservations, named staffing, private snapshots, scoped read/write RPCs and helper entitlement maintenance. See docs/scheduled-visits.md. 6285665 is the uploaded queue checkpoint.

0008 is now applied; user reported 60 checks/0 failed and pre-inline full build. Do not rerun. 0009_visit_card_save.sql is prepared, NOT applied: single atomic Save for visit fields and optional roster. See docs/visit-card-save.md.
