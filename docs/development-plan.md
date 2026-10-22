# Development plan

Updated 2026-10-22. The architecture's implementation phases remain unchanged. The user's post-pilot Phase 2 release list is separate in post-pilot.md; core scheduling remains in initial pilot scope.

| Phase | Scope and exit | State |
| --- | --- | --- |
| 0 | Foundation, permissions/model, synthetic scenarios, phone interactions, ownership/cost/sign-in | Foundation prepared; operational ownership/phone review gates pending |
| 1 | Individual sign-in, job creation/access/details/contacts/files, phone actions | Implemented and checked as recorded in status.md; phone/integration/admin checks remain; email invitations/recovery deferred with manual pilot provision |
| 2 | Work ownership, queues, week/calendar, visits, named staffing, availability, completion/returns | Ownership, inline shared-card save and assigned-lead contact creation verified; 0007 applied, 58 SQL checks/0 failed, full build and core queue desktop checks passed; queue checkpoint awaiting commit/push; visits/staffing not started |
| 3 | Readiness editing, sub commitments, follow-ups, portion handoff, PM filters/history | Not started |
| 4 | Small lead/PM/helper pilot, phone admin, export and DB+files recovery, release candidate | Not started |

Latest uploaded checkpoint: c38984c (ownership/revocation evidence), following a79c78e (atomic work card Save/Cancel), 85cad7a (inline PM work/lead contacts), e95f6ea (password changes). Applied migrations 0001-0006 and user-reported SQL checks passed; exact counts/evidence/limits are in status.md. User full build and shared-card Save/Cancel/refresh passed. Browser verified access through a remaining portion and direct job/contact-create denial after final assignment removal.

Current slice: per-lead ordered work queues. 63 Node tests and TypeScript pass. User confirmed 0007 applied, 58 SQL checks/0 failed, full normal-user build and core PM/lead/helper desktop flows, including removal and append after reassignment. Commit/push this queue checkpoint next; do not rerun applied migrations. Queue order saves are latest-commit-wins with exact membership checks, stable request retry and preserved unrelated edits. Membership triggers append/remove eligible work. See lead-queues.md for the company-wide mutation lock tradeoff and pending concurrency verification. Visits/staffing follow this checkpoint.

Email invitations, self-service forgotten-password recovery and custom SMTP/DNS setup are post-pilot. An external manager handles DNS; SMTP is off. Controlled manual pilot onboarding/reset and private credential handoff are permitted; employees can change their passwords through My account. First-login changes are not forced. Phone account administration and deactivation remain initial scope.

Phase 0 and release gates still require named owners, hosting/cost/sign-in validation, actual phone workflow review, session/fault/concurrent database tests and DB+file restore. File HEIC/near-limit/expiry acceptance remains separate. A unit or sequential SQL test is not field/recovery/concurrency proof.

At meaningful checkpoints update status/decisions, run appropriate checks and commit/push through user PowerShell. No production data in previews or unauthorized paid provisioning. Planning allowance remains 80-120 focused engineering/testing hours for pilot, excluding account delays and field iteration; re-estimate after scheduling integration.
