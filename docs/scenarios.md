# Verification scenarios

Data: `demo/synthetic.json`, reproducible with `npm run seed`. All names/addresses are invented; reserved 555 phone numbers are review placeholders. IDs are stable fixture keys. Each future scenario starts from a reset synthetic test database. Fixtures now cover entity relationships only; none of the behavioral checks below is claimed passed by fixture generation.

| ID | Handoff scenario and setup | Required behavioral check | Verification stage |
| --- | --- | --- | --- |
| S01 | lead-01 queue includes ten window jobs; job-03 waiting unknown | Schedule ready work, postpone for access, fill opening without office dispatch | Phase 2 phone + commands |
| S02 | job-11 framing work-11 lead-01; work-finish lead-02 | Dates and completion independent; one completion cannot close other work | Phase 2/3 |
| S03 | visit-03 lead-01 Leading, lead-02 Helping | Atomic move updates both schedules; conflict on either person blocks save | Phase 2 concurrent commands |
| S04 | visit-01 has helper-01; visit-02 has vacant helper need | PM assigns; lead fills vacant need; occupied staff cannot be silently taken | Phase 2 |
| S05 | sub-01 electrician Friday 2026-10-23, no time | PM/lead entry visible in job/week; internal staffing unchanged | Phase 3 |
| S06 | Expand work-01 remaining note/effort | No required fake end date, financial change order, or percent report | Phase 3 phone |
| S07 | Finish visit-01, missing trim | Visit complete; remaining work/return persists; job open | Phase 2/3 |
| S08 | work-finish waiting 2027-03-09, visit-04 tentative | Does not auto-confirm delivery or block job-11 framing | Phase 3 |
| S09 | pm-01 and pm-02 jobs; helper-01 assigned job-01 | PM My/All default; helper direct API denied for job-02 and every mutation | Phase 1/2 API/RLS |
| S10 | Two PM clients hold same lead-01 queue | Last committed order exact; contact edit by third client survives; history includes both | Phase 2 concurrency |
| S11 | Drop response after commit then resend same request ID | One visit, one audit effect; no false success on actual failed commit; payload mismatch rejected | Phase 2 fault injection |
| S12 | admin-01; former-01 inactive; trade contact | Phone invite/deactivate/contact edit; deactivated session denied immediately | Phase 1/4 |
| S13 | Reassign work-01 with existing history | Actor history retained; close requires all portions handled or PM explicit resolution | Phase 3 |
| S14 | Synthetic job + private sample file with checksum | Isolated DB+auth+file restore reconciles IDs/counts/hash/access; measure recovery | Phase 4 restore drill |
| S15 | 20 active leads, 30 active houses, 10 window jobs | DB reset/seed; filters correct; capture queries/p95 and EXPLAIN, realistic visit/file volumes | Phase 4 capacity |

Extra technical cases: adjacent timed intervals, DST transitions, all-day vs timed, mixed half-day overlap, holiday/weekend rules after confirmation, two concurrent helper bookings, forged relationship IDs, signed-file URL expiry, invalid upload types, queue membership changes during reorder, and expired sign-in with unsent form. These need real backend checks, not duplicated prototype tests.
