# Ordered lead work queues

Verified desktop checkpoint 2026-10-22. User confirmed migration 0007 success, 58 SQL checks with 0 failures, full production build and the browser checks below. Queue changes remain local until committed/pushed. Latest uploaded checkpoint before this work is c38984c (ownership access evidence); implementation before that is a79c78e.

## Workflow

Lead queues appears in the app footer for active PM/lead roles. Leads open their own queue; PMs choose an active lead. Helpers/admin-only accounts have no queue navigation or queue permission. The page lists open work portions owned by the selected lead on open jobs, including waiting work with its existing readiness label. Two portions of the same job remain separate entries with job links; queues do not create dates, visits, staffing or availability reservations.

Up/Down buttons change a draft order with visible priority numbers; no drag required. One Save/Cancel pair controls the queue. Save writes the full work-ID order atomically, with no expected-revision rejection: the latest committed order wins if membership still matches. Cancel restores the last loaded order and discards the draft. Issued save requests use a stable actor/request UUID; uncertain saves freeze the order for safe retry, while a confirmed save returns the actual current queue and rotates the UUID. No redundant client refresh is needed after the action's revalidation.

New owned open work appends deterministically; surviving entries keep their order. Reassignment, unassignment, completion or job closure removes membership. Reopened work rejoins at the end (multiple newly eligible items use created_at/id). Changes run inside the existing ownership/completion/job transaction through triggers, so no separate ACL grant or manual queue-entry setup is needed. Waiting work stays queued; readiness editing and scheduling are later slices.

If membership changed while an order draft was open, Save rejects the whole order and offers Reload queue. This is a membership check, not stale-version approval: order-only competing saves still follow latest-commit-wins. Reload discards the stale draft; no assignment is taken from another lead. Up to 500 current entries per queue are supported by the page/save boundary; over-limit queues show an explicit review message rather than a truncated editable order. The 500 UUID order fits the existing 32 KB action input limit.

## Database boundary

0007 adds private.lead_queues and private.lead_queue_events, both RLS enabled and with employee raw privileges revoked. Only get_lead_queue/save_lead_queue RPCs are granted to authenticated employees; both require active PM or the target active lead. Reads expose only this lead's current work/job context; helpers cannot enumerate queues or assignment candidates. Events retain final full order, revision, actor, operation and optional request ID. Membership events may have null actor for technical backfill. No history UI or public history endpoint is added yet.

The migration backfills existing ownership and installs work ownership/completion/job lifecycle triggers; it creates no employee/customer fixtures. Existing applied migrations/functions are unchanged. All supported queue membership changes and order saves take one company-wide advisory transaction lock before queue row locks. This deliberately serializes small-company queue mutations, including cross-lead changes, while read RPCs remain lock-free. Queue saves never lock jobs/work rows, so they cannot form a queue->job cycle with the existing job->work->queue write order. This is an implementation tradeoff for the initial approximately 20-lead workload, not a claim of independent write throughput per lead. Future multi-job commands must preserve this lock protocol; real concurrent tests remain required.

Canonical actor/request receipts reject changed payloads and keep old retries from overwriting newer committed orders. A retry returns the current authorized queue. No-op new orders receive a receipt without a new order revision/event. Membership events and reorder events share monotonic revisions; existing work/job audit records remain separate. Raw work writes remain denied by earlier grants.

## Verification

All 63 Node tests and TypeScript pass, including five new queue domain/transport/action tests: move boundaries and membership preservation, role/target denial, exact scoped RPC payloads, membership conflict handling, no false success/refresh and uncertain retry state. Tests mock database transport. They do not prove SQL execution, locking or actual client rendering.

0007_lead_queues.test.sql prepares 58 rolled-back checks: scoped/raw/anonymous/deactivated access; exact membership, invalid/null/duplicate/multidimensional/bounded input; sequential two-PM latest-save behavior; unrelated contact preservation; actor/full-order history; old retry safety; own-lead save; no-op behavior; automatic append/removal/reassignment/completion/closure/reopen and live role removal. This is a single-connection suite, not concurrent-transaction proof. User reported 58 checks, 0 failed after correcting three test-only integer/bigint assertion mismatches. The applied migration was unchanged.

Prepared migration SHA-256: 5e080ac2d88727e66ff696adba6dfe5c1c7488e0d3bf836fa2523dae09818d1e.

0007 is applied in isolated project vglhojtrccygjgupxsrd. Do not rerun it. User full build included /queue and passed. Browser confirmed PM sees both portions, Cancel restores original order, Save finishes without a stuck spinner and refresh retains order; Test Lead sees the PM order and can reorder/save/refresh; helper direct /queue redirects to /jobs. PM unassigned countertops and confirmed removal from the queue, then reassigned it and confirmed it appended after cabinets. Both portions are currently assigned to Test Lead. No new secrets, paid service or email setup.

Remaining browser checks include unrelated-lead direct denial and stale membership handling. Use two clients to check stale order-only saves and stale membership rejection. Actual phone usability, lost-response retry, live expiry/deactivation, clean-reset repeat, index/query measurements and simultaneous multi-connection serialization are pending. Before pilot, use two real test DB connections to race queue saves against each other and against reassignments, verify exact final membership/order/audit and unchanged unrelated contact edits. Do not treat a sequential test as this evidence.
