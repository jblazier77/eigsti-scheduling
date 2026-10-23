import Link from 'next/link';
import type {CalendarJob} from '../../server/supabase.ts';
export function CalendarJobHeader({job,contactId}:{job:CalendarJob;contactId?:string}){
 return <header className="calendar-job-header"><strong><Link href={'/jobs/'+job.id+(contactId?'#contact-'+contactId:'')}>{job.customer_name}</Link></strong><span className="calendar-address">{job.address}</span>{job.phone_action&&<a className="calendar-phone" href={'tel:'+job.phone_action} aria-label={'Call '+job.customer_name+' at '+job.phone}>{job.phone}</a>}</header>;
}
