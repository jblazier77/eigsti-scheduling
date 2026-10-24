# Development plan

This is the current queue. Detailed historical decisions and verification records remain in decisions.md and status.md; older pending/application statements there are superseded by the checkpoints below.

## Verified checkpoint

- Latest confirmed GitHub backup: **d585a13**, phase-0-foundation; archive commit/tracking branch confirmed clean/up-to-date at the employee-management turn start.
- Applied database migrations: **0001–0016**. Never rerun applied migrations or their bundles.
- 0014: user confirmed **48 checks, 0 failed, synthetic fixtures removed**. Calendar views, commitments, moving dates and simplified calendar cards passed the user's reported desktop review.
- Core jobs, contacts/files, work/lead ownership, queues, optional-date scheduling/staffing, rain/filler tags, scopes/trades, material availability, one-save quick work and subcontractor commitments are implemented.
- No production deployment or pilot release is claimed.

## Current development batch: employee management

D61: administrator-only existing app-profile directory, inline name/roles/active edits, no self-lockout/last-admin removal, assignment-aware role changes, retained work/history on deactivation, stale-edit protection and stable retries. No Auth account creation, email invitations or password-reset interface; manual pilot onboarding/reset remains.

Implemented locally: **173 Node checks and TypeScript pass**. **0016 application was reported successful** after the expected 33-check guarded update. Explicit full production-build output is not separately recorded; grouped employee-screen/browser/phone acceptance remains pending. Batch is uncommitted; see employee-management.md, including safe pause instructions.

D60 archive/restore is implemented/applied (0015, expected 35/0 guarded result), user-reported desktop review passed, and backed up as d585a13. Dedicated handoff notes remain removed; existing notes/history stay intact. Explicit final build output and further device/concurrency/recovery checks remain distinct.

## Remaining initial pilot queue, in order

1. Complete employee management: one new build, 0016 applied; do not rerun, grouped review and one Git backup.
2. Keep manual pilot provisioning/reset; verify admin access, deactivation and reactivation. Automated email workflows remain deferred.
3. Consolidated phone/tablet usability, role/access, leads-helping-on-other-work, concurrent scheduling and uncertain-save/fault checks. Reconcile legacy scenarios with planning-only work rather than reintroducing completion reporting.
4. Operational readiness: export and isolated database/auth/private-file restore drill, recovery instructions, realistic load/performance checks.
5. Hosting and limited pilot rollout: access without this computer running, final environment/security/operating checks, release candidate and pilot acceptance.

## Deferred or removed

- Dedicated handoff-note feature: **removed by user**, D60.
- SMTP/DNS, automated email invitations and self-service forgotten-password emails: post-pilot (user's Phase 2 list), see post-pilot.md.
- Google integration, notifications, daily completion/check-off screens and a separate return-work workflow are outside the authorized initial UI scope.

## Operating rules

Keep the carpenter-facing UI concise: inline edits, minimal clicks, one Save/Cancel per context. Dates/times are optional; multiple date-only jobs per day are supported. Expected material dates never assert actual delivery. A Lead account can coordinate one work entry and be helping crew on another; responsibility stays with the assigned work/coordinating lead. PM defaults to My jobs and can select All jobs. Calendar views are Day/Week/Two weeks/Month.

Use the user's ordinary PowerShell for a reliable backend-connected dev server. Stop dev before production builds. Run automated checks during development; group user acceptance into useful batches. Keep applied SQL immutable and use guarded new migrations with synthetic fixtures removed before commit. Record only observed browser/database/build results. Do not claim outstanding phone, concurrency, restore or pilot checks from automated unit tests.
