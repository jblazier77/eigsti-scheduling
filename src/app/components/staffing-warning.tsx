import type {Visit} from '../../domain/visits.ts';
import {helperDeficit} from '../../domain/visits.ts';
export function StaffingWarning({visit}:{visit:Visit}){
 const missing=helperDeficit(visit);
 if(!missing)return null;
 return <span className="staffing-warning" role="status" title={missing+' of '+visit.required_helpers+' requested helpers still needed'}><svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3 2 21h20L12 3z M12 9v5 M12 17h.01"/></svg><span>{missing} {missing===1?'helper':'helpers'} needed</span></span>;
}
