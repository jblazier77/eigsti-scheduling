# Hosting and cost

Updated 2026-10-24. Prepared configuration, not a purchase or deployment. See pilot-handoff.md for grouped setup.

| Component | Proposed pilot choice | Budget consideration |
| --- | --- | --- |
| App hosting | Vercel Pro, one developer seat | $20/month base; usage and tax can add charges |
| Database/Auth/private files | Dedicated Supabase Pro pilot project | $25/month starting plan; includes compute credit for one Micro project |
| Isolated test / restore | Separate from real pilot data | Additional projects in a paid organization start around $10/month each |
| Independent backups | Separate private company store, e.g. R2 | Not configured; depends on full archive size, retention, operations and transfer |
| Code and CI | Existing private GitHub repository | Account/Actions quotas apply; no database credentials in CI |
| Email and DNS | Deferred pilot workflows | Manual account setup/reset, individual passwords and Vercel HTTPS address |

Core services start around $45/month before backups, additional projects, usage and taxes. The old $47-49 estimate assumed incremental/deduplicated backups and no paid staging. Current tooling creates full archives; that estimate is not a cap. Review the actual account quote before upgrading. No plan upgrade, purchase or deployment was performed here.

Vercel Hobby is personal/non-commercial; use the proposed business plan. Staff using the app do not need developer accounts. Review deployment protection for the pilot audience. Custom domain and SMTP can follow later. No Google integration.

## Prepared deployment

vercel.json selects Next.js, npm ci and npm run build. Package/lock metadata selects Node 24.x. Production variables are in hosting-environment.example.txt; operator credentials belong only in the separate recovery environment. Previews require separate test credentials and reject production configuration. Start with fictional data and the Test workspace label. After release gates pass, set Production EIGSTI_DATA_MODE=pilot and redeploy; the label itself is not approval.

Use the reviewed phase-0-foundation branch/checkpoint until another production branch is explicitly chosen. New local changes require a Git checkpoint first. Prepared GitHub CI installs exact dependencies, runs tests and builds with no live credentials. Its first GitHub run is pending; it does not deploy or back up data.

Josh already has the private GitHub repository and isolated Supabase test project; earlier no-account notes are obsolete. Company-controlled hosting, backup storage, billing and recovery ownership remain pending. Keep the real pilot separate from fictional development data. Provider database backups exclude private file bytes; the actual combined recovery drill remains pending.

Primary references, checked 2026-10-24:

- https://vercel.com/pricing
- https://vercel.com/docs/plans/pro-plan
- https://vercel.com/docs/plans/hobby
- https://vercel.com/docs/environment-variables
- https://supabase.com/pricing
- https://supabase.com/docs/guides/platform/billing-faq
- https://supabase.com/docs/guides/platform/backups
- https://developers.cloudflare.com/r2/pricing/
