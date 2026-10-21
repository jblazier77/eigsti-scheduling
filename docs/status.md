# Current status

Updated 2026-10-21. Development paused after successful first app sign-in. Phase 0 exit pending; initial Phase 1 app checkpoint prepared. This is a local development checkout, not a production application.

## Checkpoint

- Workspace: `C:\Users\jrbla\OneDrive\Projects\ChatGPT\Eigsti Scheduling`
- Branch: `phase-0-foundation`
- Latest saved checkpoint: `e9b75e7`, committed by Josh Blazier and pushed to origin/phase-0-foundation. New framework/UI/configuration work and this status update are not yet committed. Agent Git writes remain restricted.
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

## Framework and screen checkpoint

Dependencies installed by user in normal PowerShell with exact versions and lockfile. Next.js 16.4.2 / React 19.3.1 / Supabase SSR 0.12.7 / client 2.118.0 / TypeScript 7.0.2.

Added actual sign-in/sign-out, cookie session refresh, live membership checks, PM My/All Jobs, assigned-job views, three-field creation and authorized job details/phone links. No Google login or role selector. Controlled job form retains inputs and request ID on uncertain save. User configured the test publishable key in ignored .env.local and created an individual Auth account with an active Josh Blazier admin/PM profile. No passwords or keys are recorded here. See local-app.md.

Latest full production build passed in user PowerShell (compilation, TypeScript, page generation and route output). User started the development server on port 4310, signed in successfully and supplied a screenshot showing the empty My Jobs screen in the test workspace. Job creation was requested as the next check but has not been confirmed. Agent loopback/browser limits remain; this browser evidence is user supplied.

## Phase 1 progress

- TypeScript domain validation and active-role checks; individual password/refresh Auth transport and live membership verification; jobs Request/Response handler; PM My/All listing and atomic-create RPC adapter. See api-contract.md.
- Migration 0001 applied to the Free test project. Its job/access subset passed the 35-check database suite according to user SQL Editor results. No production schema exists.
- pgTAP suite passed 35 checks, 0 failed (user reported); multi-connection tests and actual Auth/REST/Storage checks remain required.
- Earlier agent registry DNS failed; user normal PowerShell reached npm registry and installed the packages successfully. User subsequently completed the full production build successfully.
- No contacts/files/editing UI or full account lifecycle yet. Initial sign-in and empty My Jobs screen are confirmed by user screenshot. Job creation/persistence, session refresh, logout, additional role boundaries and phone usability checks remain pending.

## Checks and limitations

- `npm run seed`: passed; deterministic generated JSON.
- `npm test`: 21 checks passed (fixture, domain/request/Auth transport and environment guard checks). Mocked transport tests remain separate from the user-reported 35 cloud database checks.
- `npm run check:prototype`: passed JavaScript syntax and DOM-stub smoke checks for all role screens, helper control restrictions, planning, return work, new job/default work, unassigned planning guard and unknown-time sub entry. This is not browser rendering or backend authorization evidence.
- Local preview server started on loopback port 4310. HTTP readiness request failed with sandbox `EACCES`; browser could not reach loopback, and open-in-app tool returned an error. Therefore rendered layout, clicks and phone usability remain unverified. No network restrictions were bypassed.
- Node 24.21.0, npm 11.19.0, Git 2.53.0 available. No Docker/psql detected; local PostgreSQL remains unavailable, but user-run cloud SQL Editor migration and 35-check database suite succeeded. Node native TypeScript loading passed; TypeScript compiler check now passes. See framework checkpoint for the Windows final-build-output limit.
- No approved mockup files were supplied. Prototype is proposed interaction design only; calendar toggle, exact/multi-day controls, staffing editor, live files/auth and administration are not implemented.
- `git diff --check`: passed for the empty tracked diff; new files were separately checked by fixture/prototype tools. Staging/commit attempted with explicit Codex automation identity, but `.git/index.lock` creation was denied. No company employee identity was assumed.

## Outstanding inputs (do not reopen product scope)

1. Company domain eigsticonstruction.com confirmed; DNS access/app subdomain and production hosting/backup/email ownership pending. GitHub account/repository now exist and initial code is uploaded.
2. Standalone invitation/password app sign-in confirmed as baseline; company currently uses Google email without integration. Working defaults approved: Monday-Friday, 07:00-15:30, split at noon, America/Chicago. Specific holiday/overtime exceptions remain to define.
3. Pilot participants (two leads, PM, helper), phone workflow review, and preferred attachment limits/types including iPhone HEIC. Existing approved mockups, if any, can be supplied for fidelity review.

These inputs do not block the completed local foundation. They do block claims of Phase 0 completion and account-dependent integration. No paid services should be bought until the company setup and estimate are reviewed.

## Exact next action

Pause checkpoint: save and upload the current UI/dependency/documentation changes through user PowerShell. The .env.local file must remain ignored. Last confirmed uploaded commit remains e9b75e7 until a new push is confirmed. Stop the development server with Ctrl+C before closing PowerShell. Supabase data persists independently of the local server.

On resume, start with `npm.cmd run dev` from the project folder and open http://127.0.0.1:4310. First check whether a fictional test job already exists, since creation has not been confirmed; avoid creating a duplicate. If absent, create Test Customer One / 309-555-0101 / 123 Example Lane, Morton, IL 61550. Verify save, refresh persistence, session/logout and role boundaries. Multi-connection, contacts/private files/account administration remain Phase 1 work. No production data or paid provisioning.

Initial GitHub checkpoint is uploaded. Save subsequent changes through user PowerShell while agent Git writes remain restricted. Calendar/domain/standalone sign-in baseline are recorded. Pilot phone review, DNS access, ownership and attachment policy remain pending Phase 0 inputs. GitHub is the implementation checkpoint destination; the older recovery ZIP predates these database corrections/results.
