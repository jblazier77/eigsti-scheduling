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

| D32 | User workflow correction 2026-10-21 | PM work/lead editing belongs directly on job details to reduce clicks. Added always-visible description/lead fields for each open work portion with row Save/Cancel, page-preserving refresh and draft retention across other row saves. Existing role/SQL boundaries unchanged; no migration. 51 Node tests and TypeScript pass; inline browser/full-build checks pending. Original 0004 migration, 58 SQL assertions and original work build passed per user. Work checkpoint 5b6ed89 pushed; Test Lead account created and initial assignment saved |

| D33 | User scope correction 2026-10-21 | Inline work Cancel/Save/refresh passed; lead sign-in/job visibility and read-only work display passed. User requested leads add job contacts. Prepared authorized-lead create only in new 0005, preserving PM-only edit/archive, helper read-only, live job checks, retries/audits/limits. 53 Node tests and TypeScript pass; 32 SQL checks, full build and browser acceptance pending. No applied migration edited. See lead-contacts.md |

| D34 | Verified checkpoint 2026-10-21 | User confirmed 0005 applied, 32 SQL checks with no failures and full build after inline work/contact changes. Test Lead name-only Test Site Contact added, returned to job and persisted after refresh with no edit/removal controls. Helper direct new-contact route blocked to jobs. Inline PM work Cancel/Save/refresh and lead read-only work previously passed. Ready for user commit/push; remaining ownership/portion/revocation and phone/fault tests remain pending |

| D35 | User workflow correction 2026-10-21 | Checkpoint 85cad7a pushed. User requested one Save/Cancel pair for Work and leads card; authorized implementation. Added shared draft, narrow changed-row payload, Cancel reset and atomic/retry-safe batch command in new 0006, preserving PM checks and current rows on retry. 58 Node tests/TypeScript pass; 40 SQL checks/full build/browser acceptance pending. No prior migration edited. See work-card-save.md |

| D36 | Verified shared-card checkpoint 2026-10-21 | 0006 applied, all 40 SQL checks passed, one Cancel resets both portions, one Save persists both portions, and refresh preserves descriptions/leads per user. Fixed redundant router.refresh and clean-disabled wait cursor; confirmed Saved/idle/editable behavior and final full production build passed. 58 Node tests/TypeScript pass. Ready for user commit/push; broader fault/phone/reassignment checks remain pending |

| D37 | Verified ownership checkpoint 2026-10-21 | Implementation a79c78e pushed. User confirmed one remaining owned portion preserves lead job access; removing final ownership hides jobs and blocks direct job/contact-create routes. Initial empty list was consistent with user clearing both lead selections; no code defect established. User acknowledged restoring cabinets/Test Lead, countertops/unassigned. Documentation-only checkpoint; next ordered lead queues with existing latest-save/permission requirements |

| D38 | Queue implementation checkpoint 2026-10-22 | Resume verified clean workspace with c38984c uploaded. Prepared per-lead ordered work queues, PM-any/lead-own scope, Up/Down and shared Save/Cancel, exact live membership, latest-commit order, stable retry receipts and automatic membership triggers. Private immutable event snapshots retain actor/revision/full order. Uses a single company-wide mutation lock before queue rows for initial small-company correctness; reads remain lock-free and order saves never lock job/work. 63 Node tests/TypeScript pass; new 0007/58 SQL checks/build/browser and real concurrent verification pending. No email, staffing reservation or paid service. See lead-queues.md |

## D39 - Optional visit times and shared-day plans (2026-10-22)

Josh explicitly clarified that a lead can place one or several jobs on a day without entering a time slot. Default to date-only No time set; never silently reserve a whole day for it. Show shared-day workload warnings. Morning, afternoon, all-day and timed reservations remain optional and reject exact named-person overlaps atomically. Tentative explicit reservations also reserve staff. This supersedes any interpretation that every date-only plan expands into exclusive full-day hours. 0008 prepares visits/staffing and day/week views; SQL/build/browser verification is pending, with 70 Node tests and TypeScript passing. Schedule writes use a separate company-wide mutex before parent locks, then sorted calendar locks, an explicit small-company serialization tradeoff. Real concurrent proof remains pending.

