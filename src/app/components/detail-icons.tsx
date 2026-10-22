export function DetailIcon({kind}:{kind:'edit'|'attachment'|'photo'|'document'|'phone'|'message'|'mail'|'plus'}) {
  const path={edit:'m15 4 5 5 M4 20l5-1L21 7l-5-5L4 14z',attachment:'m8 12 7-7a4 4 0 0 1 6 6L10 22a6 6 0 0 1-8-8L13 3 M6 16l9-9',photo:'M3 4h18v16H3z M3 16l6-6 5 5 3-3 4 4 M16 8h.01',document:'M5 2h9l5 5v15H5z M14 2v6h5 M8 13h8 M8 17h6',phone:'M6 3H3v4c0 8 6 14 14 14h4v-5l-5-2-2 3a12 12 0 0 1-7-7l3-2-2-5z',message:'M3 3h18v14H9l-6 4z M7 8h10 M7 12h7',mail:'M3 5h18v14H3z M3 5l9 7 9-7',plus:'M12 5v14 M5 12h14'}[kind];
  return <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={path}/></svg>;
}
