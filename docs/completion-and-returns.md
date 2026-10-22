# Completion and return-work batch

Current direction: implemented together with R25-R27. Use combined-batch.md and database/batches/0010_0011_combined.sql, not the standalone 0010 bundle/checklist. 98 Node checks/TypeScript pass; combined SQL/build/browser acceptance is pending.

Prepared 2026-10-22 from uploaded checkpoint a91da8c. Initial scoped implementation is local and uncommitted. Applied migrations 0001-0009 remain unchanged. 86 Node tests and TypeScript pass; new SQL execution, normal-user production build and consolidated browser acceptance remain pending. No production deployment.

## Behavior

Finish scheduled work appears inline on job/schedule entries for PM or the entry's active coordinating lead. It marks that entry completed and releases the entire crew's explicit time reservations. No narrative/date/percentage is required. Optional remaining note can be recorded; Return trip needed requires a short description and creates a linked follow-up. Follow-up date is optional and does not book staff. Portion and whole job stay open; future entries and other leads' portions are untouched. Completed entries remain in the personal schedule with a Completed label. Existing noncancelled completed assignments retain active-job information access, consistent with 0008.

Completion and return work appears on job details. Active PM can manage any portion; active lead can manage only the portion they currently own. Complete this portion requires all its planned entries finished/cancelled and all open returns explicitly handled. It marks only that work item completed, clears its current remaining note with old text retained in audit, and removes it from its lead queue. It never closes the job or another portion. Reopen this portion reverses its completion and rejoins the queue without restoring old appointments or changing staff.

Add return work records a short note against the SAME work identity and retains source/owner/history. Completed portions require the explicit Reopen & save return action. Owner is the current active responsible lead or the recording actor when that identity is unavailable. No fake end date, permanent main job lead, automatic reassignment or duplicate work portion is introduced.

Plan return on calendar reuses the inline date-only/optional-time visit form and existing conflict enforcement. It creates a visit linked to the follow-up; does not clone the source crew or confirm readiness. Only one planned appointment per return is allowed; edit it directly instead of duplicating. Finish/cancel that appointment, then Mark return handled explicitly. Handling a return does not itself finish the portion. Multiple separately described open returns are allowed, up to 100 per job. Calendar dates follow the existing weekday/Central-time rules; optional follow-up due dates are reminders, not time reservations.

Helpers have read-only relevant job progress through their existing job entitlement and no lifecycle mutation. Admin-only has no operational mutation. A former owner loses completion/reopen/return-management permission on reassignment even if another entitlement preserves shared job information. PM is the resolution path for inactive owners; phone user administration remains a later gate.

## Data and transaction boundary

0010 adds public.work_follow_ups (raw employee access denied), optional visits.follow_up_id, private immutable work_progress_events with before/after snapshots, scoped list_job_progress and work_progress_command. The command has six explicit operations: finish_visit, complete_work, record_return, resolve_return, reopen_work, plan_return. It validates values/parents independently of the UI, locks the scheduling mutex, actor profile, parent job/work and related entry/return, then rechecks live authorization. Work completion/reopen uses existing queue membership triggers, following scheduling -> job/work -> queue; queue saves never lock job/work rows.

Visit finish uses the existing booking/entitlement maintenance. Return appointment creation calls the existing transactional visit command, links its new entry and audits the final linked result. Errors abort all command effects. Actor/operation/request receipts reject changed payloads and return current authorized results without replaying old completion over a newer reopen or duplicating return work. Notes/flags/dates are canonicalized for finish/record commands. Client forms retain uncertain drafts and their retry IDs, distinguish known conflicts and revalidate job/schedule/queue only after confirmed success.

No job-close/archive command, broad work history UI, notifications, automatic rescheduling or general follow-up editing is included. Whole-job closure still needs its own future guarded command. No real concurrent database connections or dropped-response fault tests have run; lock analysis and a sequential suite are not substitutes.

## One database update

Use database/batches/0010_completion_and_returns.sql once in isolated test project vglhojtrccygjgupxsrd. Do not separately apply the standalone migration if using this bundle. It keeps 0010's DDL inside one outer transaction, runs the complete 60-check suite under a savepoint, validates all results, rolls back all synthetic data/temporary state, then commits only DDL. Final result is 60 checks, 0 failed and 0010 applied; synthetic fixtures removed. An error aborts the outer transaction; stop and preserve the error. ROLLBACK clears an aborted SQL Editor transaction before a corrected retry. Do not rerun a successfully applied batch.

The exact source migration/test files are also retained for fresh-environment tooling and inspection. Regenerate the bundle with node scripts/prepare-completion-batch.mjs after any authorized pre-application SQL change. A Node packaging check enforces one outer BEGIN/COMMIT, exact migration/test bodies, all 60 assertions and cleanup before commit. Prepared bundle SHA-256: 9e64975b8fb782d3feccd829edf69db578326f9b1d694ff338ba51a85ec41448.

60 prepared SQL checks cover finish vs portion/job scope, released bookings, undated note/source/owner, queue membership, safe retries, blocked planned work/returns, guarded linked return scheduling, late conflict rollback, no cloned helper crew, resolution, completion/reopen, explicit reopening for return, independent portions, role/parent/field forgery, raw/private access, reassignment and retained readiness/history. Fixtures roll back. SQL has NOT run yet. Seven new Node checks bring the suite to 86: input/no mandatory narrative/date, explicit return/reopen, scopes/transport, action success vs conflict/uncertain retry, linked return action and atomic bundle integrity. Auth/database transport is mocked. TypeScript passed.

## Consolidated user acceptance

First run the normal-user production build (agent builds remain avoided because of earlier OneDrive cleanup permissions), copy the batch, run it once in Supabase and confirm 60/0. Restart dev. Perform this checklist as Josh/PM in one sitting; report all results together rather than one message per click:

1. On the test job, finish one planned entry using Return trip needed and a short note. Leave the optional follow-up date blank. Verify that entry is Completed, the portion/job remain open and the return note appears.
2. Plan its return inline for a weekday with No time set. Confirm the new appointment stays on the same portion; no helper is silently copied. Finishing the new entry must leave the return open until Mark return handled is chosen.
3. Finish/cancel any other planned entries for THAT portion, then mark its returns handled and Complete this portion. Verify other portions/job stay open and the completed portion leaves Test Lead's queue.
4. Reopen for return work with another short note. Verify the same portion reopens/rejoins the queue, and a return note appears without an automatic calendar booking. Refresh/open a new tab to confirm persistence.

Optional role pass in the same sitting: Test Lead can finish coordinated entries and manage only owned portions; Test Helper reads relevant progress with no completion controls. SQL covers denial boundaries, but actual phones/live expiry/deactivation/concurrent races and fault/recovery checks remain separate pilot gates.

After results pass, record the user production build/SQL/browser evidence, then one commit/push for this batch. Current local modifications are not backed up beyond a91da8c until that push is confirmed. User prefers larger implementation/testing batches, one consolidated database update and grouped acceptance going forward.
# Testing paused — 2026-10-22

Josh paused this batch's setup/acceptance to add rain-day tagging and flexible filler work to the initial build. See rain-day-and-filler-work.md and R25/R26. No successful 0010 database application or browser acceptance has been reported. Retain the local implementation; do not treat the checklist below as the current next action while paused.