## D40 - Inline editing and minimum clicks (2026-10-22)

Josh requests minimal clicks and edit-in-place throughout the program to support adoption. Prefer editing on the current job/schedule card. Avoid separate edit screens unless a workflow requires one. Applied now to visit dates, help needed, named staffing and cancellation: editors expand within job and calendar cards; old visit links redirect to the job card. Local Cancel resets its form without page reload. Existing narrow date and staffing commands remain separate; no new SQL migration. Review other existing workflows against this principle during subsequent development/phone review. Inline UI full build/browser retest pending.

## D41 - One Save/Cancel per visit card (2026-10-22)

User requests one Save instead of separate Save visit/Save staffing controls. Implement one shared inline draft and Save/Cancel pair for dates, helper need and named staffing. Selecting a helper can add the required space in the same draft; saved-time busy status must not prevent selecting staff for changed draft dates. Final availability/permissions/capacity checks remain authoritative and atomic. New 0009 is required; applied 0008 is unchanged. 77 Node tests/TypeScript pass; 38 SQL checks/full build/browser acceptance pending. See visit-card-save.md.

## D42 - Larger completion/return development batch

User approved grouping finishing scheduled work, completing a portion and planning return work into one implementation/testing batch, one database update and a consolidated acceptance checklist. Prepare all work first; interrupt only for a blocking business decision. 0010 keeps visit finish/portion completion/job close distinct; return notes can be undated, preserve work identity and link optional appointments. Completion blocks unresolved planned entries/returns and does not touch another portion/job. One outer transaction plus fixture savepoint bundles migration and 60 checks; commit DDL only after all pass and fixtures are rolled back. 86 Node tests/TypeScript pass; database/build/browser acceptance pending. Whole-job closure remains a separate future guarded command.
## D43 - Rain-day discovery and flexible filler work (2026-10-22)

Josh paused completion/return testing and requested initial-build additions: tag jobs as potential bad-weather work with an easily recognized marker, and maintain undated filler work such as punch-list items and small repairs. Documented as R25/R26 in rain-day-and-filler-work.md; not implemented. Proposed independent classifications preserve readiness, assignments and existing access. User confirmed filler work is a standalone job tag, using normal job details and permissions. No weather integration or automatic scheduling is requested.

## D44 - Trade and project-scope icons (2026-10-22)

Josh requested subcontractor trade icons and compact project-scope icons on job cards, with a Whole house indicator for full-scope projects. R27 and trade-and-scope-icons.md capture this addition; not implemented. Keep actual project scopes independent of subcontractor assignment and retain readable expanded labels. Filler work is confirmed as a standalone job tag.

## D45 - Combined development and acceptance

User requested developing the rain-day, filler-job and trade/scope additions before testing the prepared completion/return work, then testing all of it together. Plan one consolidated setup and grouped acceptance checklist after implementation, with automated verification during development. Preserve ordered migrations and detect whether 0010 has been applied before preparing the combined database update. No intermediate user acceptance is needed unless a blocking issue or business decision arises.

## D46 - Combined implementation prepared

0010 and 0011 are now implemented locally, with one guarded database update and grouped acceptance in combined-batch.md. 98 Node checks and TypeScript pass; 111 SQL checks, normal-user production build and browser acceptance remain pending. Job tags/scopes are PM edits; directory management is PM/admin with lead read access and helper denial. Filler creation uses an atomic normal-job/default-work/tag wrapper. Whole house preserves selected scopes; no automatic subcontractor assignment, readiness or staffing change. Applied 0001-0009 unchanged. Latest confirmed uploaded checkpoint remains a91da8c.

## D47 - Approved carpenter-first layout and consistent initial pages

