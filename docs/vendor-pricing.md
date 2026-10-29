# Vendor pricing

Prepared October 29, 2026. 0024 is NOT APPLIED. Existing demo checkpoint is 30663e1. This feature does not reseed or archive the demonstration jobs.

## Employee workflow

Pricing is one page at /pricing. PMs and administrators upload and manage price lists; PMs, administrators and leads search published pricing. Helpers have no pricing access, including direct database and Storage requests. All app reads/writes use the signed-in employee JWT, never the employee-provisioning admin key.

Company contacts retain the /subcontractors URL but are labeled Contacts, with Vendor and Subcontractor types. A company can have both. Existing directory records default to Subcontractor; they are not duplicated. Vendor pricing references the canonical company ID. Existing job contacts remain copied contact details, rather than automatically synchronized directory links.

1. Add or edit a company contact and select Vendor.
2. Pricing > Upload price list: choose vendor, catalog name (e.g. Lumber), effective date, optional expiration and tax/freight notes, then a PDF, XLSX or CSV up to 20 MB. Older XLS files must first be saved as XLSX/CSV.
3. Read file. For scanned English PDF pages, use Read scanned pages. Read extraction warnings, compare against the original, correct missing/misread products, units, quantities, prices and specifications, and confirm reviewed rows. Manual Add item and Save draft are available.
4. Publish pricing. A currently effective list replaces the published list for that same vendor/catalog; previous originals and prices remain in history. Publishing never happens automatically. A future/expired list cannot replace current pricing.
5. Search by size/species/grade/product or SKU. Prices sort cheapest first within the same reviewed comparable specification, selling unit and pack quantity. Different grades, units and quantities remain separate groups; no price-per-foot conversion or availability claim. Source links include original PDF page or spreadsheet row. Dates, expiration, 90-day age and vendor terms remain visible. Only active vendors' current, in-date published catalogs appear.

Use consistent catalog names on monthly uploads. Withdrawal removes a list from current results and retains history; it does not silently reactivate a superseded list. An unfinished upload can be discarded from the list. Signed file links expire after 60 seconds; reopen from the app when needed.

## Parsing limits

Real generated PDF and XLSX files are covered in local tests. Actual vendor layouts and browser OCR have NOT been accepted yet. PDFs are variable: price columns, headers, images and OCR can be omitted/misread. Extraction is always an unconfirmed draft. A PM must check completeness and every selling specification/price before publication; unknown units stay blank. Scanned/empty pages are flagged. Mixed image/text PDFs may need manual entry when their text header masks scanned body content.

Maximum 100 PDF pages, 2,000 reviewed items per catalog, 10 scanned pages per OCR pass, and 60 MB expanded XLSX content. Split larger catalogs. English OCR executes on the employee's browser using app-served workers/models; it does not send price documents to an external AI/OCR service. Parsing is best effort, with manual entry as a fallback. USD only; tax, freight, discounts and stock are vendor notes rather than silently calculated totals.

Review edits reset row confirmation. The version guard rejects another PM's intervening draft save. Save/publish retries retain the identical request and payload after an uncertain response. Original uploads use immutable scoped paths with no employee overwrite/delete policies. Originals, drafts and reviewed rows are private; leads cannot read unreviewed or discarded unpublished drafts.

## Database update and grouped acceptance

Run database/batches/0024_vendor_pricing.sql once in the fictional Supabase project after 0023. It adds contact fields, price tables/functions and a private vendor-price-sheets bucket. Its 40 synthetic checks roll back fixtures before the sole commit. It stops if 0024 already exists. Do not rerun old migrations. SQL checks are prepared but have not run against Supabase in this development turn.

After application, restart the local app if necessary and review /pricing:
- PM: make one Vendor contact, upload one actual PDF and XLSX, check/correct and publish rows.
- Lead: search a product, compare two equivalent vendor prices and open source/page. No upload/publish controls.
- PM: publish a replacement catalog; current results change and old source remains in history. Try a different unit or grade to confirm separate comparison groups.
- Helper: /pricing and direct source access are denied. Draft data is not visible to leads.
- Include one real scanned sheet if used; inspect extraction and correction effort before relying on bulk monthly imports.

## Recovery

Updated operator backups include both eigsti-job-files and vendor-price-sheets, including original file bytes. Inventory checks distinguish bucket/key, apply the correct size limits, and retain one database snapshot while exporting and copying both buckets. Old format-1 job-only archives remain supported. A pre-0024 source is detected inside the snapshot and does not query nonexistent price tables.

New manifests explicitly identify the bucket. Pricing bytes are stored under storage/vendor-price-sheets/vendor-id/list-id; legacy job bytes retain storage/job-id/file-id. Restore each object to its manifest bucket/key through the target Storage API, never only its database row. Synthetic archive tests verify two buckets and exact bytes. No new live backup, restored database or production hosting is claimed.

October 29 update: owner confirmed the guarded 0024 batch completed as expected (40 checks, 0 failed). This supersedes the prepared/not-applied statements above; do not rerun it. Publish now displays adjacent progress/error/success feedback and selects the first invalid item page, with no native popup for publishing or bulk review attestation. Actual vendor-file acceptance remains in progress.
