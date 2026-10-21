# Post-pilot development list (user's Phase 2 list)

Decision 2026-10-21: defer custom authentication email setup, email invitations and self-service forgotten-password recovery until after the initial pilot. Someone else manages eigsticonstruction.com DNS; no SMTP provider is configured. Supabase custom SMTP remains off. This is a release-scope deferral, not a change to the architecture's numbered implementation phases: scheduling still belongs in the initial pilot.

## Deferred email work

- Select/configure the sender and verified sending subdomain with the DNS manager; prepare exact provider-issued DNS records when that service is set up. Do not invent DNS values or change existing company mail records.
- Configure Supabase SMTP and delivery controls; verify actual delivery, quotas and sender identity.
- Build/test invitation and self-service forgotten-password flows, approved callback URL/redirect allowlist, expired/replayed token denial and account membership checks. Do not advertise a working recovery email button before delivery is verified.

## Initial pilot provision

Authorized manual employee account provisioning and administrator-assisted password resets replace email onboarding/recovery for the limited pilot. An administrator establishes Auth accounts and matching active app profiles using the controlled technical setup; employees receive temporary credentials privately and change them through My account. The app currently does not force a first-login password change. An operator must verify identity before a manual reset. Never send passwords through repository records or this development chat.

This exception does not defer phone access control, operational scheduling, account deactivation testing, private-file acceptance, backups/restore or the other initial pilot gates. Phone account administration remains on the initial development list; automated email invitations are deferred. No production deployment, paid provisioning or real employee enrollment has been performed by this decision.
