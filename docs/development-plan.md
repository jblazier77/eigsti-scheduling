# Development plan

Current local slice: approved job-details layout and matching initial-page theme are implemented without SQL changes. 107 Node tests/TypeScript pass; real browser review and a new user production build remain pending. Read ui-layout-refresh.md for consolidated acceptance. The combined 0010/0011 migrations are already applied with 111 checks/0 failed; do not rerun those updates. Preserve one final build/checkpoint after this visual review.

Latest evidence: user production build passed and combined SQL returned 111 checks/0 failed with 0010 and 0011 applied and synthetic fixtures removed. Those migrations are applied; do not rerun their standalone or combined updates. Next is grouped browser acceptance, then one commit/push. Earlier descriptions of pending database/build checks below are superseded by this evidence.

Updated 2026-10-22. Architecture implementation phases remain distinct from the deferred post-pilot release list in post-pilot.md.

The combined batch is implemented locally: completion/returns (0010), rain-day and filler-job tags, project scopes/Whole house markers, and the subcontractor trade directory (0011). Use database/batches/0010_0011_combined.sql once after applied 0001-0009. Its preflight stops if 0010/0011 may already be present. Do not apply the old 0010-only bundle as an intermediate step. See combined-batch.md for setup and grouped acceptance.

| Phase | Scope | Current state |
| --- | --- | --- |
| 0 | Foundation, permissions, synthetic scenarios, ownership/cost/sign-in | Foundation prepared; operational/phone exit gates pending |
| 1 | Individual sign-in, jobs/details/contacts/files, phone actions | Core desktop checks passed; phone/account administration and production/recovery gates pending. Email invites/self-service recovery deferred |
| 2 | Work ownership/queues, day/week calendar, visits/staffing, completion/returns | Uploaded a91da8c includes applied 0001-0009. Completion/return implementation remains local pending combined acceptance |
| 3 | Readiness, subcontractor commitments, follow-ups/handoffs, filters/history | Local 0010/0011 adds returns, tags/scopes and trade directory. Readiness editing, commitments, handoffs and guarded job closure remain |
| 4 | Pilot, phone admin, export/DB+file restore, release candidate | Not started; phone/concurrent/fault/recovery gates remain |

Latest confirmed uploaded commit: a91da8c. New local changes are not confirmed pushed. Never edit or rerun applied migrations 0001-0009.

The combined SQL update applies ordered DDL and runs 111 checks (60 completion/return, 51 tag/trade) under fixture savepoints; fixtures roll back before DDL commits. SQL execution, normal-user production build and grouped browser acceptance are pending. Automated Node/TypeScript results are recorded in combined-batch.md; they do not replace real database/browser checks.

D40/D41: minimize clicks, inline editing and one Save/Cancel pair per editable card. Job tags/scopes share a single inline draft; new filler creation is one atomic normal-job/default-work/tag command. Trade directory edits are inline; project scopes are independent of subcontractor assignments. PM edits job tags; PM/admin manages the directory; leads read it; helpers remain limited to assigned job data.

D45: finish the combined authorized development slice before user acceptance. Hand over one build/restart sequence, one database update and one grouped checklist. Automated checks run during development. If 0010 was applied meanwhile, stop and prepare the appropriate remaining update rather than replaying it.

Confirmed defaults: America/Chicago, weekdays 07:00-15:30, noon split; times optional. Date-only plans allow several jobs per day with workload notices; explicit blocks reserve people. Filler work is a standalone normal job tag. Rain-day suitability is independent. Whole house is an explicit compact presentation, retaining selected scopes. No weather integration or automatic rescheduling.

After combined acceptance: record results and one commit/push, then remaining readiness/commitments/handoffs/guarded job closure and phone/account/recovery gates. Email invitations, forgotten-password self-service and SMTP/DNS remain post-pilot; manual onboarding/reset is permitted. No production data, paid provisioning or notifications.

Latest UI follow-up: compact alphabetized job contacts with inline editing and Subcontractor Type/directory snapshot selection; only three My Jobs discovery filters. 118 Node tests and TypeScript pass; final user production build and grouped authenticated acceptance remain pending. No new SQL. Project work simplification is still awaiting its separate review.

Work UI simplification implemented after contact approval: compact work/lead/status and dates/crew summaries, heading-level inline Add/edit, small schedule edit/Finish actions, More for completion/returns. 119 automated checks and TypeScript pass; grouped authenticated desktop/phone review and final production build remain pending. No SQL update.

Planning requirement correction (D51): no per-entry Finish/check-off workflow. Removed scheduled-entry Finish controls throughout job/calendar views; normal planning and staffing need no completion reporting. 119 automated checks and TypeScript pass. Before optional whole-portion/return/job closure acceptance, reconcile legacy planned-entry closure guards with this decision using a new migration if needed. No mandatory daily finish, cancellation of real historical plans as a workaround, or automatic inference of completed work. Applied SQL is unchanged.

D52 clarification: Remove whole-portion Complete/Reopen and return-handled check-off controls in addition to scheduled-entry Finish. Implemented across current and legacy job components; 119 checks and TypeScript pass. Keep planning/add-return actions. Any future job archival/lifecycle workflow must be separate from daily completion reporting; no SQL/data rewrite in this slice.

D53 unified-work correction implemented: all new additions use Add work, regardless of when entered; no separate return-work flow, type, section or special scheduling selector. Save visit is Save work; removal from schedule retains the work. Legacy follow-up notes/owners/dates and linked plans remain readable on original work; no records were migrated or deleted. Applied SQL unchanged. 120 automated checks/TypeScript pass; final build and grouped authenticated review pending. Any future backend cleanup must preserve that one user-facing notion of work and use a separate safe migration.
