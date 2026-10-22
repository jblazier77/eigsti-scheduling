# Development plan

Updated 2026-10-21. The architecture's numbered implementation phases remain unchanged. The user's new Phase 2 list means post-pilot release scope, recorded in post-pilot.md; scheduling remains initial scope.

| Phase | Scope and exit | State |
| --- | --- | --- |
| 0 | Repo docs, permissions, model, synthetic scenarios, phone interactions, ownership and cost/sign-in validation | Foundation prepared; company inputs and phone review pending |
| 1 | Individual sign-in, backend policies, three-field job + default work, My/All Jobs, contacts/scope/files, phone actions | Core implementation and recorded desktop checks passed; phone/integration/account administration checks remain. Email invitations/recovery deferred by user; manual pilot provision |
| 2 | Lead ownership, queues, week/calendar, visits, named staffing, availability, completion and returns; concurrency/retry checks | Work ownership implemented locally; migration 0004 and 58 SQL checks await application/execution. Queues/visits/staffing not started |
| 3 | Readiness, tentative promises, sub commitments, follow-ups, portion handoff, PM filters/history | Not started |
| 4 | Two leads, PM and helper pilot; phone admin; export and DB+files restore; release candidate | Not started |

Phase 0 exits only after ownership/account prerequisites, hosting/sign-in, budget assumptions, calendar convention and lead phone workflow are checked. Local fixtures/docs do not satisfy authorization or recovery exits.

Latest uploaded checkpoint: e95f6ea (verified password changes), following files 193c50d, contacts dea0af9 and PM editing 018a1d2. User reported 35 initial, 60 contact and 66 file SQL checks passing, with full production build through /account. See status.md for precise browser evidence and limits; files still need phone/HEIC, near-limit, retry/fault, assigned-helper and URL expiry acceptance.

Current bounded work: PM lead assignment and optional separately owned work portions, preserving the default Whole job. 53 Node tests and TypeScript pass. User confirmed 0004 applied, all 58 SQL checks and original work build passed; PM inline work Cancel/Save/refresh and lead read-only job access passed. User-requested lead contact creation is applied through 0005; 32 SQL checks, full build, lead add/refresh and helper direct-create denial passed per user. Next commit/push this checkpoint, then remaining portion/reassignment browser checks. See work-ownership.md. Queues, then visits/staffing follow. Session expiry, live deactivation, multi-connection and phone tests remain required before pilot.

Email invitations, self-service forgotten-password recovery and custom SMTP/DNS setup are deferred to post-pilot. An external manager handles DNS; SMTP is off. Pilot onboarding/reset may use controlled manual administration and private credential handoff, with employees changing passwords through My account. First-login changes are not forced. Phone account administration/deactivation remain initial scope. See accounts.md and post-pilot.md.

At meaningful checkpoints: update status/decisions, run appropriate checks, commit/push through user PowerShell. Release review remains separate from code completion. No production data in previews or paid staging by default. Planning allowance remains 80-120 focused engineering/testing hours for pilot, excluding account delays and field iteration; re-estimate after scheduling integration.

User workflow update: 85cad7a was pushed. Replaced per-portion controls in the PM card with one shared Save/Cancel draft. New 0006 makes all changed portions one atomic, retry-safe save; 58 Node tests and TypeScript pass. Next apply 0006, run its 40 SQL checks, full build and card browser acceptance. See work-card-save.md.

Shared work-card verification: 0006 applied; user reported 40 SQL checks/0 failed, one Cancel resetting both drafts, one Save saving both portions on the job page, corrected idle button state, refresh persistence and final production build passed. 58 Node tests/TypeScript pass. Commit/push next; remaining reassignment/revocation and scheduling work continue afterward. See work-card-save.md.

Ownership acceptance checkpoint: a79c78e pushed. User browser checks confirmed access through one remaining owned portion, loss of jobs-list/direct-job access after final ownership cleared, and direct contact-create denial after revocation. Test setup restored to cabinets/Test Lead and countertops/unassigned. Save this documentation checkpoint, then begin per-lead ordered queues; second-lead handoff, multi-connection/fault and phone checks remain separate.

