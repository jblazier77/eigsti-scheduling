# Permission matrix

Agreed role responsibilities come from the handoff. Detailed resource boundaries below are proposed for pilot validation. The initial Phase 1 code implements a subset (job reads, PM create/patch commands, live membership); the initial job/access SQL subset passed the user-run 35-check PostgreSQL suite, and the matrix is not yet fully implemented. Default deny, require active individual identity, and enforce every scope in server commands AND direct database/storage API policies.

| Action | Admin | PM | Lead | Helper |
| --- | --- | --- | --- | --- |
| Manage account roles, invites, deactivation, settings, trade directory | Yes | No | No | No |
| Create jobs / assign responsible PM | With PM role | Yes | No | No |
| View job details / authorized files | With PM/lead role | All jobs | Assigned job and shared work on that job | Jobs with own named assignment |
| Edit job/customer information | With PM role | All jobs | No; scope/remaining notes on own work only | No |
| Add additional job contacts | With PM/lead role | All jobs | Assigned jobs (0005 pending verification) | No |
| Edit/remove additional job contacts | With PM role | All jobs | Read only, including own additions | Read only on assigned jobs |
| Assign/reassign lead ownership | With PM role | All jobs | No | No |
| Plan/complete work and coordinated visits | With PM/lead role | All jobs | Work they lead or visits they coordinate | No |
| Fill vacant assistance | With PM/lead role | Yes | Own/coordinated visit, vacant need, available person only | No |
| Replace existing named staffing | With PM role | Explicit edit + conflict check | No silent replacement; refer to PM | No |
| Reorder lead queue | With PM/lead role | Any lead | Own queue | No |
| Add/update sub commitments | With PM/lead role | All jobs | Assigned job | No |
| Add files / follow-ups | With PM/lead role | All jobs | Assigned job | No |
| Remove job files (soft archive) | With PM/lead role | Any accessible file | Own uploads on assigned job | No |
| View personal week/schedule | With operational role | All with filters | Own + relevant shared job context | Own assignments only |
| View staffing availability | With PM/lead role | All, details authorized | Minimal busy/free and person identity | No company-wide availability |
| Close/archive whole job | With PM role | Yes, portions handled or explicit resolution | No | No |
| View audit trail | User administration events | Accessible job history | Relevant job history | No audit endpoint |

Admin does not automatically mean PM in this proposal; one person can receive both roles. This avoids a hidden operational-permission assumption. Helper's relevant job view contains shared job context needed to do assigned work but not the whole company schedule. Exact visibility after past assignments is a pilot decision: proposed active-job access until job closure, then only assignment summary; confidential office-only notes are not a first-release feature.

## Required negative checks before Phase 1 exit

Work ownership slice (0004, not yet applied): only active PMs list assignment candidates and create/update work ownership. Only active leads may receive new ownership. Job-scoped readers may see shared work and assigned lead names, never the full assignment directory. Existing job RLS derives access from work ownership; removing the final owned portion revokes that source of access. Queues, dates and helper staffing are not granted by these commands. SQL/browser checks remain pending; see work-ownership.md. Email invitations/self-service recovery are deferred per post-pilot.md; other initial access controls remain required.

File implementation prepared in migration 0003: ready reads follow job access; pending reads/upload capability require the current uploader with job write access. Helpers have no upload/finish/archive commands. Lead archive is own-only; PM archive is any job. Direct object overwrite/delete is denied. New downloads recheck membership and return a 60-second forced-download capability; an issued capability is not immediately revocable. Signed upload capabilities last two hours; final publication always rechecks access. See job-files.md for limits and required real Storage tests. Migration/SQL execution and browser acceptance remain pending.

Anonymous, deactivated and uninvited accounts retrieve no operational data. Helper cannot POST/PATCH/DELETE via direct API or sign another job's file URL. Lead cannot change another lead's queue, take existing helper, enumerate unrelated customer details through availability, promote self, or forge an audit actor. PM can edit another PM's job. Role changes take effect without waiting for a stale session token to expire. Test both server endpoints and direct data/storage paths, including forged job/work/visit relationships and combined-role users.
