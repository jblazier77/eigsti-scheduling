# Team demonstration setup

Prepared October 28, 2026. Fictional project vglhojtrccygjgupxsrd only. Not a production/pilot seed and not a migration.

User authorized demo jobs/employees/data and clarified existing database details are disposable. The setup archives old jobs, cancels old planned entries, removes their derived bookings/access entitlements, archives old subcontractors and deactivates existing crew-only profiles. Existing active PM/admin accounts and their passwords stay available. It does not delete customer records, Auth accounts or files. Old jobs remain in Archived.

Run in ordinary PowerShell from the repository:

    node scripts/ops/setup-team-demo.mjs

Uses private .env.ops.local for verified TLS PostgreSQL access and private .env.local/server key for Auth administration. Refuses production/pilot modes and any project except the allowlisted fictional one. The initial read-only database preflight runs before Auth provisioning. Six Auth identities are created through the installed Supabase Admin API with individual random temporary passwords, email confirmation and a server-only demo marker; no invitations are sent. Existing mismatched accounts are never adopted or reset. Credentials persist privately outside Git in the configured backup root, Eigsti-Team-Demo-Accounts.private.json. An interrupted Auth/profile setup may leave recoverable Auth-only identities; rerun the same command, do not remove the private account file.

The reset and complete job/profile/work/date/helper/contact/subcontractor seed are one PostgreSQL transaction. A durable seed receipt prevents duplicate installation and preserves later edits. A failed transaction leaves existing app records unchanged. No blind reapply/reset on an installed demo. Demo dates are anchored to the Central-time day of successful setup, across the following two weeks. Date-only work allows same-day workload warnings without exclusive time reservations.

Demo content: 8 jobs, 10 work tasks, 6 crew profiles (2 leads, 4 helpers), 8 customer contacts, 4 subcontractor job contacts/commitments and 3 subcontractor directory entries. Work includes kitchen cabinets, windows, bathroom tile, deck repair, indoor punch list, basement finish, roof trim with lead needed and a full-house project. Priorities 1-8, ordered/in-stock/not-ordered/no-hold materials, partial/full staffing, a lead helping another lead, Saturday planning, rain/filler tags and unassigned/undated planning are represented. No photos or PDFs are seeded by this setup.

Show the PM Jobs page and help-needed summary; open Miller kitchen and Anderson windows; show Day/Week/Two weeks/Month calendars and Saturday staffing; use rain-day/filler filters and Subcontractors. Lead/helper views may be shown using the private demo credentials, without sharing the PM/admin account. Employees remain able to change their own password in My account.

Local dataset/input and seed-guard checks pass. Initial direct database/API probes from the coding session were denied (PostgreSQL DATABASE_PERMISSION_DENIED and table API 42501). No live demo installation is claimed. A successful ordinary-PowerShell setup result must be recorded separately. No schema permissions were relaxed.

First owner execution reached employee Auth setup but failed at the data transaction. Corrected ambiguous local job_id naming and qualified access cleanup; added safe stage/SQLSTATE-only diagnostic output. Six targeted Node tests pass. Retain the private credential file and rerun the same setup command; no completed installation is claimed until Demo ready.

TEAM DEMO INSTALLED October 28: user supplied successful setup output: Demo ready, PM Josh Blazier, 8 jobs, 6 employees, start_date 2026-10-28. This supersedes earlier failed/pending installation notes. Demo credentials remain in the private configured backup folder; no passwords recorded here. Old throwaway jobs archived, old crew-only profiles deactivated, PM/admin sign-ins retained by the successful guarded transaction. Do not rerun as a reset; replay preserves edits. Team browser review and committing/pushing the new demo tooling remain pending.
