# Development plan

Latest resume evidence supersedes older checkpoint descriptions below: a5f2bc5 is committed/pushed, and user reported a successful full production build of the unified-work/UI batch, including TypeScript and all routes. 120 automated checks previously passed; applied 0010/0011 already passed 111 database checks. Next is normal-user dev plus one grouped authenticated review; no SQL setup is needed. Remaining phone/concurrency/recovery/pilot and later feature work are still distinct, and do not reintroduce daily completion or separate return-work concepts.

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

## Next development push - optional date while adding work

User request recorded during grouped review: when adding a new work item, offer an optional schedule date in the same inline form. A date is never required. If known, enter it during Add work and save without reopening Add date; if unknown, save undated work normally. Keep time optional and preserve the existing No time set/multiple-jobs-per-day behavior. Use one Save/Cancel pair and existing lead/staffing permission boundaries. Implement safe creation/retry behavior so a partial or interrupted save cannot silently duplicate work or falsely confirm its schedule. This is queued for the next development push, not implemented or accepted yet. No current SQL change.

## Readiness scope note - material availability

User approved keeping the existing readiness badge for now. Desired future use includes material availability such as cabinets: Need to order, Ordered, In stock, and an expected availability/arrival date when known. Record this as readiness/material planning scope, not work completion tracking. Preserve unknown availability; an expected date must not automatically assert delivery or In stock. Exact controls and how multiple materials combine into overall work readiness remain to be designed. Documentation only in this turn; no app or SQL change.

## Current authorized batch - staffing warnings, optional Add-work date, material readiness

D54/D55/D56 are implemented locally. PM day/week entries warn with an amber triangle and missing helper count; no staffing Plan choice remains. Add work accepts optional dates in the same atomic save. Material availability summaries/expected dates now provide the next initial-plan readiness slice, with PM/own-lead edits and authorized read-only access. See planning-and-materials.md for one build, one guarded 0012 SQL update (42 checks), and grouped acceptance. 133 Node checks and TypeScript pass. SQL 0012 is NOT applied yet and a new full build/browser acceptance are pending. Applied 0001-0011 unchanged. Subcontractor commitments/handoffs and pilot/device/recovery/lifecycle work remain; do not restore completion-reporting or separate return-work concepts. Latest confirmed push a5f2bc5.

0012 live application succeeded: user screenshot confirms 42 checks and guarded '0012 applied; synthetic fixtures removed' result. Do not rerun. 134 Node checks and TypeScript pass; next is grouped authenticated planning/readiness review, then final batch checkpoint. Subsequent initial-plan commitments/handoffs and pilot/device/recovery/lifecycle gates remain distinct.

Current follow-up D57: quick Add work includes visible Helpers needed and Material availability together with optional dates in one save. Undated helper need persists and prefills Add date. New 0013 is prepared with a guarded 33-check bundle; applied 0012 stays unchanged. 139 automated checks and TypeScript pass; full build/live SQL/browser checks are pending. See quick-work.md. Do not rerun earlier bundles.

0013 application confirmed by user: guarded final success result '0013 applied; synthetic fixtures removed'. All 33 checks passed before the success row; migration is APPLIED. Do not rerun. Next: restart normal-user dev and review one-save window/date/help/in-stock setup and undated helper persistence, then checkpoint after acceptance. 139 Node checks/TypeScript pass; new full build output not separately supplied. Latest confirmed push a5f2bc5.

User accepted the quick-work setup with 'worked great' after the 0013 one-save scenario. That interaction is verified; remaining unreported role/device/concurrency/recovery scenarios stay pending. Next: one user Git checkpoint for this batch, then subcontractor commitments/scheduling and handoff planning within the remaining initial plan. Preserve inline editing, one-save setup and planning-only semantics.
