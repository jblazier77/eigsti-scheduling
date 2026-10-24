# Eigsti Scheduling

Phone-first work planning for Eigsti carpenters. Leads own their schedules, PMs coordinate jobs and staffing, and helpers see their assignments. Employee access will use individual company app accounts, without ChatGPT.

## Current state

The local app supports jobs, lead queues, optional-date scheduling/staffing, contacts/files, subcontractor commitments, materials, archive/restore and employee administration. Migrations 0001-0016 are applied in the isolated fictional-data project. Compact phone UI and pilot hosting/recovery preparation are local; the pilot is not released. Start with [the grouped pilot handoff](docs/pilot-handoff.md) and [current evidence](docs/status.md).

Baseline: Architecture and Development Handoff v1.0, October 20, 2026. Agreed requirements remain authoritative; new technical proposals are explicitly labeled. See [current status](docs/status.md) before continuing work.

## Local setup

Requires Node.js 24.x and Git. For a clean checkout, run `npm.cmd ci` to install the exact package-lock.json dependencies. Phase 0 prototype checks remain dependency-free. No paid account is needed for the current Free test project.

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
- [Grouped pilot handoff](docs/pilot-handoff.md)
- [Encrypted recovery procedure](docs/pilot-recovery.md)
- [Pilot release record](docs/pilot-release-record.md)
- [Synthetic verification scenarios](docs/scenarios.md)
- [Phone workflow review](docs/phone-review.md)
- [Local application setup](docs/local-app.md)
- [Initial backend contract and verification limits](docs/api-contract.md)
- [Exact next action and checkpoint](docs/status.md)

Development/test data must remain isolated from production. Never commit secrets, actual customer data, attachments, or database backups. Technical implementation records belong here; substantial product changes belong in the scoping conversation and must then be carried into these records.
