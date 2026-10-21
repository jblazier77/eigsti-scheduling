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

No proposal above authorizes new charges. No substantial product decisions have been reopened.
