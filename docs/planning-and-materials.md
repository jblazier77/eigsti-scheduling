# Planning and material-readiness batch (0012)

This implements the testing feedback and the next planned readiness slice together:

- PM day/week calendar shows an amber warning triangle and the number of requested helpers still missing. It clears when named helping participants fill the requirement. It is based on actual staffing, not a separate Plan/Tentative/Confirmed choice.
- Plan selection and certainty badges are removed from current planning UI. Existing stored certainty values are preserved for compatibility; staffing and optional time reservations use the existing rules regardless of that legacy value.
- Add work offers a date immediately, optionally through another day, optional time blocks and a helper count. Leaving the date blank still creates ordinary undated work. A dated addition is one transaction with one request identity: an invalid date/conflict rolls back work creation and a retry cannot duplicate the item or its calendar entry. A lead is required only when dates are supplied.
- Each work item has one material-availability summary: material name, Not set / No material hold / Need to order / Ordered / In stock, and an optional expected date while waiting. PMs and the responsible lead may edit; other authorized readers can see the summary. This is a work-level summary, not a multi-material purchase-order system. Estimates stay estimates even after their date passes. In stock/No material hold clear the material wait; expected arrivals feed the existing lead-queue waiting state without automatically asserting receipt.
- All changes stay inline. No work completion checks or separate return-work concept is added.

## Validation and application

133 automated Node checks and TypeScript pass locally. The new live SQL checks, production build and authenticated/phone acceptance have NOT run yet. Prior 0010/0011 remain applied and unchanged. The latest confirmed pushed checkpoint is a5f2bc5; this batch and resume notes are local/uncommitted.

1. Stop normal PowerShell dev using Ctrl+C (Y if prompted). Run npm.cmd run build from the project directory.
2. After a successful build, copy database/batches/0012_work_planning_and_materials.sql into a NEW Supabase SQL editor query in the isolated vglhojtrccygjgupxsrd project and run once. This bundle applies only 0012, runs 42 checks in a savepoint, rolls all synthetic fixtures back, then commits the schema only if checks pass. It stops if 0012 may already be applied; do not replay previous bundles. Any failure should abort the batch; retain the exact error for correction.
3. Expected final result: 42 checks, 0 failed, 0012 applied; synthetic fixtures removed. Record the actual result before marking the migration applied.
4. Restart normal-user dev. In one grouped check: add undated work; add dated work with No time set and help needed; see the PM calendar warning, fill help and see it clear; edit dates/crew with no Plan choice; set materials Ordered plus an expected date, verify the queue/work labels, then explicitly In stock and verify the waiting date clears. Check lead own-work editing/helper read-only separately. Do not infer completion from elapsed dates.
5. Record the full build/SQL/browser evidence and make one user PowerShell commit/push when the batch is accepted. Future initial-plan work remains subcontractor commitments/handoffs, lifecycle/archival design consistent with planning-only requirements, and pilot/admin/device/recovery gates. SMTP/email recovery stays deferred.

Before 0012 is applied, existing work-status reads fall back to old fields so the job page remains usable. Material editing explains that the planning update is pending; dated creation cannot report success or create partial work if the new RPC is absent. Existing undated work creation continues to use the existing command.

Regenerate the exact guarded bundle after any migration/test change with node scripts/prepare-planning-batch.mjs. New commands use employee authentication, empty SQL search_path, live role/ownership checks, scoped row locks, stable receipts and append-only audit. No service key, paid provisioning, Google integration, notification or deployment is added.

0012 first live attempt stopped with 42501 (visits table SELECT denied) inside test assertions. The schema bundle did not reach commit. Corrected the tests to read through public.list_job_visits via an invoker-only temporary typed reader, including staffing target lookup. No direct visits-table grant or elevated helper was added; application/schema behavior is unchanged. Regenerated the same guarded 42-check bundle and added a regression check for authorized test reads. Live rerun is pending. Recopy the revised SQL in normal PowerShell; no application rebuild is needed for this SQL-test-only correction.

0012 live evidence: user screenshot image(20261023-005817).png shows the final guarded result, 42 checks and '0012 applied; synthetic fixtures removed'. The guarded success row is reached only after the failure-validation block, fixture rollback and commit. Mark 0012 APPLIED in the isolated test project; do not rerun. New authenticated/phone acceptance and the final batch checkpoint remain pending. Prior Node suite: 134 passed; TypeScript passed. The user has not separately supplied the full new build output, so keep its explicit evidence distinct.