User approved the fictional job-details preview and requested the same theme across initial screens. Implemented one combined card per work portion, current user work first, visible arrival notes, all scope toggles visible (green selected/neutral inactive), inline PM edits and expandable supporting information/history. Shared compact theme covers Jobs/Queue/Schedule/Subcontractors/Account/Login. Existing atomic commands, role checks and applied SQL remain unchanged. 107 Node tests/TypeScript pass; new full build and authenticated/phone acceptance pending. See ui-layout-refresh.md.

## D48 - Scope at top and attachments as a bottom gallery

User asked for scope to be always visible near the top, with a small pencil edit control, top paperclip/photo add controls and bottom attachment thumbnails. Implemented inline native file selection/upload, protected lazy JPEG/PNG/WebP photo previews and labeled PDF/HEIC original-file tiles. Project work must be reviewed separately next and is not redesigned in this slice. Existing job scope edit and upload/remove roles remain authoritative; no applied SQL changed. 114 Node checks pass; production build and authenticated browser/device checks remain pending.

## D49 - Compact unified job contacts and three discovery filters

User requested one smaller alphabetical contact list, treating Subcontractor as a contact Type, and removal of the combined Rain-day filler filter from My Jobs. Customer and additional contacts now sort together by name, case-insensitively; compact rows expose call/text/email and PM pencil controls. Add/edit/remove stay on the job page. Existing relationship/trade labels remain intact, with Type choices Customer/Subcontractor/Site contact/Other using the existing relationship field. PMs and assigned leads can copy a directory subcontractor into a new job contact; this is an editable job-specific snapshot, not a live association or automatic scope/staff assignment. Only PMs edit/remove, helpers receive no directory payload. The primary customer still edits with the job-details pencil. My Jobs exposes only All work/Rain day/Filler; stale kind=both falls back to All work. No new SQL. 118 Node checks and TypeScript pass; authenticated UI acceptance and final production build remain pending.

## D50 - Simplified work overview

User approved the preceding scope/attachment/contact UI and requested simplification of the work sections. The default view now shows a compact portion heading with lead/status, then scheduled dates/crew. One section-heading pencil opens the existing atomic multi-portion Work & leads form with one Save/Cancel; Add work opens beside it on the same page. Both management panels close after confirmed success or explicit Cancel, retaining uncertain-result retries. Removed the duplicate full-width Edit work/leads and Add work support rows. Per-entry date/crew editing is a small pencil and Finish is a quiet action; Add date is an inline text control. Completion/reopen/return commands remain under one More control per portion, open returns remain visible and completed history remains separate. Role checks, date-only scheduling, optional times, helper selection, atomic saves and completion guards are unchanged. No SQL or deployment. 119 automated checks and TypeScript pass; authenticated visual/phone review and final normal-user production build remain pending.

## D51 - Scheduled entries are plans, not completion reports

User clarified that the tool plans future days and is not for checking up on completed work. Removed both Finish and Finish scheduled work controls from the shared scheduled-entry component, including job details and day/week schedule views. Entries retain dates, optional times, crew and edit/cancel controls. No daily finish action is required to create, move, staff or view plans. Supersedes the scheduled-entry Finish UI described in D50 and earlier completion acceptance.

This scoped UI removal does not rewrite applied SQL or historical completion data. Optional whole-portion completion and return close-out still have legacy database guards for planned entries; those are distinct from routine calendar planning. The remaining guarded whole-job/portion closure design must be reconciled with this planning-only decision before closure acceptance: do not introduce mandatory daily completion, auto-mark past plans as completed, or tell users to cancel real past plans as a workaround. No such workaround or automatic outcome inference is implemented. 119 automated checks and TypeScript pass; authenticated visual review/full build still pending.

## D52 - Remove work/return completion controls as well

