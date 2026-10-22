# Approved job layout and shared theme

User approved the job-details visualization, then requested matching initial pages. Implemented locally; no database migration or permission change. The app should be run from the user's normal PowerShell, because agent-launched dev cannot reach Supabase under the execution network policy.

## Changes

- Compact shared header without the large slogan block; consistent green/neutral surfaces, headings, card spacing and 44px-or-larger controls across Jobs, Queues, Schedule, Subcontractors, account and sign-in. Footer wraps on phones; sign-in heading is direct and schedule guidance is expandable.
- Job header combines title/customer/address, rain-day/filler indicators and one-tap Directions/Call/Text. Access/preparation notes stay visible as Before you start.
- One work card per portion combines owner, readiness, planned crew entries, remaining notes and open returns. Repeated identical remaining/return notes are suppressed. PM sees all active portions; a lead/helper sees owned or currently assigned portions first. Other shared work remains accessible in compact expandable summaries.
- Readiness uses existing RLS-scoped work_items reads, never inferred from a tag. Planned participation counts for helper relevance; old cancelled/completed staffing does not elevate unrelated work into My work. Open returns or outstanding plans keep work visible even if completion fields are inconsistent.
- Inline PM batch work/lead editing retains one atomic Save/Cancel across all changed portions. Add work and job-detail edits now stay inline. Existing legacy routes remain valid. Scheduled-entry finish, portion completion/reopening and return resolution retain their distinct commands and guards.
- Always-visible scope buttons: all trades plus Whole house, selected green with a check/pressed state, unused neutral. No checkbox/expand selector. One Save/Cancel appears when the job-classification draft changes. PM edits; other readers get disabled scope buttons with the same selected state. New-job and directory trade selectors use the same button language. Whole house does not silently select all trades.
- Job notes, customer/additional contacts, files and completed/scheduled history are expandable. Contact count includes the primary customer. Active scheduled entries appear once within their work card; finished/cancelled entries appear once in history. Unfinished returns stay on the relevant active work card.

## Evidence and next action

107 automated Node tests and TypeScript pass, including new grouping/role/control and scope-visibility checks. Local HTTP /login returned 200 with the new sign-in heading and theme reference. Authenticated visual review, real phone interaction and a new normal-user production build remain pending. No new SQL is required: the earlier combined 0010/0011 update already passed 111 checks and is applied; do not rerun it.

Review the real job page, Jobs, Queue, Schedule, account and sign-in in the working Chrome/Edge browser. In the same grouped acceptance, check scope toggle/Cancel/Save persistence, PM inline work/detail edits, helper read-only/current assignment display, finish/return/complete guards and expandable contacts/files/history. After review, stop normal dev for a final user production build, then commit/push once with the outstanding feature batch. Latest confirmed uploaded checkpoint remains a91da8c; these local changes are not yet confirmed pushed.

The static /previews/job-details.html remains the original fictional design mockup, not the live implementation or acceptance evidence.

## Follow-up: scope and attachment placement

User requested these changes before revisiting Project work. Scope text is now always visible in the top overview with a small pencil button for PM inline editing (scope field first; existing customer/location/access editing retained). Scope/tag buttons are above Project work as well. The old expandable Job scope/details section is removed. Paperclip/photo buttons near the top open native file pickers directly and reuse the scoped, retry-safe upload process inline. Helpers do not get upload controls.

Photos & files is an always-visible gallery at the very bottom, after work/history. Ready JPEG/PNG/WebP files get lazy photo thumbnails using a private same-origin preview route; each preview rechecks active membership, job/file RLS, ready status, exact object path and supported MIME. Storage signing remains scoped to the exact object with 60-second expiry; signed URLs are fetched server-side rather than embedded in the gallery, and image responses are private/no-store/nosniff with a sandbox policy. Browser-decodable originals are streamed without a separate conversion pipeline; PDF and HEIC/HEIF files get labeled document/original-photo tiles and original download links. Pending uploads get incomplete tiles, never image previews. Removal rights and retained originals/history are unchanged.

114 automated Node tests pass, including preview transport/authorization denial, unsupported/forged metadata and scope/gallery display checks. TypeScript passed; final build and authenticated upload/thumbnail/device review remain pending. No SQL update is needed. Project work internals were deliberately left unchanged for the user's next simplification review. The earlier 0010/0011 SQL update is already applied and must not be rerun.

