# Pilot release record

Status: NOT RELEASED. Prepared 2026-10-24. Blank fields are not approvals.

| Gate | Evidence / result | Owner / date |
| --- | --- | --- |
| Reviewed commit pushed; clean checkout | 078ef7d pushed; later operator fixes uncommitted | |
| CI clean-install tests and production build | GitHub run 40139519707 succeeded for 078ef7d | |
| Final production build for release commit | GitHub production build passed for 078ef7d; later operator fixes pending checkpoint | |
| Pilot project identity / environment / hosting URL | Pending | |
| Clean-project migration application 0001-0016 | Pending; existing isolated project is already applied | |
| Read-only readiness SQL, ten PASS results | User reported all ten PASS on existing isolated project | |
| Actual database/Auth/private-file export | User-reported live backup succeeded; 3 files, 1 storage object; integrity verified. Restore still pending. | 2026-10-24 |
| Actual native atomic archive publication | User ordinary-PowerShell run published verified encrypted archive successfully | 2026-10-24 |
| Separate offsite copy downloaded and verified | Owner downloaded from OneDrive web; verification passed and SHA-256 matches original. Same OneDrive account; independent account recovery not demonstrated. | User-reported |
| Isolated database/Auth/file restore and sign-in | Pending; record run/hash/counts/duration | |
| Daily offsite runner and failure monitoring | Pending; no schedule enabled | |
| Manual accounts/reset and recovery administrator | Partial existing test evidence; pilot accounts pending | |
| PM/lead/helper scope and already-active deactivation | Existing role tests; hosted live-session check pending | |
| Leads helping others, date-only vs timed conflicts | Automated/earlier partial checks; grouped pilot check pending | |
| Actual concurrent editors and interrupted saves | Pending | |
| Phone/tablet navigation, photo/PDF, saved-state review | Pending | |
| Workload/load measurement and release rollback check | Pending | |
| Owner accepts named users/jobs and limited pilot | Pending | |
| Switch to pilot label and redeploy | Blocked by preceding gates | |

Keep this record free of passwords, tokens, database connection strings and customer details. Store the backup path/hash and recovery operator log privately; record only its reference here. Set user/job limits and review date with the owner. Keep the previous planning process available during the trial. Any failed gate remains visible with a resolution, not replaced by an assumption.
