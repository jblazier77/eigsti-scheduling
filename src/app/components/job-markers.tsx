import { trades, type JobClassification } from '../../domain/job-classification.ts';

const paths: Record<string,string> = {
  rain:'M4 14a4 4 0 0 1 0-8 6 6 0 0 1 11-1 4.5 4.5 0 1 1 3 9H4 M7 17l-1 3 M12 17l-1 3 M17 17l-1 3',
  house:'M3 11l9-8 9 8 M5 10v11h14V10 M9 21v-8h6v8',
  filler:'M8 3h8v4H8z M8 5H5v16h14V5h-3 M8 12h8 M8 16h5',
  roofing:'M2 12L12 3l10 9 M6 10v10h12V10 M6 15h12',
  siding:'M3 3h18v18H3z M3 8h18 M3 13h18 M3 18h18',
  windows_doors:'M4 3h16v18H4z M12 3v18 M4 12h16',
  framing:'M3 21V3h18v18 M8 3v18 M16 3v18 M3 9h18',
  electrical:'M13 2L4 14h7l-1 8 10-13h-8z',
  plumbing:'M5 3v6a7 7 0 0 0 14 0V3 M2 3h6 M16 3h6 M12 16v6',
  hvac:'M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6 M12 9c-6-9 8-9 3 1 M15 12c10-5 10 8 0 3 M12 15c6 9-8 9-3-1 M9 12c-10 5-10-8 0-3',
  drywall:'M3 3h18v18H3z M12 3v18 M3 12h9 M12 8h9 M12 16h9',
  painting:'M3 3h14v7H3z M17 6h4v8h-9v7h-3v-8h12',
  flooring:'M3 4h18v16H3z M3 10h18 M3 15h18 M9 4v6 M15 10v5 M8 15v5',
  cabinetry:'M3 3h18v18H3z M3 9h18 M12 9v12 M7 6h10 M9 13v4 M15 13v4',
  tile:'M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z',
  concrete:'M3 15l12-8 6 4-12 8z M3 15v5l6 2 12-8v-3 M9 19v3',
  landscaping:'M12 22V10 M12 16C2 18 2 5 3 3c9 0 10 5 9 10 M12 12c0-8 8-9 9-9 1 8-3 12-9 12',
  general:'M14 6l4 4 M3 21l8-8 M8 8l8 8 M3 3l5 1 1 4-2 2-4-3z M16 16l5 5 M14 6l5-4 3 3-4 5'
};
export function WorkIcon({kind}: {kind:string}) {
  return <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={paths[kind] ?? paths.general}/></svg>;
}
export function JobMarkers({value, expanded=false}: {value:Partial<JobClassification>; expanded?:boolean}) {
  const selected=trades.filter(t=>value.trades?.includes(t.id));
  return <div className="job-markers">
    {value.rain_day&&<span className="scope-chip rain"><WorkIcon kind="rain"/>Rain-day option</span>}
    {value.filler&&<span className="scope-chip"><WorkIcon kind="filler"/>Filler work</span>}
    {value.whole_house&&<span className="scope-chip"><WorkIcon kind="house"/>Whole house</span>}
    {!!selected.length&&<div className="scope-labels" aria-label="Job scopes">{value.whole_house&&!expanded?<span className="sr-only">{selected.map(t=>t.label).join(', ')}</span>:selected.map(t=><span className="scope-chip" key={t.id}><WorkIcon kind={t.id}/>{t.label}</span>)}</div>}
  </div>;
}
