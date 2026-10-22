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
