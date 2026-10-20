# Operations design

Not yet operational. Company domain eigsticonstruction.com is confirmed; Google is used for company email without planned app integration. Standalone app invitation/password sign-in is the baseline. No GitHub account exists. Company owner, recovery administrator, repository remote, hosting and DNS access remain pending; see hosting.md. No actual customer data is permitted before the release gates.

## Environments and ownership

Local: this Phase 0 prototype, synthetic only. Test: proposed local Supabase with same versioned migrations; container runtime not yet available. Production: not provisioned. Preview builds must receive test credentials only, never fallback production values. Fail startup for missing/mismatched environment identity. Company controls domain, repository, vendors, billing and recovery MFA; developers receive named least-privilege access. No shared passwords or secrets in chat/git.

## Releases and rollback

Before deployment: pin dependencies, migration checksum/order, authorization/command checks, mobile smoke checks, environment verification and a known backup. Prepare release candidate for owner review at Phase 4. Record commit, migration level and deployment ID. Favor additive compatible migrations. A code rollback does not reverse schema/data changes; plan forward fixes or isolated restore/reconciliation before destructive schema changes. No deployment procedure has been run.

## Backup and restore proposal

Supabase daily database backups retain seven days on Pro and exclude file bytes. Separately schedule a consistent database export plus versioned attachment-byte copies to a company private R2 backup bucket. Never put backups into source control or this prototype. Proposed daily recovery point target <=24 hours, 30-day retained manifests, monthly isolated restore exercise; no promised recovery time until measured. Implementation must account for auth identities, storage metadata, RLS/functions, sequences/extensions and roles; reset custom role passwords as needed, never expose them.

Use immutable file keys and delayed physical deletion so DB snapshot/manifests can reference stable bytes. Back up database and file manifest under a common run ID; mark successful only when every referenced object exists and checksum agrees. Incremental copies plus retention-aware reference counting avoid 30 full file copies. Retain every byte referenced by a retained DB snapshot; do not delete on primary bucket deletion. Backups use separate credentials and private ACLs. Monitor last complete snapshot and failed copies; owner-facing operational error handling is separate from excluded schedule notifications.

Restore exercise: create isolated environment, restore DB and auth mappings, copy referenced file bytes, verify counts/relationships/checksums, sign in as synthetic PM/lead/helper, reconcile one complete job and a return visit, test direct API denials and signed URLs, document duration/missing objects. Never run restore drill against production. Nothing in Phase 0 claims this has passed.

## Exports and user administration

Export jobs, work, visits, participants, commitments, contacts, follow-ups and audit references using stable IDs and date/time conventions. Include attachment metadata + checksums and a private byte archive/manifest. Never export credentials or auth tokens. Export/restore tooling is not implemented. Admin invite/deactivate/trade settings are planned phone operations; infrastructure recovery remains technical work. Deactivation removes access promptly but preserves attribution and assignment history.

## Logging and failure handling

Log command/request ID, actor ID, event type and safe error codes; avoid customer names/addresses, access notes, raw files and signed URLs. Server-confirmed state only: saving, saved, failed/unsent. Persist drafts only in memory initially; preserve form on failure and retries with same request ID, but clear sensitive content on logout. Enforce duplicate protection and atomic audit creation in DB, not UI alone.
