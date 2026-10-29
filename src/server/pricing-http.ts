import {AppError} from '../domain/access.ts';
export async function pricingBody(request:Request){
 // Next may construct request.url with an internal host behind a dev/hosting proxy.
 // Match the browser-facing Host, or browser-generated same-origin Fetch Metadata.
 // Do not trust arbitrary X-Forwarded-Host values as an origin allowlist.
 const site=request.headers.get('sec-fetch-site');let allowed=false;
 try{const raw=request.headers.get('origin')??'',origin=new URL(raw),target=new URL(request.url),host=request.headers.get('host')??target.host;
  const canonical=['http:','https:'].includes(origin.protocol)&&raw===origin.origin;
  const sameHost=origin.host.toLowerCase()===host.toLowerCase()&&origin.protocol===target.protocol;
  allowed=canonical&&(site==='same-origin'||sameHost&&(site===null||site==='same-site'));
 }catch{/* Invalid or missing Origin is denied. */}
 if(!allowed||request.headers.get('content-type')?.split(';')[0].trim().toLowerCase()!=='application/json')throw new AppError('not_allowed',403,'Use the pricing page to save changes.');
 const reader=request.body?.getReader();if(!reader)throw new AppError('invalid_input',400,'Missing price rows.');const chunks:Uint8Array[]=[];let size=0;
 try{for(;;){const {value,done}=await reader.read();if(done)break;size+=value.length;if(size>4*1024*1024){await reader.cancel();throw new AppError('invalid_input',413,'Split this price list into smaller catalogs.');}chunks.push(value);}}finally{reader.releaseLock();}
 const bytes=new Uint8Array(size);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length;}
 try{return JSON.parse(new TextDecoder().decode(bytes));}catch{throw new AppError('invalid_input',400,'Invalid price data.');}
}
