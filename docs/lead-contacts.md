# Assigned leads adding job contacts

User scope correction 2026-10-21: a lead should be able to add job contacts. Only contact creation is expanded here. PM-only editing/removal remains unchanged, including contacts a lead added. Helpers remain read-only.

## Boundary

An active PM may add contacts to any existing job. An active lead may add only where the existing private.can_read_job boundary authorizes that lead, through owned work or current helping access. Work ownership on a closed job retains the existing read behavior; this change does not add a separate lifecycle rule. Helping access still follows the existing open-job/revocation rule. The form cannot choose another actor or grant job access. SQL rechecks access after the parent job lock, coordinating with work reassignment, and before returning old request results.

Migration 0005 replaces only create_job_contact and updates the table comment. Applied migrations 0001-0004 are untouched. It retains SQL validation, 100-active-contact limit, job-row serialization, actor/request replay protection, audit attribution and archived-contact replay behavior. No raw writes, update/archive permissions, directory expansion or administrative key is added. The new-contact route verifies employee role and job RLS; the action verifies membership and domain role, and SQL enforces actual target-job scope. Existing browser forms retain unsent values and the same request UUID on uncertain creates.

## Evidence and pending work

All 53 Node tests and TypeScript pass, including lead create action/domain behavior, helper denial, revoked-access failure handling and existing PM archive redirect regressions. They use mocked transport. New SQL suite 0005_lead_contact_creation.test.sql prepares 32 rolled-back checks for assigned/unrelated/helper/admin/anonymous/deactivated/revoked access, actor attribution, raw/field forgery, retries/collisions, own-contact edit/removal denial, PM behavior and limits. User reported successful 0005 application and all 32 checks, 0 failed. Two older 0002 create-denial assertions now check the permission error code without its old PM-only wording so they work before and after this role expansion; their original 60-check result remains historical evidence, not a claim of a rerun.

Prepared migration SHA-256: 2a084f504f6d5f05d9f20fe8879d858dbe0ece87800fa77c7aa78691eecb0b86.

User confirmed full normal-user production build and dev restart. As Test Lead, Add contact appeared; name-only Test Site Contact saved and returned to the job, refresh retained it, and edit/removal controls were absent. As helper, direct new-contact route was blocked and returned to /jobs. Next commit/push. Direct lead edit denial, PM compatibility retest, unrelated/reassigned lead denial, multi-connection/session/fault/phone acceptance remain separate pending browser checks; SQL covers the permission boundaries. Do not rerun applied 0005. No messages/calls were sent.

## Related inline work evidence

User confirmed inline work editor loading after restart guidance, Cancel resetting the draft to Whole job without navigation, Save changing it to Kitchen cabinets without navigation, and refresh retaining Kitchen cabinets/Test Lead. Test Lead signed in, saw Test Customer One, and its work section was read-only as intended. Full production build after inline work and lead-contact changes passed in user PowerShell. The initial new client-export runtime error is not a proven root-cause diagnosis; loading recovered after restart guidance.

Additional browser evidence: after PM removed Test Lead from the final owned portion, Test Lead direct new-contact page showed Job unavailable. Same session had no jobs and direct job details were unavailable. This verifies actual contact-create form denial after job access removal, separate from SQL assertions. User then acknowledged restoring the cabinet assignment for ongoing development.

