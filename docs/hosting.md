# Hosting, cost, and ownership gate

Research date: 2026-10-20. Proposed configuration, not a purchase or deployment. Prices USD before taxes. Vendor pages must be rechecked at actual provisioning; free quotas and billing-unit rounding apply per vendor account.

| Component | Initial configuration | Monthly estimate |
| --- | --- | ---: |
| App hosting | Vercel Pro, one developer seat, low traffic within credit; company staff are app users, not developer seats | $20 |
| Database/auth/private files | Supabase Pro, one Micro production instance covered by compute credit | $25 |
| Development/test | Local Node + isolated local Supabase containers; no paid cloud staging/branch | $0 |
| Invites/password recovery | Resend Free custom SMTP, small pilot within free limits, verified company sending domain | $0 |
| Separate backups | Private R2 Standard; 50 GB-month assumed total retained DB exports + unique file versions, low operation counts | $0.60 expected; reserve $2 |
| Source control | Company-controlled GitHub Free private repository, CI within quota | $0 |
| Domain | Existing company subdomain has no incremental registration; if new, planning allowance $24/year (not a quote) | $0–2 allowance |
| Total | Includes $2 backup reserve and optional domain allowance | **$47–49 before tax** |

This is an initial usage estimate, not a hard cap or an accepted quote. Hosting overage, extra developer seats, paid staging, larger compute, taxes, additional email volume and heavier backups can exceed $50. Supabase's spend cap does not make every charge impossible; recheck plan controls. Second paid Micro project adds about $10/month, pushing core infrastructure to $55 before extras. PITR is excluded; daily snapshots have different recovery guarantees.

Capacity included in Supabase Pro: 8 GB DB disk, 100 GB file storage, 100,000 monthly active users, 250 GB egress and seven-day daily DB backup retention. These are far above the synthetic record counts, but photo growth/transfer and query efficiency must be measured. Initial app limits proposed: 10 MiB per file and company upload usage warning at 5 GB; revisit before exhaustion. Backup reserve assumes 50 GB average retained bytes, NOT 30 full 50 GB copies. Use immutable unique object copies plus daily manifests and coordinated DB snapshots; size/dedup/retention verification remains Phase 4 work.

Vercel Hobby is personal/non-commercial, so do not budget it for this business app. Supabase's built-in email service is intended for non-production and limited to team recipients/rate limits; production invite/password recovery needs company SMTP. No schedule email is being added. Standalone individual invitation/password app accounts are the baseline. Company uses Google email, but no Google sign-in, email, calendar, contact or file integration is planned.

## Company prerequisites (updated 2026-10-20)

| Need | Required fact | Blocks |
| --- | --- | --- |
| Repository ownership | No GitHub account exists. Establish company-controlled account, private repository and recovery administrator | Remote checkpoint/backup; local work continues |
| Identity | Google currently used for company email. Standalone app invitation/password chosen; no Google integration | Implement app auth and verify invite/recovery email delivery |
| Domain | eigsticonstruction.com confirmed; DNS administrator/access and intended app subdomain pending | Custom app URL and SMTP sending-domain verification |
| Infrastructure | Company Vercel/Supabase/backup/email accounts or permission to create under company control | Provisioning and billing |
| Operations ownership | Named business owner and technical recovery administrator | Pilot operational readiness |
| Test environment | Docker-capable development machine or isolated synthetic test account | Database/RLS integration tests; no Docker/psql detected here |

No credentials are needed in chat. Set secrets directly in approved environment configuration when accounts exist. No paid service has been provisioned. If test infrastructure needs payment, present the revised estimate before any charge.

## Primary sources

- https://vercel.com/pricing — Pro price, developer seats, tax/usage caveats and non-commercial Hobby.
- https://supabase.com/pricing — Pro, quotas, included Micro compute credit, extra projects and backups.
- https://supabase.com/docs/guides/platform/manage-your-usage/compute — per-project compute billing.
- https://supabase.com/docs/guides/platform/backups — database backups exclude Storage object bytes.
- https://supabase.com/docs/guides/auth/auth-smtp — production SMTP requirement.
- https://supabase.com/docs/guides/auth/social-login/auth-azure — Microsoft OAuth setup.
- https://supabase.com/docs/guides/auth/social-login/auth-google — Google OAuth setup.
- https://resend.com/pricing — free email quota; reconfirm transactional tier during setup.
- https://developers.cloudflare.com/r2/pricing/ — Standard $0.015/GB-month after 10 GB-month free; request quotas/rounding.
- https://github.com/pricing — free private repositories and CI allowance.
