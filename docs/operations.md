# Operations

Prepared for limited-pilot setup; not operationally released. Individual password accounts and migrations 0001-0016 are in the isolated fictional-data project. The private GitHub repository exists; last confirmed pushed checkpoint is 0b5b259. Hosting, offsite backups, an actual restore and grouped device/access review remain pending. See pilot-handoff.md and pilot-release-record.md.

## Environments and accounts

Development/previews use fictional data. Use a separate approved pilot project, explicit project reference and Production configuration. Preview cannot fall back to production; operator credentials stay outside the app. The Test/Limited pilot label is not release approval. Leave pilot mode off until owner acceptance.

Admins manage existing employee names/roles/active state. Auth provisioning and forgotten-password resets remain manual operator work; employees can change their own passwords. SMTP/email invitations and Google integration are deferred. Deactivation retains assignments/history while live app membership denies subsequent requests; hosted existing-session behavior still needs verification.

## Releases

Use pinned dependencies and Node 24. Validate the reviewed commit with tests and a production build. Prepared secret-free GitHub CI has not run. Record commit, migration level, project reference, deployment ID, readiness results and owner approval. Keep provider backups and independently verified recovery before real use. Code rollback does not reverse schema/data changes; prefer compatible forward fixes or an operator-reviewed isolated recovery/reconciliation.

## Recovery

pilot-recovery.md documents backup:check, backup:create, backup:verify and backup:prepare-restore. A held database snapshot ties the dump to file inventory; encrypted packages include actual job-file bytes. Missing/mismatched ready files fail the package. Authenticated encryption and content hashes are checked before publication. Auth records make the package sensitive operator material.

Actual live export, native publication on the operator computer, offsite round-trip verification, compatible database/Auth/file restore and recovery timing are pending. Provider settings/root keys, global roles/passwords and unrelated buckets require separate planning. Extraction is not restoration; the tools do not change a live target. Do not broaden client grants as a workaround.

Target: daily complete offsite copies, <=24-hour recovery point, 30-day retention, monthly isolated recovery exercise and failure monitoring on an always-on company runner. None is configured yet. Current tooling makes full copies; budget retained bytes accordingly. Retention cleanup is not automated. Store passphrases separately from backups.

## Failure handling

Operational logs contain safe codes, request/run IDs and hashes/counts as needed, without customer details, access notes, signed URLs or credentials. An uncertain save is not success; retain the draft and stable retry identity. Keep infrastructure administration away from carpenter screens. Prepared hosted-access checks cover anonymous page/API/file access and security/cache headers, not authenticated/device/concurrent behavior.
