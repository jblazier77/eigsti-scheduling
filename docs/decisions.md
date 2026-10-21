# Decisions and proposals

All entries dated 2026-10-20.

| ID | State | Decision / reason |
| --- | --- | --- |
| D01 | Approved baseline | Handoff v1.0 defines product; one scope chat and one development chat; repo records carry continuity |
| D02 | Approved baseline | Leads own schedules; PM My Jobs default with All Jobs access; helpers read-only |
| D03 | Approved baseline | Latest committed priority order wins; narrow transactional saves preserve unrelated data; no schedule notifications |
| D04 | Approved baseline | Required job fields only customer, phone, address; default work item hidden for simple jobs |
| D05 | Approved baseline | Work completion and job closure differ; tentative waiting plans do not confirm delivery |
| D06 | Implementation choice | Initialize local Git branch phase-0-foundation; no invented company remote or deployment |
| D07 | Proposed | Next.js/TypeScript + Supabase Pro + Vercel Pro; verify company accounts before provisioning |
| D08 | Confirmed development baseline | Standalone individual invitation/password app accounts, with custom SMTP for invites/recovery. Company uses Google email; Google sign-in/email/calendar/contact/file integration is outside this baseline |
| D09 | Proposed | Local Supabase stack for DB integration tests; this machine currently has no detected Docker/psql. Arrange local container runtime or isolated test project; never production |
| D10 | Approved 2026-10-20 | Monday-Friday, 07:00-15:30, morning/afternoon split at noon, America/Chicago. User accepted defaults; holiday/overtime exceptions remain to define |
| D11 | Proposed | 10 MiB JPEG/PNG/WebP/PDF private uploads; review HEIC on real iPhones before finalizing |
| D12 | Proposed | Admin receives operational permissions via additional roles; lead coordinator edits only own work/shared visit; pilot validates exact matrix |
| D13 | Proposed | Daily consistent DB export and immutable file-copy backup to company-controlled private R2; 30-day recovery retention, daily target, test before live use |
| D14 | Known gap | Prior approved mockups were not supplied with this handoff; local prototype is a new interaction proposal, not a claim of matching unseen approvals |
| D15 | Environment blocker | Local Git initialization succeeded; staging and commit denied at .git/index.lock. Foundation remains uncommitted; do not invent a commit or bypass repository protections |

| D16 | Confirmed 2026-10-20 | Company domain eigsticonstruction.com; DNS access and intended app subdomain not yet verified |
| D17 | Confirmed 2026-10-20 | No existing GitHub account; company-controlled account and private repository setup pending |

| D18 | Implementation checkpoint | Prepare dependency-free TypeScript core and unapplied SQL while package-registry DNS and PostgreSQL tooling are unavailable; mocked requests do not prove RLS or Auth integration |
| D19 | Proposed validation convention | Initial phones accept formatted US ten-digit numbers with optional +1; readable input retained; extensions/international formats not implemented |

| D20 | Confirmed setup | GitHub origin jblazier77/eigsti-scheduling and checkpoint dc95ab1 uploaded. Free Supabase test project vglhojtrccygjgupxsrd created; initial migration failed with PostgreSQL 42601; corrected CASE expression then applied successfully; subsequent user-run database suite reported 35 checks, 0 failed |

| D21 | Implementation checkpoint | User normal PowerShell installed exact framework dependencies. Initial actual app screens and server cookie sessions implemented; 21 Node checks/type check pass; final build output verification and real connection/session tests pending |

| D22 | Implementation checkpoint 2026-10-21 | Initial PM create/persistence/logout and unassigned helper denial browser checks passed (user evidence), recorded in uploaded commit 5588284. Added PM details/scope/access-notes editing using existing update_job RPC, six allowed fields and client original-value diff. Title remains explicit. Uncertain edit saves retain values and allow inspecting saved job before manual resave; updates are not deduplicated. 25 Node checks and TypeScript pass; editing browser acceptance and full normal-user build remain pending. No migration or paid service added |

| D23 | Verified checkpoint 2026-10-21 | PM editing browser checks passed: save/refresh, clear optional notes, cancel, invalid-phone validation, helper edit-route denial and preservation of a newer phone edit by a stale scope-only form. Full production build then passed in normal user PowerShell including the edit route. These supersede D22 pending checks; simultaneous multi-connection/fault tests remain separate. Editing checkpoint ready to commit/push |