User clarified that Complete this work is also unwanted after scheduled-entry Finish was removed. Removed whole-portion Complete/Reopen and Mark return handled controls from the active job workspace and legacy return-work component. No Finish, complete_work, resolve_return or reopen_work form is now rendered anywhere in app pages/components. Planning dates/crew and adding/planning return work remain available. Historical outcomes and applied SQL are retained, without automatic completion inference or data mutation. This supersedes D51's assumption that optional portion close-out controls should remain in the UI. Any future lifecycle/archival design must be distinct from carpenter completion reporting. 119 automated checks and TypeScript pass. No SQL update.

## D53 - One notion of job work

User requested Save visit be renamed Save work and clarified that work is a single notion, whether set up initially or added later. Removed the distinct Add/Plan return work flow, More submenu, return section and handled-return section. New items always use ordinary Add work; dates and crew remain optional planning details on work. Removed unused legacy return-work and progress-form UI components and the special return selector from the scheduling form. Scheduling and ordinary add-work submits use Save work; calendar removal says Remove from schedule and explicitly retains the work item.

Existing follow-up records have NOT been deleted, silently migrated or duplicated: their notes, owners and target dates render with their original work as ordinary notes; the duplicated remaining-note copy is suppressed. Existing linked dates/crews still render through the same planning component. Historical outcomes remain in Work history. Backend legacy commands/fields are retained for compatibility/audit, with no current return/completion UI producing them. No SQL needed for this UI/workflow unification; any eventual data-model cleanup requires a separate reviewed migration. 120 automated checks and TypeScript pass; authenticated desktop/phone review and final production build remain pending.

## D54 - Queue optional scheduling during Add work

User asked to save this for the next development push: Add work should offer an optional date immediately, avoiding the separate reopen/Add date step when a date is already known. Undated work remains fully supported; times remain optional. Keep the inline one-Save/Cancel interaction and existing scheduling/role rules. Queued only; implementation and acceptance are pending.

## D55 - Keep readiness badge; support material availability

User approved retaining the readiness badge for now and described intended material planning states: Need to order, Ordered, In stock, or a date, using cabinet arrival as the example. Capture optional expected availability/arrival dates alongside material status; do not infer actual receipt from an estimate or elapsed date. This is future readiness scope, separate from work completion/check-offs. UI details and aggregation across materials are not yet decided. No implementation or database update in this turn.

## D56 - Staffing warning and authorized testing-feedback/readiness batch

User authorized implementing the testing feedback and proceeding with the initial plan. Replace the named-help Plan choice with staffing facts: required count, named helpers, and an obvious simple warning on PM day/week cards until enough helpers are assigned. Implement D54 optional date in Add work with one atomic work/date save and stable retry identity. Begin the next readiness slice using D55 material availability as one summary per work item, edited by PM/own responsible lead, readable within job access. Expected dates do not automatically imply arrival or stock. No per-work completion/check-off or separate return-work flow. Implemented locally in new 0012 plus inline UI; 133 Node checks and TypeScript pass. 42 live SQL checks, a new production build and grouped browser/phone acceptance are pending. Do not rerun applied 0010/0011. See planning-and-materials.md. Further commitments/handoffs and pilot operations remain in the initial plan after this batch; not claimed completed.

## D57 - Quick work creation includes help and materials up front

User requested minimizing setup clicks using installation of one window next Tuesday, help needed, windows in stock/ready as the concrete example. Add work now includes required helping count and material availability before any date is entered; common one-day/no-time setup uses one Save work. Material name defaults to work description when blank; only expected dates or optional advanced scheduling need extra fields. Undated helper need is saved on work and prefilled when planning dates later. New 0013 wraps ordinary work/date creation, helper defaults and optional material status atomically with whole-request retry identity; failures cannot leave partial or duplicate work. No lead/helper role expansion, automatic named staffing, completion reporting or separate return-work category. 139 Node checks/TypeScript pass; new 33-check SQL bundle, full build and browser acceptance are pending. Applied 0012 is unchanged. See quick-work.md.