## Follow-up: compact contacts and subcontractor type

Contacts is an always-visible, compact alphabetical list, including the primary customer. Each row has a Type label and small touch-sized call/text/email icons; PMs have a pencil for inline edits. Notes expand only when needed. One inline add/edit form appears at a time, retaining narrow updates, unsaved-change protection, stable creation retry identity and archived removal history. PMs and assigned leads can add; edit/removal remains PM-only. The main customer is edited through the top job-details pencil.

Type choices use the existing relationship field: Customer, Subcontractor, Site contact, Other. Existing custom relationship/trade values are preserved. Selecting Subcontractor when adding allows choosing a company from the active directory, copying name/phone/email into this job contact. It is a snapshot: later directory edits do not propagate, no scope icons or staffing are assigned automatically, and removing the job contact does not remove the directory company. Helpers do not receive the directory data. No schema update is needed.

My Jobs now has exactly three filter controls: All work, Rain day, Filler. The combined Rain-day filler control was removed; independent rain and filler tags remain usable together on jobs. Automated suite: 118 passed; TypeScript passed. Authenticated inline add/select/save/edit/remove and phone layout acceptance are pending together with the final normal-user production build. Project work redesign remains a separate user review.

## Follow-up: simpler work overview

Active work uses compact rows/cards: description + lead + readiness, scheduled dates + crew, an edit pencil, and a quiet Finish action. The heading owns Add work and the work/leads pencil; there are no separate bottom Edit work/leads or Add work sections repeating those controls. The work/leads panel retains one atomic Save/Cancel across all active portions and closes only on confirmed success or Cancel. Add work is inline and also closes after a confirmed save. No separate screen is introduced.

Each portion offers Add date; work completion, reopening and recording returns remain in More. Existing open returns stay visible, and completed work/history stays separate. Helpers still get a read-only assigned-work view; leads and PMs retain their existing live permissions. Finish scheduled work continues to be distinct from completing a portion or closing a job. No timing, staffing, scope or readiness rules changed. No new SQL.

Validation: 119 automated checks and TypeScript pass, including compact scheduling visibility/action-role checks and existing completion/return/history guards. Real authenticated desktop/phone layout acceptance and a final production build after the UI batch remain pending; current development server was not stopped and no build was run against it. Latest confirmed uploaded checkpoint remains a91da8c.

## Planning-only correction

Per user clarification, Finish/Finish scheduled work have been removed from all scheduled-entry views. The calendar is for future plans and staffing, without per-day completion reporting. Automated role/render checks cover both compact job cards and standard calendar cards and ensure no Finish control is rendered. 119 checks and TypeScript pass. No SQL needed for this UI correction.

Keep the remaining optional whole-portion/return closure rules separate: existing applied SQL still guards closure when planned entries exist. Reconcile those guards in a future guarded closure change before testing that workflow; never require daily check-offs or cancel past plans merely to satisfy a legacy completion guard. History is retained and elapsed dates do not assert that work was actually completed.

Completion control follow-up (D52): removed Complete this work, standalone Reopen work and Mark return handled controls too, including the legacy return-work component. The job UI now has planning/add-return actions, with no per-entry, portion or return completion check-off forms. Existing recorded history is preserved. 119 checks and TypeScript pass; no SQL needed. Supersedes earlier text retaining optional whole-portion close-out controls in this UI.

## Unified work (D53)

There is one Add work flow whether work is entered initially or later. No separate Return work, Add return work, Plan return or handled-return UI remains, and the empty More submenu is removed. Planning forms now say Save work; removing scheduled dates says Remove from schedule and keeps the original work. Work history retains existing outcomes. Dates, optional times and staffing rules are unchanged.

Earlier follow-up records are retained as ordinary notes on their original work, including owner and target date; duplicate remaining-note text is suppressed. Existing scheduled entries keep their links and crew. This is a presentation/workflow unification, not a hidden database conversion: applied SQL and stored audit/legacy data are unchanged. New work uses the ordinary work-item creation command. Automated checks verify retained notes/target date, no separate return or completion controls, normal schedule payload and Save work wording. 120 checks and TypeScript pass; full build/authenticated phone acceptance pending.
