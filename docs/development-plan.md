# Development plan

| Phase | Scope and exit | State |
| --- | --- | --- |
| 0 | Repo docs, permissions, model, reproducible synthetic scenarios, phone interactions, ownership and cost/sign-in validation | Foundation prepared; company inputs and phone review pending |
| 1 | Individual sign-in, backend policies, three-field job + default work, My/All Jobs, contacts/scope/files, phone actions | Initial app screens and full build passed; 21 Node and 35 user-reported DB checks passed; user browser checks passed PM sign-in/create/persistence/logout and unassigned helper denial; editing/contacts/files/account lifecycle pending |
| 2 | Queues, week/calendar, visits, named staffing, availability, completion and returns; concurrent/retry checks | Not started |
| 3 | Readiness, tentative promises, sub commitments, follow-ups, portion handoff, PM filters/history | Not started |
| 4 | Two leads, PM and helper pilot; phone admin; export and DB+files restore; release candidate | Not started |

Phase 0 exits only after ownership and account prerequisites are recorded, hosting/sign-in is confirmed, budget assumptions understood, calendar convention checked, and lead phone workflow reviewed. A local fixture or documentation check does not satisfy authorization or recovery exits.

PM editing is verified and uploaded as 018a1d2. Current bounded implementation: additional job contacts (job-local customer/site/trade contacts), PM create/edit/archive, authorized read/call/text/email, narrow updates and creation retry deduplication. Code, new migration 0002 and a 60-check SQL suite are prepared; 31 Node tests and TypeScript pass. Next apply/test 0002, run full normal-user build and browser acceptance, then commit/push. Private files and account lifecycle follow. Session expiry, live deactivation, assigned-helper access, multi-connection tests and phone review remain required.

At each meaningful checkpoint: update status and decisions, run appropriate checks, commit. Keep release review separate from code completion. No production data in previews, no paid staging by default. Current planning allowance remains 80–120 focused engineering/testing hours for pilot, excluding account delays and field iteration; Phase 0 discovery gives no evidence to tighten it. Re-estimate after stack setup and after Phase 2.
