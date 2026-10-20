# Development plan

| Phase | Scope and exit | State |
| --- | --- | --- |
| 0 | Repo docs, permissions, model, reproducible synthetic scenarios, phone interactions, ownership and cost/sign-in validation | Foundation prepared; company inputs and phone review pending |
| 1 | Individual sign-in, backend policies, three-field job + default work, My/All Jobs, contacts/scope/files, phone actions | Initial backend code and migration authored; 18 Node checks passed, DB/framework integration blocked |
| 2 | Queues, week/calendar, visits, named staffing, availability, completion and returns; concurrent/retry checks | Not started |
| 3 | Readiness, tentative promises, sub commitments, follow-ups, portion handoff, PM filters/history | Not started |
| 4 | Two leads, PM and helper pilot; phone admin; export and DB+files restore; release candidate | Not started |

Phase 0 exits only after ownership and account prerequisites are recorded, hosting/sign-in is confirmed, budget assumptions understood, calendar convention checked, and lead phone workflow reviewed. A local fixture or documentation check does not satisfy authorization or recovery exits.

Next bounded implementation: resolve package-registry access and an isolated Supabase/PostgreSQL test runtime; apply/test migration 0001 and verify actual Auth; pin framework dependencies and wire the existing backend modules into the phone app. Then add contacts/private attachments and user administration to complete Phase 1. Phase 0 company setup/phone review remains open; this preparatory Phase 1 checkpoint does not waive its exit.

At each meaningful checkpoint: update status and decisions, run appropriate checks, commit. Keep release review separate from code completion. No production data in previews, no paid staging by default. Current planning allowance remains 80–120 focused engineering/testing hours for pilot, excluding account delays and field iteration; Phase 0 discovery gives no evidence to tighten it. Re-estimate after stack setup and after Phase 2.