| D24 | Implementation checkpoint 2026-10-21 | PM editing uploaded as 018a1d2. Additional job contacts now prepared locally: customer-side or trade contact details tied to a single job; existing customer contact retained. PM-only create/edit/archive, assigned operational readers, optional phone/email/relationship/notes, narrow patches, audited soft removal and retry-safe creation. 100 active contacts/job bounds list size and is checked under job-row lock. Global trade directory and subcontractor commitments remain separate scope. 31 Node checks/TypeScript pass; migration 0002, 60 SQL assertions, full build and browser checks await user-run setup. No new charges or Google integration |

| D25 | Verified checkpoint 2026-10-21 | Contacts/removal fix uploaded as 64609f0. Migration 0002 and its 60 SQL assertions passed per user; 34 Node tests/TypeScript passed. User browser confirmed removal returned to job without error, persisted after refresh, and helper contact create/edit routes were blocked. Final production build after the navigation fix passed in normal user PowerShell. Actual phone action dispatch, live assigned-helper reads and simultaneous connection tests remain separate. Final verification documentation ready to commit |

| D26 | Confirmed/implementation 2026-10-21 | User confirmed direct iPhone uploads. Prepared job attachments with original HEIC/HEIF plus PDF/JPEG/PNG/WebP, 10 MiB/file from the proposed baseline, 100 non-archived records/job, PM/assigned lead uploads, helper authorized downloads, lead own-only/PM-any soft archive. Direct scoped upload avoids Vercel body limit; SQL verifies stored size/MIME before publication. Download URLs last 60 seconds; upload capabilities last two hours and are not immediately revocable. No overwrite, content-scanning/conversion service or physical deletion/cleanup. 40 Node/TypeScript checks pass; migration 0003/66 SQL checks/full build/Storage/phone acceptance pending. No new charges |

No proposal above authorizes new charges. No substantial product decisions have been reopened.

| D27 | Verified checkpoint 2026-10-21 | Supersedes D26 pending setup: user confirmed migration 0003, 66 SQL checks with no failures, full production build, desktop upload and matching-original download, refresh persistence, soft removal and refresh, and unassigned helper upload-route denial. SQL assertion 37 required a test-only top-level CTE correction; applied migration unchanged. Real phone/HEIC, near-limit, retry/fault, assigned-helper and issued-URL expiry acceptance remain pending. Implementation awaits user commit/push; no production deployment |

| D28 | Implementation checkpoint 2026-10-21 | Private files uploaded as 193c50d. Added signed-in own-password change for active employees, current-password reauthentication in an isolated non-persistent session, own-identity/live-membership checks, project-cookie logout and sign-in notice. 46 Node tests and TypeScript pass; full build and helper browser acceptance pending. No migration, administrative secret or new service. Forgotten-password recovery, verified SMTP and admin account setup remain following work; see accounts.md |

| D29 | Verified checkpoint 2026-10-21 | Supersedes D28 pending build/core browser checks: user full build passed with /account. Helper mismatched confirmation and wrong current password rejected; correct change redirected with success notice; old password rejected, new password signed in; signed-out /account denied. Passwords kept private. Cancel, phone, real deactivation and fault acceptance remain pending. Ready for user commit/push; recovery email and account administration follow |

| D30 | Scope decision 2026-10-21 | Password-change checkpoint e95f6ea pushed. Someone else manages domain DNS; custom SMTP is off. User deferred email invitations and self-service forgotten-password recovery/custom sender setup to the post-pilot Phase 2 list. Limited initial pilot may use controlled manual account provisioning/admin-assisted reset and signed-in password changes. Scheduling remains initial scope; architecture implementation phase numbers are unchanged. See post-pilot.md |

| D31 | Implementation checkpoint 2026-10-21 | Prepared PM-owned work portions and active lead assignment, preserving the default Whole job entry, narrow edits, scoped name directory, existing job access derivation and audited retry-safe create. No dates/helper staffing yet. New migration 0004 and 58 SQL assertions await user execution; full build and browser acceptance pending. Queues follow. See work-ownership.md |
