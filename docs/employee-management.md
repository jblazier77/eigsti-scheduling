# Employee management

D61 scope: administrators manage existing employee app profiles from /employees with inline name, account-role and Active controls. One Save/Cancel per employee draft. Search and All/Active/Inactive filtering; one row edited at a time. Footer Employees link is admin-only. No new Auth account creation, Auth email directory, password/reset interface, credential handling, paid provider, email integration or automatic enrollment.

PM alone cannot manage accounts. Active Administrator authority is checked on page/action and again in every scoped database command. Raw app_users writes remain revoked. Directory RPC returns only id/name/roles/active/version and counts of open lead work/upcoming scheduled entries, not Auth secrets or emails. Deactivation immediately removes operational app access under existing live profile/RLS checks; it does not claim to revoke all issued Auth tokens. App authorization remains denied while inactive even if Auth sign-in succeeds.

Deactivation preserves work ownership, crew entries, bookings and history; PM must review existing plans. Reactivation resumes existing role/assignment-based access. No employee or record is deleted. An active account cannot lose Lead while owning open work on open jobs or coordinating today/future plans; it cannot lose both Lead/Helper while helping on today/future work. Deactivation itself is permitted so access can be stopped without first erasing historical assignments. Review and reassign before changing the active employee's role.

Self-deactivation and removal of one's own Administrator role are prohibited. Another active admin must do that. This stronger self-protection also preserves the last active administrator: profile editors serialize, lock actor/target in stable order, and recheck current authority after locking. A second concurrent editor whose authority was removed cannot proceed. Manual Supabase operator changes remain outside this application guard. No automatic first-admin grant or privilege escalation is added.

Each save includes exact original updated_at, a stable request UUID and normalized full profile values. Stale saves fail explicitly. Exact retries acknowledge current saved profile without restoring old roles/activity; payload changes on the same request fail. Private before/after events retain actor/target identity and are not exposed to ordinary profiles. Operational directories/menus refresh after confirmed writes only. Unknown results retain/freeze the draft for identical retry.

## Current checkpoint

Previous archive slice is backed up as **d585a13**, confirmed by clean workspace/tracking branch at this turn's start. 0001–0015 are applied. **0016 application was reported successful by the user** after the expected 33-check guarded instructions. Do not rerun it. **173 Node checks and TypeScript pass**. User reported the build/copy/SQL step worked; exact full build output was not separately supplied. Grouped employee-screen/browser/phone verification remains pending. Current employee batch and these notes are local and uncommitted. Do not rerun 0015 or earlier bundles.

## One update when ready

Stop the user's dev server in its normal PowerShell with Ctrl+C (Y if prompted). In ordinary PowerShell, not Supabase SQL:

```powershell
Set-Location -LiteralPath "C:\Users\jrbla\OneDrive\Projects\ChatGPT\Eigsti Scheduling"
npm.cmd run build
if ($LASTEXITCODE -eq 0) {
    Get-Content -Raw -LiteralPath ".\database\batches\0016_employee_management.sql" | Set-Clipboard
    Write-Output "Build passed; employee update copied."
}
```

Only after the build passes, paste the copied SQL into a new query in isolated Supabase vglhojtrccygjgupxsrd and Run once. Expected final row: **33 checks, 0 failed, 0016 applied; synthetic fixtures removed**. This guarded update requires 0015, refuses duplicate 0016, validates fixtures and rolls them back before committing DDL. No live employee is enrolled or promoted by it. Regenerate with `node scripts/prepare-employees-batch.mjs` while unapplied if sources change.

Restart normal-user dev, then visit http://127.0.0.1:4310/employees . An existing active Administrator role is required. If Employees is absent or redirects, verify the operator's app profile in Supabase rather than relaxing the admin-only rule. The app cannot bootstrap its own first admin. Do not post passwords in chat.

## Grouped acceptance

Use fictional test employees, keep one known working administrator signed in, and do not deactivate real employees for acceptance.

1. As admin, find a test employee, edit name/roles and Save once; refresh and confirm persistence. Cancel a different draft and confirm nothing changed. Verify own Administrator/Active checkboxes cannot be cleared.
2. Deactivate a test helper and confirm its already-signed-in session cannot read assigned operational data. Its history/plans must remain. Reactivate from Inactive/All; sign back in and check restored access follows current assignments.
3. PM-only/lead/helper accounts cannot open Employees, see its footer link, or invoke privileged mutations. Removing a Lead role with current owned work must explain reassignment first. Existing Lead accounts remain eligible for helping duty independently of account roles.
4. Record observed outcomes; do one final build/checkpoint/push. Phone usability, simultaneous profile changes, actual fault injection and restore drills remain separate gates.

## Safe pause

It is safe to pause before applying 0016: existing app/data remain at applied 0015, and the employee page clearly reports missing schema to an admin. Stop dev and commit/push the prepared code/docs using ordinary Git commands to back it up. Resume from this document. Apply the new update only once; if it succeeds, record the exact result before any pause. Never treat 173 local tests as proof that SQL was applied.
