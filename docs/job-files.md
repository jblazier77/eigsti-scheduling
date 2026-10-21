# Private job attachments

Checkpoint 2026-10-21. User confirmed migration 0003 applied, 66 SQL checks with 0 failures, and a successful full production build. Desktop test upload, matching original download, refresh persistence, removal/refresh and helper upload-route denial passed per user. Real iPhone tests remain required. Implementation is local, awaiting commit/push.

## Behavior

The job files section lists available files and, for the uploader, unfinished uploads. PMs and assigned leads can upload PDFs, JPEG/PNG/WebP images and original HEIC/HEIF photos. Other employees with job access can download ready files. Only a file selection is required. The existing job/contact workflows remain separate.

The initial limit is 10 MiB (10,485,760 bytes) per file, matching the existing proposed 10 MiB baseline. The UI calls this 10 MB. At most 100 non-archived file records per job, including pending uploads, enforced under a job row lock. Name max 180 characters; path separators, control characters and leading-dot names are rejected. Extension/type must match. Blank/octet-stream browser MIME is inferred from the allowed extension. Videos, SVG, HTML and other formats are not supported. Format validation is not a content scanner and does not prove the binary is safe or decodable.

Files retain their uploaded format; HEIC viewing depends on the downloading device. There is no conversion/thumbnail service or inline untrusted document rendering. Download requests force attachment disposition using the original filename. iPhone picker conversion/format behavior must be tested on a real phone before claiming mobile acceptance.

## Upload and privacy design

1. A small cookie-authenticated Server Action verifies the employee through Auth/live app membership and reserves a pending record with one stable actor/request UUID. A repeat request with identical normalized metadata returns the same file ID; changed metadata conflicts.
2. The storage path is generated from job UUID/file UUID, not supplied by the filename. Only the reserving active PM/assigned lead can obtain an insert capability for a pending path. The private bucket enforces the size and allowed MIME types. No object overwrite/upsert or direct deletion is allowed through employee storage policies.
3. The browser sends bytes directly to Supabase using that path-scoped signed upload URL, with no employee session token/cookies/admin key in that request. The app's 32 KB Server Action limit remains unchanged and the bytes do not traverse a Vercel Function.
4. Finalization rechecks live membership and job write access, then SQL checks the stored object's size and MIME against the reservation. Only matching uploaded metadata transitions to ready and is audited once. This is storage metadata verification, not file-content scanning.
5. On retry, the app first attempts finalization. A previous transfer with a lost response therefore becomes ready without another object/write. If no object exists, a fresh capability is issued for the same path. The selected File stays in memory and cannot be changed after the first attempt; closing/reloading the tab loses that selection.

The private bucket has both permissive job-specific policies and restrictive boundaries so broad existing storage policies cannot accidentally grant access to this bucket. Ready reads follow private.can_read_job; pending reads require the active uploader and current write access. Helpers, admin-only, inactive and unrelated employees cannot write. SQL additionally requires parent job/file IDs to match. No administrative/service-role key is used.

Downloads use a cookie-authenticated job/file route, verify Auth/profile and metadata RLS, and issue a forced-download signed URL valid for 60 seconds with no-store/no-referrer response headers. This avoids routing file bytes through app hosting. Already issued URLs are bearer capabilities: a copied download URL may continue to work for its remaining 60 seconds even after access removal. New URLs immediately require current access.

Supabase signed upload capabilities last two hours and do not require further authentication. A capability already issued may still accept its one path after account deactivation/removal; live SQL finalization will not publish it after access is lost, and object overwrite is disabled. Do not describe this as immediate revocation of issued URLs. Never log, persist in the database or show these signed URLs as permanent links.

## Removal, interrupted work and recovery

PMs can remove any file on a job. Assigned leads can remove only their own uploads. Explicit confirmation calls an audited, retry-safe soft archive and redirects back to the job. Archived records disappear and cannot receive new read URLs or be finalized/restored by employees. Original bytes and identity remain for recovery/history. This consumes storage until an authorized retention process removes bytes through Storage API; no physical delete or cleanup job is added here.

An abandoned upload stays pending, is invisible to helpers, and can be removed by the uploader (with current access) or a PM. Orphan/mismatched/pending bytes are identifiable by the reservation/path but not automatically purged. Old upload capabilities must expire before any future physical cleanup. The existing proposed company usage warning at 5 GB and independent file backup/restore are not implemented; storage usage and quotas must be monitored before pilot. Account departure cleanup and recovery remain operational work.

## Setup and evidence

- Last confirmed uploaded checkpoint before this work: dea0af9 (contacts verified).
- 40 Node tests pass; TypeScript passes. Six file checks cover format/size/path validation, role denial, retry behavior, scoped storage signing, employee identity and URL safety.
- New database/migrations/0003_job_files.sql creates the private bucket, metadata table, restrictive storage boundaries and begin/finish/archive commands. No customer fixture is added.
- New database/tests/0003_job_files.test.sql has 66 assertions, all fixtures rolled back. User confirmed 66 checks, 0 failed after a test-only correction to assertion 37's data-modifying CTE placement. Synthetic metadata does not create/test binary bytes.
- Migration 0003 is applied in test project vglhojtrccygjgupxsrd. Do not manually create a conflicting bucket or rerun applied migrations.
- Full production build passed in normal user PowerShell. Actual desktop upload/download/removal and helper upload denial also passed; the specific test format/size were not recorded. Agent builds previously triggered Windows/OneDrive cleanup failures, so no repeat cleanup attempt is made here.
- Browser acceptance: small fictional PDF/photo upload, refresh, original download, remove/refresh, invalid/oversize file rejection, interrupted transfer/retry without duplication, helper upload-route denial, assigned helper download, unrelated/anonymous download denial and expired signed URL. Real phone HEIC/HEIF and near-10-MiB transfer tests remain essential.
- No paid service, email, Google integration, production deployment or automatic contact/subcontractor scheduling change is introduced.

## Sources checked 2026-10-21

- https://vercel.com/docs/functions/limitations — request/response body limit 4.5 MB; direct upload avoids routing the allowed 10 MiB file through the Function.
- https://supabase.com/docs/reference/javascript/storage-from-createsigneduploadurl — scoped unauthenticated upload capability valid two hours.
- https://supabase.com/docs/guides/storage/security/access-control — object operation RLS; INSERT for upload, additional policies for overwrite; service keys bypass RLS and are not used.
- Installed @supabase/storage-js source — createSignedUploadUrl, createSignedUrl download option and path construction; installed Next route/action documentation reviewed for the implementation.
