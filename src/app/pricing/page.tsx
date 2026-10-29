import Link from 'next/link';
import {redirect} from 'next/navigation';
import {currentSession} from '../../lib/session';
import {pricingSession} from '../../lib/pricing-session';
import {contactUuid} from '../../domain/contacts.ts';
import {AppError} from '../../domain/access.ts';
import {companyToday} from '../../domain/visits.ts';
import {Shell} from '../components/shell';
import {PricingResults,PricingUpload,PricingReview,DiscardPricingUpload} from '../components/pricing-workspace';
export const dynamic='force-dynamic';
export default async function Pricing({searchParams}:{searchParams:Promise<{q?:string;review?:string;history?:string}>}){
 const session=await currentSession();if(!session?.actor.active||!session.actor.roles.some(r=>['pm','admin','lead'].includes(r)))redirect('/jobs');const manager=session.actor.roles.some(r=>['pm','admin'].includes(r)),query=await searchParams,q=String(query.q??'').slice(0,200);
 try{const {gateway}=await pricingSession(),[directory,lists,result]=await Promise.all([gateway.listSubcontractors(),gateway.lists(),q?gateway.search(q):Promise.resolve(null)]),vendors=directory.filter(v=>v.contact_types?.includes('vendor'));
 let review=null;if(manager&&query.review){const list=await gateway.list(contactUuid(query.review));if(list&&list.status!=='uploading')review=<PricingReview key={list.id} list={list} initialRows={await gateway.rows(list.id)} vendor={directory.find(v=>v.id===list.vendor_id)?.name??'Vendor'}/>;}
 return <Shell title="Vendor pricing"><form action="/pricing" className="queue-filter"><label>Find a material<input type="search" name="q" defaultValue={q} maxLength={200} placeholder="2x12x12 Doug fir lumber"/></label><button className="button primary">Search</button></form><p className="muted">Published USD material prices. Confirm specifications, current availability, tax and delivery with the vendor.</p>{review??<>{result?<PricingResults {...result}/>:<p>Search by product, size, species or SKU. Prices are compared within matching reviewed specifications and selling units.</p>}{manager&&<PricingUpload vendors={vendors} today={companyToday()}/>}</>}<section className="stack"><div className="section-heading"><h2>Price sheets</h2><Link href={'/pricing'+(query.history==='1'?'':'?history=1')}>{query.history==='1'?'Show current':'History and drafts'}</Link></div>{lists.filter(l=>query.history==='1'||l.status==='published'||manager&&['draft','uploading'].includes(l.status)).map(l=><article className="compact-contact-row" key={l.id}><div><strong>{directory.find(v=>v.id===l.vendor_id)?.name??'Vendor'} — {l.catalog}</strong><p>{l.filename} · {l.effective_on} · {l.status}{l.expires_on&&l.expires_on<companyToday()?' · Expired':''}</p></div>{l.status!=='uploading'&&<Link className="button" href={manager?'/pricing?review='+l.id:'/pricing/source/'+l.id}>{manager&&l.status==='draft'?'Review':'Open'}</Link>}{manager&&l.status==='uploading'&&<DiscardPricingUpload id={l.id}/>}</article>)}{!lists.length&&<p>No price lists uploaded yet.</p>}{lists.length===100&&<p>Latest 100 price sheets shown.</p>}</section><Link href="/subcontractors?type=vendor">Manage vendor contacts</Link></Shell>;
 }catch(e){if(e instanceof AppError&&e.code==='schema_pending')return <Shell title="Vendor pricing"><p>Vendor pricing needs the prepared database update before it can be used.</p></Shell>;throw e;}
}
