# Job archive and return for more work

User decision D60: dedicated handoff notes are not needed. Reversible job archive is in scope; a job may return for additional work or a punch list. Existing notes/history are preserved, not replaced with a new workflow.

## Behavior

PM opens Job options at the bottom of an active job and chooses Archive job after reviewing the explanation. Archive is organization, not a claim that every work item was completed. There is no delete operation or daily finish requirement. Today or future planned crew dates and dated subcontractor commitments block archive with a specific explanation; the PM must deliberately resolve those plans first. Old planned dates, undated work/notes, attachments, contacts, material data and work ownership remain intact.

PM finds jobs through Active/Archived beside My jobs/All jobs; ownership, tag filters and pagination persist. The archived view includes legacy closed jobs for recovery. An archived/closed job has a prominent Restore for more work action. Restore sets the same job back to open, without copying it or reopening completed historical work. Existing open work rejoins the lead queues under its retained owners; review before adding dates. Add new punch-list/additional work using ordinary Add work. Nothing is automatically scheduled or reassigned.

Operational calendars exclude inactive jobs. Subcontractor commitment calendars already follow the same open-job rule. Archive/restore uses the existing scheduling mutex and job lock, live PM authorization, expected-state checks, stable request receipts, private transition history and audit. Lost-response retries acknowledge the original request; an old archive retry cannot archive a job that was restored later. Current saved lifecycle is returned on replay.

Archived job pages offer review/downloads and restore, with normal editing/upload/removal controls hidden until restored. Existing backend metadata/file permissions are not expanded or comprehensively rewritten: archive is not an immutable-record security feature. Existing lead work ownership can retain historical read access under current RLS; former helper-only context is unavailable until open again. Restoring resumes existing assignment-based access; no new role or manual job-access grant is created.

## Validation and completed setup (do not rerun SQL)

164 Node checks and TypeScript pass. **0015 is applied**: the user confirmed the expected guarded SQL result (35 checks, 0 failed, synthetic fixtures removed). Do not rerun this or earlier bundles. They cover future/today guards, preserving work/contact/file metadata, queues/calendar removal, restore/additional work on the same job, stale requests, idempotency/history and unauthorized actors. File bytes/restore/concurrent race testing remain separate pilot gates.

Latest confirmed backed-up checkpoint is f767b9f; this new batch is local. Applied 0001–0014 remain unchanged. Stop normal-user dev with Ctrl+C (Y if prompted), then run this in ordinary PowerShell, not Supabase SQL:

```powershell
Set-Location -LiteralPath "C:\Users\jrbla\OneDrive\Projects\ChatGPT\Eigsti Scheduling"
npm.cmd run build
if ($LASTEXITCODE -eq 0) {
    Get-Content -Raw -LiteralPath ".\database\batches\0015_job_archive.sql" | Set-Clipboard
    Write-Output "Build passed; archive update copied."
}
```

After Build passed, paste into a new Supabase SQL query in the isolated project and Run once. Expected final row: **35 checks, 0 failed, 0015 applied; synthetic fixtures removed**. Do not run older bundles or separately apply migration/tests. Failed validation rolls back; duplicate application is guarded. Regenerate the new bundle with `node scripts/prepare-archive-batch.mjs` if unapplied sources change.

Restart dev with `npm.cmd run dev` for a grouped review:

1. As PM, archive a fictional job with no current/future crew dates or subcontractor promises. It leaves Active and its lead queue/calendar, appears under Archived, and retains the same details, contacts and attachments. Resolve live plans deliberately if the guard blocks; no work check-offs are required.
2. Restore from Archived, add ordinary additional/punch-list work and an optional date, and confirm the same job has its prior history and new work. Refresh to check persistence; legacy completed work must stay historical. Verify previous open ownership before scheduling.
3. Check that a job with a current/future crew plan or subcontractor promise is blocked from archive, with nothing silently cancelled or removed. Lead/helper accounts have no archive/restore controls.
4. Record actual outcomes, final build and one Git push. Device, concurrency, fault and full recovery gates remain separately pending.

User-reported grouped desktop review: works after archive/find/restore/additional-work instructions. No additional phone, concurrency, blocker or recovery results are inferred. Current batch awaits Git backup; last confirmed pushed checkpoint remains f767b9f.
