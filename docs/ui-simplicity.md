# Phone-first simplicity pass

D62: user asked for an independent make-it-as-simple-as-possible pass before pilot testing: understandable labels, simple buttons/icons, less blank space and fewer expand arrows on phones. This is a UI-only batch; no SQL, permission expansion or backend command changes.

## Implemented

- Compact header, cards, filters, forms and gaps on phones. Phone navigation stays at the bottom in one horizontally scrollable row, with safe-area/content padding so it does not cover the end of a form. Inputs retain 16px text and controls retain 44px touch rows; checkboxes use a smaller visible box inside a full-size label.
- PM scope choices stay visible and green when selected, using shorter tiles. Leads/helpers see only selected scope labels instead of a grid of disabled unused choices. Selected scopes on job/queue/calendar cards are readable chips without an expand arrow. Whole house stays one visual badge; underlying names remain accessible and PM choices remain available on the job.
- Calendar navigation uses previous/next arrows, Today and a compact four-view selector. Empty dates take less vertical space. No date-only/staffing or visibility rules change.
- Crew edit pencils sit beside crew names on both job and calendar cards, using the same lazy scoped editor. The coordinating person is marked lead; other crew names do not repeat helping after every name. Hidden editors remain mounted to retain drafts; roles and server permissions are unchanged.
- Materials show a summary and pencil, not an expand row. Existing baseline/version/retry and Save/Cancel behavior is retained; successful saves close the editor. Read-only users have no write form. Hidden forms use an explicit hidden rule so a grid display rule cannot reveal them.
- Subcontractors use compact contact rows with visible trade labels and call/text/email/edit icons. Add/edit opens in place without details arrows; confirmed saves and Cancel close the editor. Existing archive confirmation remains. Global-directory access and snapshot-copy semantics do not change.
- Contact notes are directly readable without expanding. Job and queue titles open the job, removing duplicate Open job links. Queue priority uses accessible up/down icons. No empty Work history accordion is shown when there is no history.
- Employees have less introductory copy and compact rows; role controls use two columns where useful. Existing administrator-only/self-lockout guards remain.

## Evidence and limits

177 Node checks and TypeScript pass. Covers always-visible scopes, read-only action restrictions, subcontractor contact actions, material summary/pencil/hidden form, queue links/accessible movement and existing saves/auth boundaries. No new SQL is required; applied 0001–0016 are unchanged.

Attempted local headless Chrome fixture screenshot review, but the process exited before capturing an image (exit -2147483645). No real browser screenshot, measured layout-height improvement, authenticated mobile interaction, iOS behavior or actual phone acceptance is claimed. Temporary review files were removed. New full normal-user production build and desktop/phone/tablet review remain pending. Keep icons accompanied by accessible names; do not replace Save/Cancel with unexplained symbols.

## Current checkpoint / next action

Latest confirmed uploaded checkpoint is 0b5b259 (employee management), clean at this batch's start. User reported the employee screen, name persistence and deactivate/reactivate steps worked; live denial in an already-open employee session is a separate pending pilot check. Current UI changes are local/uncommitted.

Refresh normal-user dev to review Jobs, a job, Schedule, Subcontractors and Employees. No SQL reruns. Before final backup, stop dev and run one production build, then restart as needed. Consolidated hands-on review should include narrow phone/tablet widths, no sideways document scroll, footer reachability, dates/crew and material edits, retained drafts when collapsed, Save/Cancel, subcontractor call/edit and role-appropriate controls. Browser/phone findings may require adjustments. Then one Git checkpoint/push and resume the already-approved pilot-readiness testing, restore and hosting queue.
