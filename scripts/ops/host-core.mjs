// Unauthenticated, read-only hosting smoke test; no cookies or app credentials.
export async function checkHost(input,transport=fetch){
 const base=new URL(input);
 if(base.protocol!=='https:'||base.username||base.password||base.port||base.pathname!=='/'||base.search||base.hash)throw new Error('Use the hosted HTTPS origin only.');
 const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
 const routes=[['/login','public'],['/jobs','page'],['/queue','page'],['/schedule','page'],['/employees','page'],['/subcontractors','page'],['/account','page'],['/api/jobs','api'],['/jobs/'+id+'/files/'+id+'/download','api'],['/jobs/'+id+'/files/'+id+'/preview','api']];
 const results=[];
 for(const [path,type]of routes){
  try{
   const response=await transport(new URL(path,base),{method:'GET',redirect:'manual',cache:'no-store',signal:AbortSignal.timeout(20000)});
   const location=new URL(response.headers.get('location')||'/',base);
   const access=type==='public'?response.status===200:type==='api'?response.status===401:[302,303,307,308].includes(response.status)&&location.origin===base.origin&&location.pathname==='/login';
   const headers=response.headers.get('x-content-type-options')==='nosniff'&&response.headers.get('x-frame-options')==='DENY'&&/no-store/i.test(response.headers.get('cache-control')||'');
   results.push({path,status:response.status,passed:access&&headers});await response.body?.cancel();
  }catch{results.push({path,status:null,passed:false});}
 }
 return {origin:base.origin,passed:results.every(row=>row.passed),checks:results,authenticated_device_review_verified:false};
}
