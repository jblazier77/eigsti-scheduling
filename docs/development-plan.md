# Development plan

Updated 2026-10-22. The architecture's implementation phases remain unchanged. The user's post-pilot Phase 2 release list is separate in post-pilot.md; core scheduling remains in initial pilot scope.

| Phase | Scope and exit | State |
| --- | --- | --- |
| 0 | Foundation, permissions/model, synthetic scenarios, phone interactions, ownership/cost/sign-in | Foundation prepared; operational ownership/phone review gates pending |
| 1 | Individual sign-in, job creation/access/details/contacts/files, phone actions | Implemented and checked as recorded in status.md; phone/integration/admin checks remain; email invitations/recovery deferred with manual pilot provision |
| 2 | Work ownership, queues, week/calendar, visits, named staffing, availability, completion/returns | Ownership, inline shared-card save and assigned-lead contact creation verified; 0007 applied, 58 SQL checks/0 failed, full build and core queue desktop checks passed; queue checkpoint pushed as 6285665; visit/staffing/day-week calendar slice prepared locally, 0008/60 SQL checks/full build/browser pending |
| 3 | Readiness editing, sub commitments, follow-ups, portion handoff, PM filters/history | Not started |
| 4 | Small lead/PM/helper pilot, phone admin, export and DB+files recovery, release candidate | Not started |

Latest uploaded checkpoint: 6285665 (queue implementation and acceptance), following c38984c (ownership/revocation evidence), following a79c78e (atomic work card Save/Cancel), 85cad7a (inline PM work/lead contacts), e95f6ea (password changes). Applied migrations 0001-0006 and user-reported SQL checks passed; exact counts/evidence/limits are in status.md. User full build and shared-card Save/Cancel/refresh passed. Browser verified access through a remaining portion and direct job/contact-create denial after final assignment removal.

Current slice: per-lead ordered work queues. 63 Node tests and TypeScript pass. User confirmed 0007 applied, 58 SQL checks/0 failed, full normal-user build and core PM/lead/helper desktop flows, including removal and append after reassignment. Commit/push this queue checkpoint next; do not rerun applied migrations. Queue order saves are latest-commit-wins with exact membership checks, stable request retry and preserved unrelated edits. Membership triggers append/remove eligible work. See lead-queues.md for the company-wide mutation lock tradeoff and pending concurrency verification. Visits/staffing follow this checkpoint.

Email invitations, self-service forgotten-password recovery and custom SMTP/DNS setup are post-pilot. An external manager handles DNS; SMTP is off. Controlled manual pilot onboarding/reset and private credential handoff are permitted; employees can change their passwords through My account. First-login changes are not forced. Phone account administration and deactivation remain initial scope.

Phase 0 and release gates still require named owners, hosting/cost/sign-in validation, actual phone workflow review, session/fault/concurrent database tests and DB+file restore. File HEIC/near-limit/expiry acceptance remains separate. A unit or sequential SQL test is not field/recovery/concurrency proof.

At meaningful checkpoints update status/decisions, run appropriate checks and commit/push through user PowerShell. No production data in previews or unauthorized paid provisioning. Planning allowance remains 80-120 focused engineering/testing hours for pilot, excluding account delays and field iteration; re-estimate after scheduling integration.

Current next slice: scheduled visits and staffing, prepared in 0008. Dates alone are sufficient, with several jobs per day allowed; optional explicit time blocks reserve staff. Day list and week calendar are implemented locally. 70 Node tests and TypeScript pass. Apply 0008 once, run 60 SQL checks, user full build and browser acceptance before committing this checkpoint. See scheduled-visits.md. Completion/returns and lifecycle resolution remain subsequent work.

Checkpoint update 2026-10-22: 0008 applied, 60 SQL checks/0 failed and initial full build passed per user. Date-only create/persistence and PM day/week views passed. D40 makes minimal clicks/inline editing the default for further work. Visit cards revised to edit dates/staffing in place; new UI full build and browser checks pending, with no new SQL. Named-helper acceptance remains next.

D41 update: one Save/Cancel for complete inline visit draft, including named help. Prepared 0009 and 38 checks; apply once after 0008, test, full user build/browser, then commit/push. 77 Node tests and TypeScript pass. Existing 0008/60 SQL checks and initial build remain verified; named staffing browser success is unconfirmed.

Browser acceptance update: helper assignment now saved and visible on personal schedule; helper job details read-only; lead cannot remove named helper; shared Cancel restores need and certainty. Empty helper schedule was resolved by user assigning the helper, with no demonstrated schedule-query bug. Next check explicit overlap, final user build, and commit/push visit checkpoint.

Visit checkpoint desktop acceptance: PM optional-time planning/day-week views; shared helper save; helper personal schedule and read-only job details; lead cannot remove assigned help; shared Cancel; explicit Morning overlap rejected; restored No time set visible in fresh job tab. Final normal-user build and commit/push outstanding. Phone/concurrent/fault/recovery gates remain separate.
