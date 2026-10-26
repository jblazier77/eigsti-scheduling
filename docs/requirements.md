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

- R39 (queued after October 25 local review): Reuse the full job-details layout for creation. Minimum required fields and Save job appear first; optional details can be supplied below in the same flow, with a minimal save allowed. Preserve safe creation, drafts and permissions.
- R40 (queued after October 25 local review): PM sets a simple optional numeric job priority on the job card. Lower numbers come first in PM and lead job lists; unnumbered jobs follow, with stable ties. Retain access scope and existing work-queue/calendar semantics; no complex priority system.

- R40 clarification (October 26): Display the PM-set job priority near the top of job details as well as using it to sort PM/lead job lists. Leads see the saved value; PM controls editing.
- R41 (queued): PM landing view includes a compact summary of their jobs/tasks with unfilled or partially filled help requests, including undated requests, requested/assigned counts and direct staffing access. Reuse existing visibility and shortfall rules; no notifications.
- R42 (queued): PM and authorized lead may enter/edit optional approximate days per work task, including fractional days. Show the estimate on saved work cards; do not require it, track actual time or automatically reserve days/staff from it.
- R43 (queued): Saved work uses compact cards with bold task titles and visible relevant details, directly editable in place with minimal clicks and one Save/Cancel per context. Preserve drafts, permissions, scheduling semantics and planning-only purpose.

- R43 clarification (October 26): All editable work fields must be visible together in the work card, without an edit pencil or expander to reveal ordinary inputs. One Save/Cancel covers work name, lead, estimated days, help, materials and dates/crew. Keep existing role restrictions and read-only views.

- R40 clarification: PM priority input is directly visible/editable in the job card; no edit button. Save on blur or Enter, then re-sort by the confirmed persisted value. Preserve filters, visibility scope, pagination correctness and safe uncertain retries.

- R44: PM may multi-select eligible helping staff directly in the work card without first entering Helpers needed. Automatically allow at least the selected number of people while retaining larger unfilled requests. Dates and named helpers save in one transaction, including the first dated save. Undated helper requests remain valid; reserving named people requires dates. Preserve lead/coordinator restrictions and availability validation.

R45: Administrators can create employees directly from Employees using name, email, temporary password and roles (Helper default), with no Supabase copy/paste for each account. Preserve scoped access, secret isolation, retry recovery and existing role/deactivation safeguards. No email delivery dependency.

R46: Full new-job setup must support the same helper multi-select as existing-job Add work, with optional count, automatic minimum spaces and one atomic Save job for work/date/crew. No second visit to job details is required to assign crew.

R47: PM may save scheduled work and named helpers while lead is Not assigned yet. Show Lead needed on work and calendar; preserve date/crew when a lead is assigned later. Never reserve a fake lead or let null ownership grant lead editing rights.

R48: Allow Saturday work in creation/editing, calendar display and named staffing reservations. Workweek is Monday-Saturday; multi-day ranges include Saturdays and skip Sundays. Preserve optional dates/times, no-lead planning and existing conflict/permission checks.
