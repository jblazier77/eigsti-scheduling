import {redirect} from 'next/navigation';
import {requireSession} from '../../lib/session';
import {AppError} from '../../domain/access.ts';
import {Shell} from '../components/shell';
import {EmployeeList} from '../components/employee-list';
export const dynamic='force-dynamic';
export default async function Employees(){
 const {actor,gateway}=await requireSession();if(!actor.roles.includes('admin'))redirect('/jobs');
 let employees;
 try{employees=await gateway.listEmployees();}catch(error){if(!(error instanceof AppError)||error.code!=='schema_pending')throw error;return <Shell title="Employees"><p>Employee management is not available until the database update is applied.</p></Shell>;}
 return <Shell title="Employees"><EmployeeList employees={employees} actorId={actor.id}/><details className="support-section"><summary>New accounts and password resets</summary><p>Pilot accounts and password resets are set up manually in Supabase by an authorized operator. This screen manages existing app profiles. Employees change their own password in My account. Email invitations and forgotten-password emails are planned for a later phase.</p></details></Shell>;
}
