# Requirements baseline

Source: Handoff v1.0, 2026-10-20. Status is specified, not implemented, unless docs/status.md explicitly says otherwise. Stable IDs are retained through later phases. Proposed permission/time conventions remain proposals in their companion records.

| ID | Agreed behavior | Acceptance evidence | Phase |
| --- | --- | --- | --- |
| R01 | Individual admin, PM, lead, helper access; no ChatGPT dependency | Direct API allow/deny checks for each role, deactivated and anonymous accounts | 1 |
| R02 | Create job with customer, phone, address only | Atomic job + default work creation; optional generated title; no extra setup | 1 |
| R03 | PM defaults My Jobs and may switch to/edit All Jobs | Two-PM scenario; all-job permission enforced on server | 1 |
| R04 | Lead sees assigned jobs and relevant shared project work | Related-job access allowed; unrelated customer records denied | 1 |
| R05 | Helper reads only assigned-job details and personal assignments | Read permitted for assigned job; mutation and unrelated read denied directly | 1/2 |
| R06 | Job scope, contacts, private files, preparation/access notes | Authorized phone upload/download and one-tap call/text/directions | 1 |
| R07 | Work items support separate ownership, readiness, returns | Simple job hides structure; separate lead portions remain independent | 2/3 |
| R08 | Per-lead ordered queue; latest server save wins | Two PM saves; exact final order; concurrent contact edit retained | 2 |
| R09 | Day list default, calendar toggle; hours, half/all/multiple days | Date-only values survive timezone/DST; exact time remains optional | 2 |
| R10 | Leading/Helping are visit roles, not account permissions | Lead can help elsewhere without losing own lead privileges | 2 |
| R11 | Required help differs from named staffing | Help needed is visible; PM assigns; lead fills vacant assistance only | 2 |
| R12 | Named overlaps surfaced before saving; no displacement | Timed/calendar checks; concurrent bookings cannot bypass final transaction | 2 |
| R13 | Finish visit, finish portion, and close job are distinct | Return persists; one lead cannot finish another portion; job stays open | 2/3 |
| R14 | Ready default; dated or undated Waiting | Tentative future plans do not confirm readiness or delivery | 3 |
| R15 | PM or lead adds tentative/confirmed subcontractor commitment | Unknown time supported; Friday entry visible; no internal reservation | 3 |
| R16 | Follow-ups, short remaining-work notes, human handoffs | No mandatory percentages, narratives, steps, or invented finish dates | 3 |
| R17 | Narrow saves preserve unrelated edits; retries do not duplicate | Transactional participants; idempotency replay and conflict tests | 2 |
| R18 | Failed save is clear; retain unsent form where practical | Network failure/retry and session-expiry manual checks | 1–4 |
| R19 | Admin manages users/configuration/trade contacts on phone | Create/deactivate account and edit contact without code | 1/4 |
| R20 | Archive/deactivate; retain identity and change history | Reassignment, job closing and user departure preserve linked records | 1–4 |
| R21 | Database AND file recovery/export | Isolated restore with hashes; stable-link export; code rollback separate | 4 |
| R22 | Phone-first, large tap targets, no mandatory drag | Actual lead/PM/helper phone review of core workflows | 0/4 |
| R23 | Approx. $50 monthly initial operation; no unauthorized charges | Current-source estimate covers host, DB, auth email, files, backup and test | 0/4 |
| R24 | About 20 leads/30 active houses represented coherently | Deterministic seed now; indexed DB queries measured later | 0/4 |
| R25 | Tag a job as potential bad-weather/rain-day work and find it quickly in relevant views | Tag persists; clear cloud icon with text/accessibility label appears on job list/details and relevant queue/schedule entries; quick filter respects existing access | Initial build addition, 2026-10-22 |
| R26 | Maintain a list of standalone jobs tagged Filler work, including punch-list items and small repairs, without requiring a scheduled date or time | Create and find undated work; optionally schedule it later; filler and rain-day suitability can coexist; existing ownership, readiness and access rules remain enforced | Initial build addition, 2026-10-22 |
| R27 | Identify subcontractors by trade with icons; show project scopes on job cards and a compact Whole house indicator for full-scope projects | Recognizable icons with accessible labels; project scopes remain independent of subcontractor assignment; full scope list remains inspectable | Initial build addition, 2026-10-22 |

