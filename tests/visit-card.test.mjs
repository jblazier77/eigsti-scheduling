import test from 'node:test';
import assert from 'node:assert/strict';
import { chooseVisitHelper, visitCardChange, valuesFromVisit } from '../src/domain/visits.ts';
import { VisitSession } from '../src/server/visits.ts';
const id='33333333-3333-4333-8333-333333333333';
const helper='55555555-5555-4555-8555-555555555555';
const visit={id,work_item_id:id,start_date:'2026-10-23',end_date:'2026-10-23',slot:'day',start_time:null,end_time:null,coordinator_id:id,required_helpers:0,certainty:'tentative',participants:[{id,name:'Lead',duty:'leading'}]};
test('selecting helper from zero need adds a space in the SAME draft; Cancel baseline stays unchanged', () => {
  const values=valuesFromVisit(visit);
  const next=chooseVisitHelper(values,[],helper,true);
  assert.equal(next.values.required_helpers,1); assert.deepEqual(next.helpers,[helper]);
  assert.equal(values.required_helpers,0); assert.deepEqual(visit.participants,[{id,name:'Lead',duty:'leading'}]);
  assert.deepEqual(visitCardChange(visit,next.values,next.helpers),{patch:{required_helpers:1},helpers:[helper]});
  assert.deepEqual(visitCardChange(visit,valuesFromVisit(visit),[]),{patch:{},helpers:null});
});
test('combined draft omits unchanged roster and sends only changed dates without stale unrelated fields', () => {
  const values={...valuesFromVisit(visit),start_date:'2026-10-26',end_date:'2026-10-26'};
  assert.deepEqual(visitCardChange(visit,values,[]),{patch:{start_date:'2026-10-26',end_date:'2026-10-26'},helpers:null});
  assert.throws(()=>visitCardChange(visit,values,[helper,helper]));
});
test('combined transport sends one employee-authenticated RPC, retaining null versus empty roster',async()=>{
  const calls=[];
  const gateway=new VisitSession({url:'https://example.supabase.co',publishableKey:'sb_publishable_test',environment:'test'},'employee-token',async(url,options)=>{calls.push({url,body:JSON.parse(options.body),auth:options.headers.Authorization});return Response.json(visit);});
  await gateway.saveVisitCard(id,id,id,{required_helpers:1},[helper]);
  assert.equal(calls.length,1); assert.ok(calls[0].url.endsWith('/rpc/save_visit_card')); assert.equal(calls[0].auth,'Bearer employee-token');
  assert.deepEqual(calls[0].body,{p_work_id:id,p_visit_id:id,p_request_id:id,p_patch:{required_helpers:1},p_helpers:[helper]});
  await gateway.saveVisitCard(id,id,id,{certainty:'confirmed'},null); assert.equal(calls[1].body.p_helpers,null);
  await gateway.saveVisitCard(id,id,id,{},[]); assert.deepEqual(calls[2].body.p_helpers,[]);
});
