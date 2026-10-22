# Work ownership checkpoint

Updated 2026-10-21. User confirmed migration 0004 applied, 58 SQL checks with no failures and a full build of the original work routes. Initial PM assignment save passed; subsequent inline PM editor is local and awaits browser/full-build verification. This is the first scheduling foundation slice; it does not implement queues or visits.

## Behavior

The existing default Whole job work item is shown on job details. At user request, PMs now edit open work descriptions and leads directly on that page, with per-row Save/Cancel. Save stays on the job page and Cancel resets the draft/error state. Each row has unique field labels; fields stack on phones. Read-only roles see assigned work without assignment controls. The existing edit route remains usable for old links; adding a new portion retains its separate form. Active PMs may rename it and assign an active lead, or leave it unassigned. Simple jobs require no additional setup. To split a project, rename the existing Whole job to the first portion and add only the other separately owned portions. Each portion has one responsible lead; there is no permanent primary lead on the whole job. Multiple portions may belong to the same lead.

PMs may update other PMs' open jobs. Description and responsible_lead are separate narrow patch fields. A stale description-only form cannot overwrite a newer lead assignment. Same-field updates follow the latest committed save; there is no stale-version approval. Completed work and closed/archived jobs cannot be edited by these commands. Maximum 100 total work entries per job, including the default and completed entries; no delete/archive/restore work command is introduced here.

Lead ownership immediately follows the existing job RLS boundary. It gives the active lead access to shared job details, contacts, work and ready files. Reassigning/clearing the last owned portion removes that ownership-based access. Another owned portion or an independently authorized helping entitlement may still grant access. Deactivated accounts are excluded from new assignments and existing access is denied by live membership checks. Issued file capabilities still have their documented expiration window; see job-files.md.

Only PMs may enumerate active leads for assignment; the directory returns ID/name, no email or unrelated customer data. Authorized readers get only the assigned lead names on their job's portions, including an inactive label for historical assignment. Helpers and leads cannot mutate ownership or grant themselves access. Raw work table writes remain revoked; anonymous RPC execution is denied.

## Commands and limits

Migration 0004 adds list_assignable_leads, list_job_work, create_job_work and update_job_work; existing applied migrations are unchanged. Create uses an actor/request UUID and canonical payload, returning the original work ID on an identical retry and rejecting changed payloads. The job row lock serializes create/limit checks; updates lock job then work and validate/lock a newly assigned active lead. UUID parent relationships and text are independently validated in SQL. Commands use employee tokens only, no administrative secret.

Audits retain the actor, work identity, operation, changed field names and timestamp; create also retains the request ID. Existing work identity/history is retained on reassignment. This slice does not provide an ownership history viewer or record complete before/after field snapshots. No-op updates add no extra audit event.

Job/work/lead assignment is not a calendar reservation or named helper assignment. Queues, visits, overlap enforcement, helper access derived from actual visit participants, completion/return commands and readiness follow in later slices. Do not infer staffing from the existing private information-access ACL.

## Verification and next actions

All 51 Node tests and TypeScript pass. Five new work tests use mocked transport and real action execution for validation, role boundaries, scoped command payloads, narrow changes and uncertain-save behavior. New database/tests/0004_work_ownership.test.sql prepares 58 assertions with rolled-back synthetic accounts/jobs/work/contact/file metadata. It covers SQL access, reassignment/removal of access, other-portion retention, live deactivation, direct-write/role/parent forgery, create replay/collision, narrow edits, no-op audit and limits. User confirmed all 58 SQL assertions passed. The suite does not exercise binary Storage, simultaneous database connections or UI behavior.

1. Completed in the existing test project; for a fresh environment only: copy database/migrations/0004_work_ownership.sql and apply once in test project vglhojtrccygjgupxsrd after 0001-0003. Migration prepared SHA-256: 469b2a638c2c960af44281a545cd33ba4249f6ccd1a211e6728f4eb10f0c6a82. No seed data/account setup or emails are added.
2. Completed: user reported 58 checks, 0 failed from the complete SQL suite. Record errors before any retry. Do not rerun earlier applied migrations.
3. Original work build passed and dev restarted. Inline editor changes need another full build after browser acceptance. Add two synthetic lead Auth accounts/profiles through controlled manual pilot setup; do not change the helper's role merely to make the dropdown work.
4. As PM, assign the existing default work to Lead A, confirm refresh persistence and Lead A job/contacts/files access. Rename it to a first portion; add a second portion for Lead B, confirm each sees shared context. Check blank input, cancel, unassign/reassign, former-lead denial after last owned portion, helper edit/new denial, and a two-tab description change preserving the newer lead assignment. Confirm failure/retry does not duplicate a portion.
5. Real phone, inactive-account, multi-connection and session/fault checks remain required. Commit/push after the checkpoint; continue to lead queues, then visits/staffing.

Inline acceptance: as Josh/PM refresh the job; edit/cancel description and lead without navigation; save/refresh; verify another row draft survives a save, and a stale description-only save preserves a newer lead assignment. Test Lead account exists (lead.test@example.com); second lead account not yet created. Do not change the helper role for testing. No SQL migration changed for inline editing.

User browser update: inline Cancel/Save/page retention and refresh passed. Whole job is now Kitchen cabinets, assigned Test Lead. Lead account sign-in/job list/detail and read-only work display passed. New lead contact creation request is prepared separately in 0005; see lead-contacts.md. Full production build after inline changes still pending.

Full normal-user production build after inline work and lead-contact changes passed. Inline Cancel/Save/refresh and lead read-only work view passed; remaining portions/reassignment/revocation checks are still pending. See lead-contacts.md for the separate verified contact expansion.

User superseded per-row buttons with one card-level Save/Cancel pair. This is implemented locally using a new atomic batch command in 0006, awaiting application/40 SQL checks/full build/browser verification. Existing individual update RPC/edit-route behavior remains; applied 0004 was not edited. See work-card-save.md.

Ownership/revocation browser checkpoint: user confirmed that assigning Test Lead only to cabinets leaves job access while countertops is unassigned. After clearing the final cabinet assignment, the lead jobs list was empty and direct job detail plus new-contact URLs showed Job unavailable. Initial apparent failure was consistent with clearing both leads, not an established code defect. User acknowledged restoring cabinets/Test Lead and countertops/unassigned as Josh/PM for subsequent development. Second-lead handoff, concurrent reassignment, stale-tab/fault and phone acceptance remain unverified. Shared card implementation was pushed as a79c78e; these results are documentation-only.

