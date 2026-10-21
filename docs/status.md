# Current status

Updated 2026-10-20. Phase 0 exit pending; **first Phase 1 backend checkpoint prepared**. This is a local development checkout, not a production application.

## Checkpoint

- Workspace: `C:\Users\jrbla\OneDrive\Projects\ChatGPT\Eigsti Scheduling`
- Branch: `phase-0-foundation`
- Latest saved checkpoint: `dc95ab1`, committed by Josh Blazier and pushed to origin/phase-0-foundation. Current SQL correction and this status update are not yet committed. Agent Git writes remain restricted; user PowerShell writes succeeded.
- Company GitHub: https://github.com/jblazier77/eigsti-scheduling.git; origin configured and first checkpoint upload confirmed.
- Supabase test project: `vglhojtrccygjgupxsrd`, created by user in Eigsti Construction organization using Free plan. No production hosting/deployment. Corrected migration applied successfully via user SQL Editor; 35 database checks reported, 0 failed.
- Baseline read in full: Eigsti Architecture and Development Handoff v1.0, 248 lines; Library file libfile_43703675297881918e01ebfd5fa6463f.
- No existing project or applicable ancestor AGENTS.md was found at initialization.

## Prepared

README, architecture, stable requirements, proposed permission matrix, approved/proposed decision log, sequential plan, sourced cost estimate and company prerequisites, operational/recovery design, all 15 handoff verification scenarios, migration contract, reproducible fixtures, and local phone interaction prototype.

Synthetic seed has 20 active leads, 30 active house projects, ten window jobs, two PMs, one helper, one admin and a deactivated employee. It represents distinct job portions, Leading/Helping roles, vacant assistance, a no-time Friday subcontractor visit, waiting work and tentative future cabinets. It does not claim database capacity performance.

## Current database setup

User first received PostgreSQL 42601 at the update_job CASE expression. The expression was corrected locally, the complete migration rerun, and user reported "Success. No rows returned". User then ran the 35-check pgTAP suite and reported "35 checks, 0 failed". Evidence is user-reported SQL Editor output, not direct agent database access.

The suite checks direct database role access, rejected writes/promotion, deactivation, atomic job/default work/audit creation, sequential retry deduplication, payload collision and narrow patches. The SQL Editor wrapper captures every assertion and raises an exception on incomplete/failing results; all temporary fixtures are rolled back.

Migration file SHA-256 at this checkpoint: `3739d78d66e60f78a4bd1eca89a902bcf693e20c8ffde18ab374f12e871c888c`. PostgreSQL version, full TAP transcript, clean-reset repeat and multi-connection concurrency proof are still pending.

## Phase 1 progress

- TypeScript domain validation and active-role checks; individual password/refresh Auth transport and live membership verification; jobs Request/Response handler; PM My/All listing and atomic-create RPC adapter. See api-contract.md.
- Migration 0001 applied to the Free test project. Its job/access subset passed the 35-check database suite according to user SQL Editor results. No production schema exists.
- pgTAP suite passed 35 checks, 0 failed (user reported); multi-connection tests and actual Auth/REST/Storage checks remain required.
- Next.js/SDK installation could not proceed: registry.npmjs.org DNS returned ENOTFOUND for Next.js and PGlite package lookups. No dependency lockfile or framework build is claimed.
- No contacts/files/UI connection or complete account lifecycle yet. No actual password session, employee invitation or storage object was created.

## Checks and limitations

- `npm run seed`: passed; deterministic generated JSON.
- `npm test`: 18 checks passed (3 fixture and 15 domain/request/Auth transport checks). Vendor responses are mocked; these do not prove RLS, SQL syntax, actual Auth behavior, transaction atomicity or concurrency.
- `npm run check:prototype`: passed JavaScript syntax and DOM-stub smoke checks for all role screens, helper control restrictions, planning, return work, new job/default work, unassigned planning guard and unknown-time sub entry. This is not browser rendering or backend authorization evidence.
- Local preview server started on loopback port 4310. HTTP readiness request failed with sandbox `EACCES`; browser could not reach loopback, and open-in-app tool returned an error. Therefore rendered layout, clicks and phone usability remain unverified. No network restrictions were bypassed.
- Node 24.21.0, npm 11.19.0, Git 2.53.0 available. No Docker/psql detected; local PostgreSQL remains unavailable, but user-run cloud SQL Editor migration and 35-check database suite succeeded. Node native TypeScript loading passed; full TypeScript compiler checks await tooling.
- No approved mockup files were supplied. Prototype is proposed interaction design only; calendar toggle, exact/multi-day controls, staffing editor, live files/auth and administration are not implemented.
- `git diff --check`: passed for the empty tracked diff; new files were separately checked by fixture/prototype tools. Staging/commit attempted with explicit Codex automation identity, but `.git/index.lock` creation was denied. No company employee identity was assumed.

## Outstanding inputs (do not reopen product scope)

1. Company domain eigsticonstruction.com confirmed; DNS access/app subdomain and production hosting/backup/email ownership pending. GitHub account/repository now exist and initial code is uploaded.
2. Standalone invitation/password app sign-in confirmed as baseline; company currently uses Google email without integration. Working defaults approved: Monday-Friday, 07:00-15:30, split at noon, America/Chicago. Specific holiday/overtime exceptions remain to define.
3. Pilot participants (two leads, PM, helper), phone workflow review, and preferred attachment limits/types including iPhone HEIC. Existing approved mockups, if any, can be supplied for fidelity review.

These inputs do not block the completed local foundation. They do block claims of Phase 0 completion and account-dependent integration. No paid services should be bought until the company setup and estimate are reviewed.

## Exact next action

Commit/push this verified database checkpoint through user PowerShell. Then resolve package-registry connectivity, pin Next.js dependencies, connect backend modules to actual sign-in/jobs screens, and test real Auth/REST sessions. Preserve Free test isolation. Add multi-connection retry/narrow-edit tests and finish contacts/private files/account administration for Phase 1. No production data or paid provisioning.

Initial GitHub checkpoint is uploaded. Save subsequent changes through user PowerShell while agent Git writes remain restricted. Calendar/domain/standalone sign-in baseline are recorded. Pilot phone review, DNS access, ownership and attachment policy remain pending Phase 0 inputs. GitHub is the implementation checkpoint destination; the older recovery ZIP predates these database corrections/results.
