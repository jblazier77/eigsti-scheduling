# Isolated database verification

The SQL suite is **authored, not executed**. This computer has no PostgreSQL/Docker, and package-registry DNS is unavailable. Node unit/request-adapter tests are separate evidence and cannot establish RLS, SQL syntax, transaction atomicity or real Auth behavior.

When a synthetic-only Supabase test instance is available:

1. Record instance/project identity and verify it is not production. Use the same schema/migration path intended for production.
2. Apply `database/migrations/0001_jobs_and_access.sql` to an empty application schema. It requires Supabase's `auth.users`, `auth.uid()`, `anon` and `authenticated` roles.
3. Run `database/tests/0001_jobs_and_access.test.sql` with a privileged test connection and pgTAP available. It creates reserved-domain synthetic identities in a transaction and rolls them back. Check TAP output for every assertion; a SQL client exit code alone is insufficient if TAP contains failures.
4. Capture PostgreSQL version, migration checksum and complete pass/fail output. Then repeat from a clean reset.
5. Add two-connection tests: simultaneous same-request CreateJob gives one job/work/audit; different requests remain separate; concurrent narrow patches to scope and phone both persist. A single-connection pgTAP retry is not proof of concurrency behavior.
6. Before Phase 1 exit, test actual Supabase Auth password/invite/recovery sessions, direct REST API reads/writes, and private Storage authorization/uploads on phones.

Account provisioning is deliberately not public: no user signup/role promotion RPC exists. Initial company admin/PM app profiles must be provisioned through an authorized technical process, then the phone invite/user administration flow can be implemented with separate administrative secrets kept server-side. Database Auth rows in this test are fixtures only, not usable employee accounts.

Helper `private.job_access` records are information-access entitlements, not staff reservations. Phase 2 must derive and revoke these from real visit participants transactionally before helper schedules are enabled. No UI may grant broad access just because a helper has free time.