No payroll, time clock, accounting, estimating, purchasing, CRM expansion, portals, messaging capture, notifications, offline sync, automatic routing/rescheduling, AI scheduler, or critical-path engine. Tools links are optional only if trivial and cost-neutral. No shared account or permanent primary lead per job. No paid notification services.

2026-10-22 UI clarification (D40): minimize clicks across the program; use inline edits on the current job/schedule card wherever practical, avoiding separate edit screens. Visit dates, help needed, named staffing and cancellation now follow this locally; browser/build retest pending. Date-only plans allow multiple jobs per day (D39); time blocks remain optional.

2026-10-22 additions R25-R27 are implemented locally with 0011; combined database/build/browser acceptance is pending. See combined-batch.md and rain-day-and-filler-work.md. Filler work is a standalone job with a tag, using normal job details, ownership and access. Trade/scope markers are added as R27; see trade-and-scope-icons.md.

- R28: Calendar entries plan future days and staffing; do not require per-entry Finish actions or completion reporting. This supersedes earlier daily-finish UI requirements. Whole-job/portion close-out is a separate planning-lifecycle decision, not a daily carpenter check-off workflow.

- R29: One user-facing notion of work per job. Work may be entered initially or added later through the same Add work flow. No separate return-work category or workflow. Scheduling saves say Save work; removing dates preserves the work item. Preserve existing notes, ownership, dates and staffing while unifying the UI.

- R30: Named helping staff have no separate Plan selection. Compare requested helping count with distinct assigned helpers (excluding the coordinating lead); show a clear accessible warning icon/count on PM day/week calendar entries when short. Clear automatically when filled; zero need, cancelled and completed historical entries do not warn. Retain existing role, staffing and optional time rules.

- R31: Common work setup (description, lead, optional date, helpers needed, material availability) belongs in one inline Add work form and one Save work. Help/material availability must be editable without reopening the saved work or first choosing a date. Undated help requirements persist without reserving people, and prefill later scheduling. Keep one-day/no-time setup compact; extra date/time options may expand. Save all supplied fields atomically and preserve safe retries.

- R32: Job subcontractor contacts may have optional commitments containing a date, a note about promised work/needs, or both. Offer the first commitment during contact creation with one save; support inline later edits. Dated promises flag the PM/lead calendar even without a crew entry; no staffing reservation or access grant is implied. Preserve history on removal/contact type changes.
- R33: Every user with schedule access has Day, Week, Two weeks and Month views. Retain existing role/personal-job scope, PM My jobs/All jobs, inline editing and staffing warnings; include weekend subcontractor markers and safe month/year navigation.

- R34: Calendar cards put customer/address first, then work and project scope, followed by concise schedule/crew details. Customer name opens the job; a small accessible crew pencil edits dates/staffing in place, replacing redundant Open job and Edit plan & crew text actions in every calendar view. Retain unsaved drafts when the editor is collapsed and existing read/write scopes.

- R35: PM may archive and restore the same job for additional work/punch-list items. Preserve work ownership, history, files and contacts; hide inactive jobs from active lists/queues/calendars. Resolve current/future crew dates or subcontractor commitments first. No daily completion prerequisite, duplicate job or automatic rescheduling.
- R36: Dedicated handoff-note development is removed by the user (D60). Preserve the existing ordinary notes and recorded history.

- R37: Active administrators manage existing employee display names, account roles and active state in a simple inline directory. PM alone cannot administer accounts. Protect self/last-admin access, reject stale changes, retain assignments/history on deactivation and require eligible roles or reassignment for active staff. Manual pilot Auth onboarding/reset remains separate; no email/credential exposure.

- R38: Before pilot testing, simplify phone presentation: reduce nonessential whitespace, visible relevant facts without everyday expand arrows, understandable icons with accessible names, inline edits and one Save/Cancel pair. Keep usable touch targets and readable inputs, selected scopes for readers, all PM scope choices, permission boundaries, retained drafts and explicit uncertain-save feedback. Do not hide useful information or replace core Save/Cancel labels with unexplained icons.
