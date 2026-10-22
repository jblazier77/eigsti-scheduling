# Architecture

## State and proposed technology

Current implementation: pinned TypeScript/React/Next.js app with Supabase Auth/PostgreSQL/private Storage in an isolated test project. Jobs, PM edits, contacts, private files, password changes, work ownership and atomic card saves are implemented and checked to the extent in status.md. Applied migrations 0001-0006 are unchanged. Lead queue code/migration 0007 is prepared locally, awaiting SQL/build/browser/concurrency acceptance. No production deployment. Proposed hosting remains Vercel Pro; cost/ownership/recovery gates are separate from implementation.

Sign-in baseline: individual app invitation/password accounts. Company Google email is not integrated with app sign-in, calendars, contacts or files.

Requests authenticate an individual, resolve current active account roles, authorize the requested record/action, then execute a narrow command. RLS is a second boundary for direct database/storage API access. Administrative secrets never go to a browser. UI visibility is not permission enforcement.

## Relationships (proposed schema contract)

All mutable records use UUID, created_at/updated_at (UTC), created_by/updated_by. Historical actors survive deactivation. Use explicit foreign keys; archive rather than cascade-delete operational history. The fixture IDs are deterministic review keys; production UUID mapping comes with migrations.

| Record | Relationships and invariants |
| --- | --- |
| users / user_roles | Auth identity + active flag; multiple account roles allowed; no public signup; promotion only by admin |
| company_settings | Single company; America/Chicago; calendar/half-day rules versioned; no multi-company product |
| jobs | Required customer_name, readable phone + normalized action phone, address; responsible_pm nullable until assigned; generated title; open/closed/archived |
| work_items | job_id; responsible_lead nullable; description; ready/waiting_date/waiting_unknown; optional wait date; open/completed; duration range and crew assumptions optional; remaining note |
| lead_queues / lead_queue_entries | One queue per lead; unique work membership in queue, rank; queue revision; order saved atomically after locking lead queue |
| visits | work_item_id; planned/completed/cancelled; tentative/confirmed; local date range OR timezone-aware timed interval; all_day/morning/afternoon/timed; required_helpers separate from participants |
| visit_participants | visit_id/user_id; leading/helping; one responsible coordinating lead; inherited visit dates; split visit when crew dates vary; no permanent job primary lead |
| subcontractor_commitments | job_id, optional work_item_id, trade/contact, local date/window, optional times, tentative/confirmed, attendance/prep flags and note; creates no staff assignment |
| contacts / job_contacts | Reusable trade directory; customer/additional job contacts linked explicitly; no unrelated customer directory disclosure to helpers |
| follow_ups | job_id plus optional work_item_id, owner, note, optional due date, open/done; show next steps without daily reports |
| attachments | job_id, optional work_item_id; private object key, filename, MIME, byte length, checksum, upload state; no public URLs |
| audit_events | entity/id, actor, UTC timestamp, command/request ID, relevant field changes; immutable to normal app roles |
| idempotency_keys | actor + operation + request UUID, payload hash, result reference; reused key with different payload rejected |

## Command boundaries

- CreateJob atomically inserts job + one default work item + audit record; retry uses same request ID.
- EditJob patches explicit permitted fields. A job editor never submits visits, contacts and the queue as one replace-all blob.
- ReorderLeadQueue validates full membership and locks one queue; last committed order wins. Audit records the final revision and actor, without stale-version rejection/approval workflow.
- SaveVisit/FillVacantHelp authorize current coordinator or PM, lock affected user calendars in stable user-ID order, recheck overlaps, update visit + participants + audit atomically. Conflicting attempts return a conflict and leave both records unchanged. Reschedule never silently moves other visits.
- CompleteVisit, CompleteMyPortion, CreateReturnWork and CloseJob are distinct commands. A return leaves work open and links a follow-up; completion never cascades across other portions.
- DeactivateUser changes live access checks immediately, blocks new assignments and revokes sessions where supported; preserve actor history. No reliance solely on long-lived JWT role claims.

## Dates and availability proposals

Date-only work stays as PostgreSQL date; timed work uses timestamptz + company zone. Never parse YYYY-MM-DD as an instant for calendar display. Timed overlap uses [start,end), so adjoining visits do not conflict. Date ranges are inclusive in UI; expand to company working intervals for checks. Confirmed company default (2026-10-20): Monday-Friday, 07:00-15:30, morning 07:00-12:00, afternoon 12:00-15:30, America/Chicago. Specific holiday/overtime exceptions remain to define; implement and test mixed timed/all-day overlaps against these confirmed defaults. A working-calendar change must recheck future assignments and show conflicts.

## Authorization, files, and queries

See permissions.md for resource scopes. Job relevance derives from work ownership or named visits, not arbitrary client-supplied job IDs. Directory availability endpoint returns minimum person/busy interval information without unrelated customer names or addresses. Private signed file links are short-lived after job authorization. Proposed upload policy: JPEG/PNG/WebP/PDF up to 10 MiB each; verify MIME signatures, sanitize filenames, prohibit executable/HTML/SVG; HEIC conversion/support remains an actual phone pilot question. Stage upload, finalize authorized metadata, reconcile orphan files safely. Apply authorization to metadata, download, upload, replace and delete.

Proposed indexes: work_items(responsible_lead,completion), jobs(responsible_pm,lifecycle), visits(work_item_id,start_date), participants(user_id,visit_id), commitments(job_id,start_date), follow_ups(owner,status,due_date); index timed ranges for availability. Paginate All Jobs and related queries. Capacity fixture is not a benchmark; PostgreSQL EXPLAIN and concurrent command tests await Phase 1/2.

## Queue implementation checkpoint 2026-10-22

0007 prepares private ordered UUID arrays per lead plus immutable event snapshots, RPC-only PM-any/lead-own access, automatic membership triggers, actor/request-safe reorder and latest-commit-wins without revision rejection. Exact membership changes require reload. Queue membership mutations and order saves use one company-wide advisory transaction lock before queue row locks for this small-company phase; read RPCs take no such lock. Order saves do not lock job/work rows, avoiding reverse lock order against existing job->work->queue commands. This is an explicit throughput tradeoff, and simultaneous multi-connection verification remains pending. See lead-queues.md.
## Visits slice 0008 (prepared, not applied)

Queue checkpoint 6285665 is uploaded and 0007/58 checks/user build/core browser checks passed. New 0008 prepares date-only visits, optional timed reservations, named staffing, helper access, immutable private snapshots and scoped day/week views. User clarification D39: date-only plans permit several jobs per day and are not exclusive hours; shared-day warnings surface workload. Only explicit all-day/half-day/timed slots expand into [start,end) bookings. Schedule mutations take the scheduling mutex before parent locks and sorted person calendar locks; future lifecycle/account commands must preserve that protocol. See scheduled-visits.md for boundaries and pending real database evidence.
