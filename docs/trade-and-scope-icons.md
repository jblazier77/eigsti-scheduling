# Trade and project-scope icons

Requested by Josh on 2026-10-22 for the initial build (R27). Implemented locally with 0011; database/build/browser acceptance remains pending. Use combined-batch.md for the grouped setup and acceptance.

Identify subcontractors by trade/type of work with small recognizable icons. Show project scopes on job cards so users can quickly understand the work involved. For full-house projects with all scopes, show a compact house/Whole house indicator instead of a crowded row of icons. Keep scope detail available when expanded.

Local implementation:

- Share consistent trade names/icons between subcontractor classification and project scopes; allow multiple trades per subcontractor.
- Select project scopes independently of subcontractor assignment so internal work and trades not yet assigned are represented accurately.
- Use accessible names and readable labels on expansion; provide tap access on phones without depending on hover or color.
- Make Whole house an explicit compact display choice, retaining the actual scope list. Do not infer every catalog trade is required.
- Keep rain-day and filler tags visually distinct. Prefer inline edits with shared Save/Cancel.
- Preserve existing job permissions, readiness and staffing rules. Icons do not create appointments or imply completion.

Initial catalog: roofing, siding, windows/doors, framing, electrical, plumbing, HVAC, drywall, painting, flooring, cabinetry, tile, concrete, landscaping and general repairs/punch list. Changes require coordinated client/server catalog validation. PM/admin manage the directory, leads read it, helpers have assigned job information only. PMs edit project tags/scopes. No automatic subcontractor-to-job linking or scheduling commitments are introduced.

Consolidated acceptance should cover multi-trade subcontractors, project scopes without assigned subcontractors, whole-house expansion, readable phone/desktop markers, persisted edits/Cancel and access restrictions.
