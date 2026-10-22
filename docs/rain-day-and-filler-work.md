# Rain-day and filler work

Requested by Josh on 2026-10-22. Implemented locally in 0011 with the combined completion/return batch; database/build/browser acceptance is pending. Use combined-batch.md; no separate interim test of 0010 is needed.

## Confirmed needs

- R25: Mark a job as potential bad-weather work so suitable work can be found quickly when weather changes. A rain-cloud icon was suggested by Josh.
- R26: Create and maintain a list of flexible filler work that can be done whenever there is capacity, including punch-list work and small repairs. A scheduled date/time is not required.
- Keep interactions short and inline wherever practical, consistent with D40/D41.

## Proposed behavior

Rain-day suitability and filler classification are independent: an item may be either or both. Neither label confirms readiness, guarantees safe weather conditions, reserves staff, creates an appointment or changes ownership. Existing waiting/readiness information remains visible when selecting work.

Use a cloud icon plus an understandable text label/accessibility name for rain-day jobs. Show the marker on job lists/details and relevant queue/schedule entries. Provide a quick rain-day filter within the user's authorized records; helper visibility stays limited to assigned jobs.

Provide a Filler work list of open standalone jobs tagged Filler work, within existing job permissions and My/All scope. Use normal customer, phone and location fields. Dates/times remain optional; assignment and completion use existing work/visit rules. Preserve job/portion/return identities and history.

PMs edit job tags, matching existing scope-editing permissions. Completed/closed work retains its tags/history; the quick tagged lists show open jobs. No external weather service or automatic rescheduling is requested.

## Confirmed record model

Josh confirmed filler work is a standalone job tag. Use normal job customer/location/contact fields, ownership and permissions; no parent job or separate task system is required. Rain-day suitability remains independent. See trade-and-scope-icons.md for the additional project-scope markers.

## Consolidated acceptance

- Tag, clear and filter rain-day jobs; verify markers across relevant views and accessible labels.
- Add undated filler work, find it quickly and optionally schedule it without requiring a time slot.
- Verify either/both classifications, waiting-work visibility and no automatic staffing/readiness changes.
- Verify authorized editing, unrelated-job denial, retained completion history and retry-safe saves.
- Include these checks in a consolidated batch; resume completion/return acceptance using combined-batch.md.
