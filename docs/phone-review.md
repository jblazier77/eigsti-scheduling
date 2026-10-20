# Phone interaction review

Prototype: prototype/index.html, via `npm run preview`. Synthetic, memory-only, no sign-in or server saves. Refresh resets changes. New layout proposal; approved mockups were not included, so fidelity to them cannot be claimed. No actual phone review has happened.

Large controls (minimum 48px), day list as lead default, fixed bottom navigation, job list, short job details, three-field PM creation, helper read-only view and admin directory outline. Review buttons allow choosing a role for demonstration only; the real app must derive roles from sign-in.

| Role | Review sequence | Expected result |
| --- | --- | --- |
| Lead | My Jobs → first ready job → Plan work → choose date → Add to week | A synthetic all-day visit appears; no mandatory time or daily report |
| Lead | My Week → Done here → Need a return visit | Visit ends; job stays open and remaining work is visible |
| Lead | Job → Add sub visit → Friday, time not set | Commitment appears, without a named internal reservation |
| PM | Jobs → My Jobs/All Jobs → New job | Three fields create synthetic job/default work; no mandatory phases |
| Helper | My Schedule → Job details | Location, lead, preparation context; no edit or completion controls |
| Admin | People and settings | Account/contact operations listed as future implementation, no false live invites |

Use two nontechnical leads, one PM and a helper on real iPhone/Android devices. Ask users to plan a known job, finish with a return, and find a phone/directions action without coaching. Measure Friday sub entry from job open (~15 seconds proposed) and routine few-tap planning. Review legibility, reachability, keyboard/scroll behavior and save understanding. Fixture creation has browser memory feedback only; production failed-save/session/duplicate checks require Phase 1+.

Pending review inputs: existing approved mockup/screenshots if any; actual pilot participants; holiday/overtime exceptions (Monday-Friday, 07:00-15:30 with noon split now approved); attachment file types, especially iPhone HEIC. No mandatory typing or new reports should be added to fix layout problems.
