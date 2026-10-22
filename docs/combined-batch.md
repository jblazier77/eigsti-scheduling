# Combined completion, job-tag and trade batch

User verification update: full normal-user production build passed including /subcontractors. User then reported combined SQL result: 111 checks, 0 failed, 0010 and 0011 applied; synthetic fixtures removed. Do not rerun the setup/update instructions below; they are retained as historical procedure. Next is dev restart and the grouped browser checklist. Browser acceptance and commit/push remain unconfirmed.

Prepared 2026-10-22 from uploaded checkpoint a91da8c. Implementation is local, not confirmed committed/pushed. Applied 0001-0009 are unchanged. 0010 and 0011 are now applied per the user-reported 111/0 combined result. This replaces the earlier 0010-only setup/test instructions.

## Included behavior

- Finish scheduled work; explicitly complete/reopen an owned work portion; add, plan and resolve dated or undated return work. Finishing a visit does not complete its portion or whole job. Completing a portion does not close another portion/job.
- Independent Potential rain-day work and Filler work tags. Filler work is an ordinary standalone job: customer, phone and location; no required appointment/time. Create the job/default portion/tags atomically with retry protection.
- Job-list All work / Rain-day options / Filler work / Rain-day filler filters, applied on the server before pagination. Tagged lists show open jobs within existing My/All and RLS boundaries. Assigned leads/helpers do not gain access to unassigned filler jobs.
- Compact job scope icons and optional Whole house marker with inspectable trade labels. Tags/scopes appear on job list/details, lead queues and schedule entries. Trade lists expand with a tap; project scopes do not require subcontractor assignment.
- Inline job-tag/scope edit with one Save/Cancel and narrow patches. PM only, matching existing job-scope editing. No automatic readiness, staffing, dates or scope inference.
- /subcontractors: shared multi-trade directory, filter by trade, call/email, inline add/edit and audited archive. PM/admin manage, lead reads, helper has no directory access. No automatic linking of directory contacts or commitments to projects. Existing job contacts remain independent.

Initial catalog: roofing, siding, windows/doors, framing, electrical, plumbing, HVAC, drywall, painting, flooring, cabinetry, tile, concrete, landscaping, general repairs/punch list. Adding catalog types later requires coordinated server/client validation; the catalog is not a required whole-house checklist.

## Verification and boundaries

98 automated Node checks and TypeScript pass. Includes independent labels/validation, narrow updates, filtered pagination, exact retry identity, atomic classified creation, role-forgery denial, employee-authenticated transport and rendered accessible/compact markers. Database execution, actual browser/phone behavior and production build remain pending. The 111 prepared SQL checks are not reported as passed until the project runs them.

The combined file database/batches/0010_0011_combined.sql has one transaction, ordered exact 0010/0011 DDL, and two guarded test suites. Each suite removes its fictional users/jobs/calendar/audits under a savepoint before the final commit. Any failed assertion aborts the update. Preflight stops if the completion table or subcontractor table already exists, or the 0009 RPC is missing. This is a duplicate-application guard, not a complete migration fingerprint or production-release mechanism. Use only the known isolated test project.

## One setup sequence

Stop the app in its PowerShell with Ctrl+C (answer Y if asked). In normal user PowerShell at the project:

```powershell
Set-Location -LiteralPath "C:\Users\jrbla\OneDrive\Projects\ChatGPT\Eigsti Scheduling"
npm.cmd run build
if ($LASTEXITCODE -eq 0) {
    Get-Content -Raw -LiteralPath ".\database\batches\0010_0011_combined.sql" | Set-Clipboard
    Write-Output "Build passed; combined database update copied."
}
```

After a successful build, paste into a NEW SQL editor query in test Supabase project vglhojtrccygjgupxsrd and Run once. Expected final result: 111 checks, 0 failed, 0010 and 0011 applied; synthetic fixtures removed. If an error occurs, stop; do not apply other migrations or claim success. Keep the exact error. The transaction may require ROLLBACK before a corrected attempt, depending on the SQL editor connection. If preflight reports an existing 0010/0011, verify what was applied and prepare only the remaining work.

After confirmed SQL success, run npm.cmd run dev and use the grouped checklist below. Avoid building while the dev server uses the same .next directory. Agent does not perform OneDrive build cleanup/deletion; normal user production build remains the established check.

## Grouped browser acceptance

Use fictional test data. Do these together; report results in one message, naming any failed group.

1. **Find and edit work:** as Josh/PM, use an existing test job. Select rain-day + filler, choose several scopes, Save. Confirm markers on Jobs and relevant queue/schedule entries; open a fresh tab to confirm persistence. Try changing several selections then Cancel. Turn on Whole house and confirm compact cards plus expandable scope names. Try each job filter, including both tags. Return to My/All defaults as desired.
2. **Standalone filler:** from Filler work choose + Filler job. Create with fictional customer/phone/location and no dates. Confirm it appears in the open filler list with one default portion and no calendar booking. Assign a lead and optionally plan a date-only entry using existing inline work/scheduling. No forced time slot.
3. **Subcontractors:** add a fictional company with two trades (phone/email optional), filter by either trade, edit one field, Save and reopen. Try Cancel on another draft. Archive the test contact and confirm it disappears. Changing a directory trade must not change project scopes. Leads can read but cannot edit; helpers cannot open the directory or browse unassigned filler jobs.
4. **Completion and returns:** on a scheduled entry, Finish scheduled work with Return trip needed + a short undated note. Portion/job stay open. Plan the linked return, finish that entry, explicitly mark its return handled. Finish/cancel other planned entries for that portion, then Complete this portion; other portions/job stay open and it leaves its queue. Explicitly reopen for new return work and confirm the same portion rejoins the queue without an automatic appointment. Helper remains read-only; lead controls are limited to owned/coordinated work.

After all groups pass, record build/SQL/browser evidence, then one commit/push. Phone usability, real concurrent transactions, session/fault tests, production provisioning and DB+file recovery remain separate pilot gates.

## Regeneration

node scripts/prepare-combined-batch.mjs reproduces the combined file from exact migration/test sources. Do not change applied migrations after successful application. Make future corrections in a new ordered migration.
