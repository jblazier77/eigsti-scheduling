# Development plan

This is the current queue. Detailed historical decisions and verification records remain in decisions.md and status.md; older pending/application statements there are superseded by the checkpoints below.

## Verified checkpoint

- Latest confirmed GitHub backup: **0b5b259**, phase-0-foundation; employee-management commit/tracking branch confirmed clean/up-to-date before the simplicity pass.
- Applied database migrations: **0001–0016**. Never rerun applied migrations or their bundles.
- 0014: user confirmed **48 checks, 0 failed, synthetic fixtures removed**. Calendar views, commitments, moving dates and simplified calendar cards passed the user's reported desktop review.
- Core jobs, contacts/files, work/lead ownership, queues, optional-date scheduling/staffing, rain/filler tags, scopes/trades, material availability, one-save quick work and subcontractor commitments are implemented.
- No production deployment or pilot release is claimed.

## Current development batch: UI simplicity before pilot testing

D62: independent phone-first simplification, less whitespace, understandable buttons/icons and fewer everyday expanders. Compact spacing/navigation; always-visible scope labels; PM keeps all scope choices while readers see selected scopes; inline crew/material pencils; compact subcontractor contact rows; direct contact notes; linked job/queue titles instead of redundant links; no empty history accordion. Existing permissions, field values, command/retry behavior and one Save/Cancel flows are preserved.

Implemented locally: final combined batch has **190 Node checks and TypeScript passing**. **No SQL update**. Actual phone/tablet review and a final successful release build remain pending; see current status for the successful earlier build and final Windows EPERM. Automated Chrome screenshot capture was unavailable, so no visual acceptance is claimed. Batch is uncommitted; see ui-simplicity.md.

D61 employee management is implemented/applied (0016, reported expected 33-check success), user-reported name editing and deactivate/reactivate controls worked, and code is backed up as 0b5b259. Existing-session access revocation, role forgery, actual concurrent/fault and device checks remain separate. D60 archive/restore remains applied and accepted; handoff notes remain removed.

## Pilot preparation D63 implemented locally

Prepared hosting/Node configuration, isolated build command, preview/data-mode safeguards, employee/subcontractor session refresh coverage, encrypted database/Auth/private-file packages and verification/extraction tools, read-only readiness SQL, anonymous hosted-access checks and secret-free CI. See pilot-handoff.md for the single grouped owner/operator checklist. No new schema migration. Actual provisioning, live backup, daily offsite execution, managed restore, device/concurrency checks and pilot approval remain pending.

## Remaining initial pilot queue, in order

1. Save/push D62/D63; complete final production build in ordinary PowerShell or prepared CI, then grouped UI review. No SQL rerun.
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
