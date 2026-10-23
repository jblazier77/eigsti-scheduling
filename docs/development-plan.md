# Development plan

This is the current queue. Detailed historical decisions and verification records remain in decisions.md and status.md; older pending/application statements there are superseded by the checkpoints below.

## Verified checkpoint

- Latest confirmed GitHub backup: **f767b9f**, phase-0-foundation; user reported clean/up-to-date after push.
- Applied database migrations: **0001–0015**. Never rerun applied migrations or their bundles.
- 0014: user confirmed **48 checks, 0 failed, synthetic fixtures removed**. Calendar views, commitments, moving dates and simplified calendar cards passed the user's reported desktop review.
- Core jobs, contacts/files, work/lead ownership, queues, optional-date scheduling/staffing, rain/filler tags, scopes/trades, material availability, one-save quick work and subcontractor commitments are implemented.
- No production deployment or pilot release is claimed.

## Current development batch: reversible job archive

D60: user removed dedicated handoff notes from the queue. Do not develop a new handoff-note form or workflow. Existing job/access/work notes and historical records remain; this does not remove those fields.

Implement PM Archive job and Restore for more work. Archive removes the job from active lists, operational calendars and lead queues without completing work, deleting files/contacts or wiping history. Archived jobs can return for ordinary additional work/punch lists on the same job. Today/future crew plans and dated subcontractor promises must be resolved before archive; no daily completion/check-off requirement. Existing open work ownership resumes when restored; review before scheduling again.

Status: **0015 applied**, user confirmed expected guarded success (35 checks, 0 failed, synthetic fixtures removed). **164 Node checks and TypeScript pass**. Explicit new production-build output is not separately recorded; user reported the grouped archive/restore desktop review worked. Phone/concurrency/recovery checks remain separate. D60 changes are not yet backed up. See job-archive.md for one guarded update and consolidated acceptance. Applied 0014 is unchanged.

## Remaining initial pilot queue, in order

1. Finish the archive/restore batch: Desktop review passed by user report; back up with one Git commit/push and retain the final build-evidence gap. Do not rerun applied 0015.
2. Simple employee account/deactivation administration; manual pilot provisioning/reset remains supported. No unconfigured recovery-email feature.
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
