# Subcontractor commitments and longer calendar views

Implemented locally on 2026-10-23. Latest confirmed pushed checkpoint before this batch: cb3ba26. Migrations 0001–0013 are already applied; never rerun their bundles. 0014 is now APPLIED: user confirmed 48 checks, 0 failed, 0014 applied; synthetic fixtures removed. Do not rerun it or any earlier bundle.

A job contact with Type Subcontractor can hold multiple optional commitments. Record a date, a note, or both (at least one for a saved commitment). Adding a new subcontractor and its first commitment uses the same contact form and one save. Existing commitments add/edit/remove in place under that contact. Contact removal or changing its type archives its commitments with history; switching it back does not revive old promises.

PMs can manage commitments on open jobs. An active lead can manage commitments on an open job where they own open work or coordinate a planned crew entry. Helpers with job access can read the contact context but cannot mutate commitments or browse the planner commitment calendar. Admin-only is not a planning role. All authorization is enforced in scoped RPCs, independently of UI controls.

Dated commitments show a purple flag with job, subcontractor and note on PM/lead calendars, even with no crew work that day. Weekends are included. Undated notes remain on the contact. These records never create work, visits, people assignments, bookings, or new job access, and do not change materials readiness. The global directory and project scope icons remain separate.

Every authorized schedule page offers Day, Week, Two weeks and Month. PM My jobs/All jobs and each employee's existing staffing scope persist through navigation. Month uses complete Monday–Sunday rows, includes adjacent-month dates, and advances by calendar month with day clamping. Queries are split into at most 28 days to respect existing RPC limits; repeated multi-day entries are deduplicated. Month work entries expand in place; smaller screens use a readable two-column date layout. Staffing warnings appear in every PM view. Missing commitment schema displays an explicit notice while retaining crew plans; access/network errors are not hidden as empty schedules.

Validation: 151 Node checks and TypeScript pass. Includes calendar DST/leap-year/month boundaries, deduplication, scope-preserving navigation, weekend commitments without staffing, helper isolation, role/unknown-save boundaries, contact one-save setup and immutable bundle bodies. All 48 SQL fixture checks passed in Supabase; the user confirmed the guarded application/fixture-cleanup result. A new normal-user production build and authenticated desktop/phone acceptance remain pending.

## Applied database update (historical setup; do not rerun)

Stop the running dev server in its PowerShell with Ctrl+C; if asked Terminate batch job, enter Y. In ordinary PowerShell (not Supabase SQL):

```powershell
Set-Location -LiteralPath "C:\Users\jrbla\OneDrive\Projects\ChatGPT\Eigsti Scheduling"
npm.cmd run build
if ($LASTEXITCODE -eq 0) {
    Get-Content -Raw -LiteralPath ".\database\batches\0014_subcontractor_commitments.sql" | Set-Clipboard
    Write-Output "Build passed; 0014 database update copied."
}
```

The following describes the already completed application, not a next action. Only after Build passed: open a new Supabase SQL query in the isolated project, paste the copied SQL and Run once. Expected final row: **48 checks, 0 failed, 0014 applied; synthetic fixtures removed**. The bundle requires 0013, rejects a repeated 0014, fails on any fixture assertion, and rolls synthetic fixtures back before committing the new schema. Do not separately run the migration or tests if using this bundle. Regenerate byte-for-byte bodies with `node scripts/prepare-commitments-batch.mjs` when the unapplied source changes.

Then restart normal-user dev with `npm.cmd run dev` and open http://127.0.0.1:4310/jobs . Do not run builds over an active dev process.

## Grouped review

1. As PM, add a Subcontractor contact with an optional date/note and save once; confirm both appear together. Add another commitment to that contact, including a note without a date. Ordinary customer contacts and undated subcontractor contacts must still work.
2. Open Job schedule. Check Day, Week, Two weeks and Month, Previous/Today/Next, My jobs/All jobs, and a weekend commitment with no crew work. The note and correct job/contact link should appear; no helper assignment should be created. Existing crew work and short-staffing warnings must remain visible.
3. Edit/clear a commitment date, refresh, and check its flag moved/disappeared. Remove a commitment and confirm it remains absent after refresh. Archive a synthetic contact only when appropriate and confirm its flags disappear too.
4. Assigned lead can manage that job's subcontractor commitments; unassigned lead cannot access the job. Helper sees assigned crew work plus permitted job contact notes, with no commitment edit controls. Keep passwords private. Check phone layout and inline editing without additional edit pages.
5. Record observed results, then one Git commit/push. Full phone/concurrency/fault/recovery and pilot gates remain separate; do not claim them from automated results.

User desktop review passed: calendar views, subcontractor flag/note visibility and moving a commitment to a different date. Other grouped checks remain unreported. Batch is still local pending Git commit/push.

D59 calendar-card refinement: customer/address/phone lead the card, then work and scope. Customer name opens the job; crew pencil replaces the separate Edit plan & crew and Open job actions. Shared across all calendar views, with no SQL change and no permission expansion. 154 Node checks and TypeScript pass; fresh browser/phone review and final production build remain pending. D58 browser successes above remain valid for the earlier layout.
