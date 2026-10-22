# Job details layout proposal

Approved by the user and implemented locally, along with a shared theme for initial pages. See ui-layout-refresh.md for the actual implementation and pending acceptance. The original static mockup remains reference-only; earlier proposal wording below records the design discussion.

Requested after the user successfully reached the app following combined 0010/0011 acceptance. This is a design proposal, not a change to the live page. The grouped feature browser tests remain incomplete.

The current page repeats work descriptions/leads in Work and leads, Scheduled visits, and Completion and return work. Standalone cards for location, customer, tags, scope, access, contacts and files make daily field work harder to find. Permanent setup instructions add noise for carpenters.

## Recommended order

1. Compact job heading: title, address, short rain-day/filler/status labels. Directions / Call / Text stay one tap away; avoid duplicate customer/title information and a large branding block.
2. Before you start: show access/preparation notes when present. Keep important arrival instructions visible rather than hidden inside job notes.
3. My work first for a lead/helper; all active work for PM. One combined card per work portion contains its description, lead/help, current or next scheduled entries, readiness, remaining work and open returns. Group upcoming appointments beneath the relevant work instead of repeating them in a separate section. A simple one-portion job should look like one work card.
4. Other project work: compact summaries, expandable in place for leads/helpers. Preserve authorized shared-job visibility. PM sees all active portions without needing to expand each as a separate screen.
5. Project scopes: all icon buttons always visible. See explicit user direction below.
6. Supporting information: Job scope and notes, Contacts, Photos and files, Completed work/history as compact expandable rows with useful counts. Open returns remain in the active work card, not hidden in history.

## Scope button direction confirmed by user

Always show every scope button, including inactive types. Use the icon and a short readable trade label; active types are green and inactive types quiet/neutral. No separate checkbox list or expand-more selector. Authorized users tap buttons directly to toggle a draft; show one Save/Cancel pair only when changed. Use accessible pressed state and a shape/border difference in addition to color. Recommend avoiding strike-through because it can imply completed work.

Whole house remains a visible choice while all individual types stay visible, superseding the earlier compact hidden-scope presentation for this job-details proposal. Do not silently infer/select every trade from it. Rain-day/filler tags remain separate. The proposal does not grant new editing permissions: PM manages job classifications; other authorized readers see the same selected scopes without editable controls.

## Interaction principles

Inline editing remains on this page. Forms appear when needed and keep one Save/Cancel per logical card, retaining existing atomic boundaries. Never combine unrelated lifecycle commands into an ambiguous Done action. Finish scheduled work, complete a work portion and close the job remain distinct and retain current safeguards. Completed/cancelled appointment history is tucked away; current and upcoming schedules and unfinished returns remain discoverable. Role-specific controls preserve server permissions.

Avoid permanent implementation instructions such as how to rename Whole job or split portions. Put optional guidance beside the relevant PM Add work action. Do not add tabs or extra edit pages for the main field workflow.

Example interaction mockup: eigsti-job-layout-proposal.html at repository root. Fictional data only; it does not call the app/backend or alter project data. Native expanded rows and scope selection demonstrate the proposal; it is not a production component or complete acceptance test.
