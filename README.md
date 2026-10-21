# Eigsti Scheduling

Phone-first work planning for Eigsti carpenters. Leads own their schedules, PMs coordinate jobs and staffing, and helpers see their assignments. Employee access will use individual company app accounts, without ChatGPT.

## Current state

Phase 0 foundation plus the first Phase 1 backend checkpoint. TypeScript job/access/Auth adapters exist. The initial schema is applied to an isolated Free Supabase test database, and 35 database checks passed according to user SQL Editor results. Code checkpoint dc95ab1 is hosted in the private GitHub repository; later database corrections/results await commit. No authenticated browser app or production deployment exists. The separate phone prototype still uses synthetic data and browser memory; its role selector is a review aid, not authentication.

Baseline: Architecture and Development Handoff v1.0, October 20, 2026. Agreed requirements remain authoritative; new technical proposals are explicitly labeled. See [current status](docs/status.md) before continuing work.

## Local setup

Requires Node.js 24 or newer and Git. No dependencies or paid accounts are required for Phase 0.

```powershell
npm run seed
npm test
npm run check:prototype
npm run preview
```

Open http://127.0.0.1:4310. The server binds to loopback only. Stop with Ctrl+C. Do not enter actual customer information. `npm run seed` deterministically regenerates `demo/synthetic.json`; it never connects to a database. The future Next.js application is not scaffolded yet: package-registry DNS is blocked. Backend TypeScript runs in Node 24 native type-stripping mode for isolated tests; a full compiler/type check and framework build remain pending.

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
- [Initial backend contract and verification limits](docs/api-contract.md)
- [Exact next action and checkpoint](docs/status.md)

Development/test data must remain isolated from production. Never commit secrets, actual customer data, attachments, or database backups. Technical implementation records belong here; substantial product changes belong in the scoping conversation and must then be carried into these records.
