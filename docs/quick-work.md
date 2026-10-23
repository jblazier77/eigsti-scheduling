# Quick work setup - 0013

User example: install one window next Tuesday, help needed, windows in stock and ready. Add work now exposes work/lead, optional date, Helpers needed and Material availability together, with one Save work/Cancel. Help and material fields are visible before dates are chosen. A blank material name uses the work description (up to the material-name limit), avoiding duplicate typing. Expected arrival appears only for material waiting states. Longer date ranges and optional time blocks are under More date / time options; the normal case saves as one date with no time block.

Undated work may also retain a helper requirement without reserving anyone. It is shown on the work card and prefilled when Add date is used. Calendar staffing warnings still compare the scheduled helper requirement with actual named participants. This does not silently assign specific people, require dates/times, mark work complete or add a separate return-work category.

New create_quick_work RPC wraps existing ordinary work/date creation, the default helper requirement and optional material status in one transaction. One immutable receipt covers the entire payload. A material validation failure or staffing conflict rolls back the work and schedule; a retry cannot duplicate work, repeat its material history, or overwrite later independent material edits. Existing role boundaries remain PM-only work creation, PM/own-lead material updates and authorized job reads.

## Current evidence

139 automated checks and TypeScript pass. Applied 0012 remains unchanged and previously passed 42 live checks. New 0013 is NOT applied. Full production build and live 33-check SQL execution/browser acceptance for this addition remain pending. Latest confirmed pushed checkpoint is a5f2bc5; new work remains local.

## One update and grouped review

1. Stop normal-user dev with Ctrl+C (Y if prompted), then run npm.cmd run build.
2. After build success, copy database/batches/0013_quick_work.sql in PowerShell into a new Supabase SQL editor query for isolated project vglhojtrccygjgupxsrd. Run once. Do not rerun 0012 or older updates.
3. Expected result: 33 checks, 0 failed, 0013 applied; synthetic fixtures removed. Bundle guards duplicate application and rolls fixture data back before committing the DDL.
4. Restart dev. Add the window work, lead, Tuesday, one helper needed, In stock; save once. Confirm date/need/readiness on the work and PM calendar. Add undated work with two helpers needed, save, then open Add date and confirm two is prefilled. Check a failed/cancelled draft does not create partial work. This is a grouped review, not a separate check for every field.
5. Record actual evidence and make one checkpoint after acceptance. Initial-plan commitments/handoffs and pilot/device/recovery/lifecycle gates remain distinct; no completion-reporting or return-work UI should be restored.

Regenerate only this new bundle with node scripts/prepare-quick-work-batch.mjs if its source/tests change. It uses the same scoped schedule RPC for fixture reads; no direct visits-table grant is needed.

0013 live evidence: user reported the guarded final result '0013 applied; synthetic fixtures removed'. This success row is emitted only after all 33 check results pass validation, fixtures roll back and the DDL commits. Mark 0013 APPLIED; do not rerun. 139 Node checks and TypeScript passed locally. Restart normal-user dev for grouped quick-work acceptance; full new build output has not separately been supplied, and GitHub checkpoint remains a5f2bc5 until a new push is confirmed.

Quick-work browser evidence: after applying 0013 and reopening the test job, user reported 'worked great' in response to the one-save window-installation/date/help/in-stock scenario. Record that quick-work workflow as user-verified. Do not extend this evidence to unreported undated, staffing-warning-clearance, lead/helper, phone, concurrency or recovery checks. 0012/0013 applied, 139 Node checks and TypeScript passed; save the current batch in one user Git checkpoint before subsequent initial-plan work.
