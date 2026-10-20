# Migration contract

`0001_jobs_and_access.sql` is authored but **not applied or PostgreSQL-verified**. It requires Supabase Auth schemas and roles. It creates users, jobs, default work, audit/retry records, private information-access entitlements, read RLS and PM-only create/update commands. It grants no raw operational writes to employee roles.

Run `database/tests/` against an isolated Supabase instance before use. Node request tests do not prove SQL correctness or database authorization. Next: apply from empty, run all pgTAP and multi-connection tests, repeat clean setup; then add contacts/private files, account provisioning and the Next.js interface. Visit/staffing tables belong to Phase 2. Every migration must include its access boundary.

Apply identical ordered migrations in isolated test and production. Do not manually patch the production schema. Seed production with configuration only; demo records belong exclusively to local/test. Recovery and backward compatibility are separate from migration execution.
