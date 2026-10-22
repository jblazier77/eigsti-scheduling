import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {trades,classificationPatch,classificationChanges,subcontractorValues} from '../src/domain/job-classification.ts';
import {listJobs} from '../src/domain/jobs.ts';
import {SupabaseSession} from '../src/server/supabase.ts';
const id='11111111-1111-4111-8111-111111111111';

test('independent job labels accept only booleans and canonical known scopes, with no scheduling or ownership fields',()=>{
 assert.deepEqual(classificationPatch({filler:true,rain_day:true,whole_house:false,trades:['plumbing','electrical']}),{filler:true,rain_day:true,whole_house:false,trades:['electrical','plumbing']});
 for(const value of [{rain_day:'true'},{trades:['roofing','roofing']},{trades:[null]},{trades:['unknown']},{responsible_pm:id},{readiness:'ready'},null,[]])assert.throws(()=>classificationPatch(value));
 const original={rain_day:true,filler:true,whole_house:false,trades:['plumbing']};
 assert.deepEqual(classificationChanges(original,{...original,rain_day:false}),{rain_day:false});
 assert.deepEqual(classificationChanges(original,{...original,whole_house:true}),{whole_house:true});
});
test('directory requires only a name; trades do not require a project or appointment',()=>{
 assert.deepEqual(subcontractorValues({name:'  Repair company ',phone:'',email:'',trades:['general']}),{name:'Repair company',phone:'',email:'',trades:['general']});
 for(const value of [{name:'',phone:'',email:'',trades:[]},{name:'Company',phone:'',email:'broken',trades:[]},{name:'Company',phone:'',email:'',trades:['invented']},{name:'Company',phone:'',email:'',trades:[],roles:['admin']}])assert.throws(()=>subcontractorValues(value));
 const sql=readFileSync(new URL('../database/migrations/0011_job_tags_and_trades.sql',import.meta.url),'utf8');
 const sqlIds=sql.match(/p_ids <@ array\[([^\]]+)\]/)[1].match(/'([^']+)'/g).map(s=>s.slice(1,-1));
 assert.deepEqual(sqlIds,trades.map(t=>t.id));
});
test('job discovery sends filters before pagination and preserves ownership restrictions',async()=>{
 const calls=[],gateway={listJobs:async q=>{calls.push(q);return[];}};
 await listJobs({id,active:true,roles:['pm']},{kind:'both',offset:'50'},gateway);
 assert.deepEqual(calls[0],{responsiblePm:id,limit:50,offset:50,rainDay:true,filler:true});
 await listJobs({id,active:true,roles:['lead']},{kind:'filler'},gateway);
 assert.equal(calls[1].responsiblePm,undefined);assert.equal(calls[1].filler,true);
 await assert.rejects(listJobs({id,active:true,roles:['helper']},{scope:'all',kind:'filler'},gateway));
 await assert.rejects(listJobs({id,active:true,roles:['pm']},{kind:'unknown'},gateway));
 assert.equal(calls.length,2);
});
test('metadata transport uses employee identity and one atomic creation endpoint; tag reads batch and deduplicate',async()=>{
 const calls=[];
 const gateway=new SupabaseSession({url:'https://example.supabase.co',publishableKey:'public-test',environment:'test'},'employee-token',async(url,init)=>{
  calls.push({url,init});return Response.json(url.includes('/rpc/')?{id}:[]);
 });
 await gateway.createClassifiedJob({requestId:id,customer:'Customer',phone:'3095550101',phoneAction:'+13095550101',address:'Fictional'}, {filler:true});
 assert.equal(calls.length,1);assert.ok(calls[0].url.endsWith('/rpc/create_classified_job'));
 assert.equal(JSON.parse(calls[0].init.body).p_classification.filler,true);
 await gateway.listJobs({limit:50,offset:50,rainDay:true,filler:true});
 const url=new URL(calls[1].url);assert.equal(url.searchParams.get('rain_day'),'eq.true');assert.equal(url.searchParams.get('filler'),'eq.true');assert.equal(url.searchParams.get('lifecycle'),'eq.open');assert.equal(url.searchParams.get('offset'),'50');
 await gateway.jobMarkers([id,id]);assert.equal(calls.length,3);
 await gateway.jobMarkers([]);assert.equal(calls.length,3);
 await gateway.saveClassification(id,id,{rain_day:false});assert.deepEqual(JSON.parse(calls.at(-1).init.body),{p_job_id:id,p_request_id:id,p_patch:{rain_day:false}});
 await gateway.listSubcontractors('plumbing');assert.equal(new URL(calls.at(-1).url).searchParams.get('trades'),'cs.{plumbing}');
 for(const call of calls){assert.equal(call.init.headers.Authorization,'Bearer employee-token');assert.equal(call.init.cache,'no-store');}
});
