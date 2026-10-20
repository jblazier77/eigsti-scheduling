# Current status

Updated 2026-10-20. Phase 0 exit pending; **first Phase 1 backend checkpoint prepared**. This is a local development checkout, not a production application.

## Checkpoint

- Workspace: `C:\Users\jrbla\OneDrive\Projects\ChatGPT\Eigsti Scheduling`
- Branch: `phase-0-foundation`
- Current commit: **none**. `git init -b phase-0-foundation` succeeded, but staging/commit failed because workspace permissions deny creation of `.git/index.lock`. No checkpoint commit or remote push is claimed. Resume from these files and this status until commit access is available.
- Company GitHub: no existing account; company-controlled account/repository setup pending; no remote configured.
- Hosting/database/sign-in/storage: not provisioned. No deployment, paid charge, or production customer record.
- Baseline read in full: Eigsti Architecture and Development Handoff v1.0, 248 lines; Library file libfile_43703675297881918e01ebfd5fa6463f.
- No existing project or applicable ancestor AGENTS.md was found at initialization.

## Prepared

README, architecture, stable requirements, proposed permission matrix, approved/proposed decision log, sequential plan, sourced cost estimate and company prerequisites, operational/recovery design, all 15 handoff verification scenarios, migration contract, reproducible fixtures, and local phone interaction prototype.

Synthetic seed has 20 active leads, 30 active house projects, ten window jobs, two PMs, one helper, one admin and a deactivated employee. It represents distinct job portions, Leading/Helping roles, vacant assistance, a no-time Friday subcontractor visit, waiting work and tentative future cabinets. It does not claim database capacity performance.

## Phase 1 progress

- TypeScript domain validation and active-role checks; individual password/refresh Auth transport and live membership verification; jobs Request/Response handler; PM My/All listing and atomic-create RPC adapter. See api-contract.md.
- Migration 0001 authored for users/jobs/work/access/audit/retries, read RLS and PM create/update commands. SQL has NOT been applied or PostgreSQL-verified.
- Draft pgTAP suite covers direct role access, denied writes/promotion, deactivation, create/default work/audit, retry collisions and narrow patches; multi-connection tests remain required.
- Next.js/SDK installation could not proceed: registry.npmjs.org DNS returned ENOTFOUND for Next.js and PGlite package lookups. No dependency lockfile or framework build is claimed.
- No contacts/files/UI connection or complete account lifecycle yet. No actual password session, employee invitation or storage object was created.

## Checks and limitations

- `npm run seed`: passed; deterministic generated JSON.
- `npm test`: 18 checks passed (3 fixture and 15 domain/request/Auth transport checks). Vendor responses are mocked; these do not prove RLS, SQL syntax, actual Auth behavior, transaction atomicity or concurrency.
- `npm run check:prototype`: passed JavaScript syntax and DOM-stub smoke checks for all role screens, helper control restrictions, planning, return work, new job/default work, unassigned planning guard and unknown-time sub entry. This is not browser rendering or backend authorization evidence.
- Local preview server started on loopback port 4310. HTTP readiness request failed with sandbox `EACCES`; browser could not reach loopback, and open-in-app tool returned an error. Therefore rendered layout, clicks and phone usability remain unverified. No network restrictions were bypassed.
- Node 24.21.0, npm 11.19.0, Git 2.53.0 available. No Docker/psql detected; migration and RLS integration suite have not run. Node native TypeScript loading passed; full TypeScript compiler checks await tooling.
- No approved mockup files were supplied. Prototype is proposed interaction design only; calendar toggle, exact/multi-day controls, staffing editor, live files/auth and administration are not implemented.
- `git diff --check`: passed for the empty tracked diff; new files were separately checked by fixture/prototype tools. Staging/commit attempted with explicit Codex automation identity, but `.git/index.lock` creation was denied. No company employee identity was assumed.

## Outstanding inputs (do not reopen product scope)

1. Company domain eigsticonstruction.com confirmed; DNS access/app subdomain and hosting/backup/email ownership pending. No GitHub account exists; company-controlled setup remains required.
2. Standalone invitation/password app sign-in confirmed as baseline; company currently uses Google email without integration. Working defaults approved: Monday-Friday, 07:00-15:30, split at noon, America/Chicago. Specific holiday/overtime exceptions remain to define.
3. Pilot participants (two leads, PM, helper), phone workflow review, and preferred attachment limits/types including iPhone HEIC. Existing approved mockups, if any, can be supplied for fidelity review.

These inputs do not block the completed local foundation. They do block claims of Phase 0 completion and account-dependent integration. No paid services should be bought until the company setup and estimate are reviewed.

## Exact next action

Resolve package-registry connectivity and obtain an isolated synthetic Supabase/PostgreSQL test runtime. Apply migration 0001, run database/tests/0001_jobs_and_access.test.sql and multi-connection retry/narrow-edit cases; repeat from a clean reset. Then pin Next.js dependencies, connect existing backend modules to sign-in/jobs screens, and finish contacts/private files/account administration for Phase 1. No production data or paid provisioning.

Company GitHub/private repository setup and workspace Git write access remain needed for a committed checkpoint. Calendar/domain/standalone sign-in baseline are recorded. Pilot phone review, DNS access, ownership and attachment policy remain pending Phase 0 inputs. The saved recovery package includes this uncommitted checkpoint.
