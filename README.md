# Eigsti Scheduling

Phone-first work planning for Eigsti carpenters. Leads own their schedules, PMs coordinate jobs and staffing, and helpers see their assignments. Employee access will use individual company app accounts, without ChatGPT.

## Current state

Phase 0 foundation plus the first Phase 1 backend checkpoint. TypeScript job/access/Auth adapters exist. The initial schema is applied to an isolated Free Supabase test database, and 35 database checks passed according to user SQL Editor results. Code checkpoint dc95ab1 is hosted in the private GitHub repository; later database corrections/results await commit. No authenticated browser app or production deployment exists. The separate Phase 0 phone prototype still uses synthetic data/browser memory and has a review-only role selector. The real Next.js app now has password sign-in, job lists, job creation and job details; its test-project connection and actual sign-in checks are pending.

Baseline: Architecture and Development Handoff v1.0, October 20, 2026. Agreed requirements remain authoritative; new technical proposals are explicitly labeled. See [current status](docs/status.md) before continuing work.

## Local setup

Requires Node.js 24 or newer and Git. For a clean checkout, run `npm.cmd ci` to install the exact package-lock.json dependencies. Phase 0 prototype checks remain dependency-free. No paid account is needed for the current Free test project.

```powershell
npm run seed
npm test
npm run check:prototype
npm run preview
```

Open http://127.0.0.1:4310. The server binds to loopback only. Stop with Ctrl+C. Do not enter actual customer information. `npm run seed` deterministically regenerates `demo/synthetic.json`; it never connects to a database. Run `npm.cmd run dev` for the real application at the same loopback address. Run only one server at a time. See [local app setup](docs/local-app.md) for the test connection and verification limits.

## Records

- [Requirements and acceptance criteria](docs/requirements.md)
- [Architecture and domain relationships](docs/architecture.md)
- [Permission matrix](docs/permissions.md)
- [Decisions and proposals](docs/decisions.md)
- [Development phases](docs/development-plan.md)
- [Hosting, costs, and ownership prerequisites](docs/hosting.md)
- [Operations and recovery design](docs/operations.md)
- [Synthetic verification scenarios](docs/scenarios.md)
- [Phone workflow review](docs/phone-review.md)
- [Local application setup](docs/local-app.md)
- [Initial backend contract and verification limits](docs/api-contract.md)
- [Exact next action and checkpoint](docs/status.md)

Development/test data must remain isolated from production. Never commit secrets, actual customer data, attachments, or database backups. Technical implementation records belong here; substantial product changes belong in the scoping conversation and must then be carried into these records.
