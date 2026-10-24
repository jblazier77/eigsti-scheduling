import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire,stripTypeScriptTypes} from 'node:module';
import {runInNewContext} from 'node:vm';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import * as access from '../src/domain/access.ts';
import * as work from '../src/domain/work.ts';
import * as visits from '../src/domain/visits.ts';
import * as planning from '../src/domain/planning-updates.ts';
import {WorkSession} from '../src/server/work.ts';
const require=createRequire(import.meta.url),swc=require('next/dist/build/swc');
const jobId='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',leadId='33333333-3333-4333-8333-333333333333',workId='dddddddd-dddd-4ddd-8ddd-dddddddddddd',requestId='abcdefab-cdef-4abc-8abc-000000000001';
const values={description:'Cabinets',responsible_lead:leadId};
const date={start_date:'2026-10-23',end_date:'2026-10-23',slot:'day',required_helpers:2};
const material={material_name:'Cabinets',material_status:'ordered',material_expected_on:'2020-01-01'};
const config={url:'https://synthetic-project.supabase.co',publishableKey:'sb_publishable_test',environment:'test'};

test('optional dates stay optional; date-only work uses its chosen lead and no exclusive time block',()=>{
 assert.equal(planning.validateOptionalPlan(null,{...values,responsible_lead:null}),null);
 const plan=planning.validateOptionalPlan(date,values);assert.equal(plan.slot,'day');assert.equal(plan.start_time,null);assert.equal(plan.end_time,null);assert.equal(plan.coordinator_id,leadId);assert.equal(plan.required_helpers,2);
});
test('invalid dated-work drafts fail before writes: no lead, weekends, reversed ranges and injected ownership',()=>{
 for(const [p,w] of [[date,{...values,responsible_lead:null}],[{...date,start_date:'2026-10-24',end_date:'2026-10-24'},values],[{...date,end_date:'2026-10-22'},values],[{...date,coordinator_id:jobId},values],[{...date,required_helpers:21},values]])assert.throws(()=>planning.validateOptionalPlan(p,w));
});
test('materials validate explicit availability and calendar dates without inferring stock from elapsed estimates',()=>{
 assert.deepEqual(planning.validateMaterial(material),material);
 assert.deepEqual(planning.validateMaterial({...material,material_status:'in_stock',material_expected_on:null}),{...material,material_status:'in_stock',material_expected_on:null});
 for(const patch of [{material_status:'invented'},{material_expected_on:'2026-02-30'},{material_status:'in_stock'},{material_name:''},{responsible_lead:leadId}])assert.throws(()=>planning.validateMaterial({...material,...patch}));
});
test('help warning counts only distinct helpers, not the coordinator; it clears when filled, overfilled or cancelled',()=>{
 const v={state:'planned',required_helpers:2,coordinator_id:leadId,participants:[{id:leadId,duty:'leading'},{id:'h1',duty:'helping'},{id:'h1',duty:'helping'}]};
 assert.equal(visits.helperDeficit(v),1);assert.equal(visits.helperDeficit({...v,participants:[]}),2);assert.equal(visits.helperDeficit({...v,participants:[...v.participants,{id:'h2',duty:'helping'}]}),0);assert.equal(visits.helperDeficit({...v,state:'cancelled'}),0);assert.equal(visits.helperDeficit({...v,required_helpers:0}),0);assert.equal(visits.helperDeficit({...v,participants:[{id:leadId,duty:'helping'}]}),2);
});
function actions({roles=['pm'],active=true,fail=false}={}){
 const calls=[],exports={};
 const gateway={createQuickWork:async(...args)=>{calls.push(['quick',...args]);if(fail)throw new access.AppError('connection_failed',503,'Unconfirmed.');return{id:workId};},createWorkWithPlan:async(...args)=>{calls.push(['create',...args]);if(fail)throw new access.AppError('connection_failed',503,'Unconfirmed.');return{id:workId};},saveMaterials:async(...args)=>{calls.push(['material',...args]);if(fail)throw new access.AppError('not_allowed',403,'Lead access changed.');return{id:workId,job_id:jobId};}};
 const dependencies={'next/cache':{revalidatePath:path=>calls.push(['refresh',path])},'../lib/work-session':{workSession:async()=>({actor:{id:leadId,roles,active},gateway})},'../domain/access.ts':access,'../domain/work.ts':work,'../domain/planning-updates.ts':planning};
 const compiled=stripTypeScriptTypes(readFileSync(new URL('../src/app/planning-update-actions.ts',import.meta.url),'utf8')).replace(/^import \{([^}]+)\} from '([^']+)';$/gm,'const {$1} = require(\'$2\');').replace(/export async function (\w+)/g,'exports.$1 = async function $1');
 runInNewContext(compiled,{exports,require:name=>{assert(name in dependencies,name);return dependencies[name];}});
 const form=new FormData();form.set('jobId',jobId);form.set('workId',workId);form.set('requestId',requestId);form.set('values',JSON.stringify(values));form.set('schedule',JSON.stringify(date));
 return {calls,form,...exports};
}
test('dated work uses one authenticated command and refreshes only after confirmed success',async()=>{
 const f=actions();assert.equal((await f.createPlannedWorkAction({},f.form)).jobId,jobId);assert.equal(f.calls[0][0],'create');assert.equal(f.calls[0][2],requestId);assert.deepEqual(f.calls[0][4],planning.validateOptionalPlan(date,values));assert.equal(f.calls.filter(c=>c[0]==='create').length,1);assert(f.calls.some(c=>c[1]==='/schedule'));
 const failed=actions({fail:true});const result=await failed.createPlannedWorkAction({},failed.form);assert.equal(result.uncertain,true);assert.equal(result.jobId,undefined);assert.equal(failed.calls.length,1);
 await failed.createPlannedWorkAction(result,failed.form);assert.deepEqual(failed.calls[0],failed.calls[1]);
});
test('helper, lead, admin-only, inactive and malformed dated-work attempts never reach the command',async()=>{
 for(const option of [{roles:['helper']},{roles:['lead']},{roles:['admin']},{active:false}]){const f=actions(option);assert.equal((await f.createPlannedWorkAction({},f.form)).jobId,undefined);assert.equal(f.calls.length,0);}
 const f=actions();f.form.set('schedule',JSON.stringify({...date,start_date:'2026-10-24'}));assert.equal((await f.createPlannedWorkAction({},f.form)).jobId,undefined);assert.equal(f.calls.length,0);
});
test('materials recheck roles, defer ownership to scoped RPC, and use returned job identity for invalidation',async()=>{
 for(const roles of [['pm'],['lead']]){const f=actions({roles});f.form.set('values',JSON.stringify(material));f.form.set('jobId','forged');const result=await f.saveMaterialAction({},f.form);assert.deepEqual(result.values,material);assert.deepEqual(f.calls[0],['material',workId,requestId,material]);assert(f.calls.some(c=>c[1]==='/jobs/'+jobId));assert(!f.calls.some(c=>c[1]==='/jobs/forged'));}
 for(const options of [{roles:['helper']},{roles:['admin']},{active:false},{roles:['lead'],fail:true}]){const f=actions(options);f.form.set('values',JSON.stringify(material));const result=await f.saveMaterialAction({},f.form);assert.equal(result.values,undefined);assert(!f.calls.some(c=>c[0]==='refresh'));}
});
test('new command transport retains employee identity, request key and atomic plan payload',async()=>{
 const calls=[];const gateway=new WorkSession(config,'employee-token',async(url,init)=>{calls.push({url:String(url),init});return Response.json({id:workId,job_id:jobId});});
 await gateway.createWorkWithPlan(jobId,requestId,values,planning.validateOptionalPlan(date,values));await gateway.saveMaterials(workId,requestId,material);
 assert(calls[0].url.endsWith('/rpc/create_job_work_with_plan'));assert.equal(JSON.parse(calls[0].init.body).p_request_id,requestId);assert.equal(JSON.parse(calls[1].init.body).p_values.material_expected_on,'2020-01-01');for(const c of calls){assert.equal(c.init.headers.Authorization,'Bearer employee-token');assert.equal(c.init.cache,'no-store');}
});
test('work overview falls back safely before the unapplied material columns exist, but does not mask access failures',async()=>{
 let count=0;const gateway=new WorkSession(config,'employee-token',async()=>++count===1?Response.json({code:'42703'},{status:400}):Response.json([{id:workId,readiness:'ready',waiting_until:null}]));assert.equal((await gateway.workStatus(jobId))[0].readiness,'ready');assert.equal(count,2);
 count=0;const denied=new WorkSession(config,'employee-token',async()=>{count++;return Response.json({code:'42501'},{status:403});});await assert.rejects(denied.workStatus(jobId),e=>e.code==='not_allowed');assert.equal(count,1);
});
function component(name,deps={}){const source=swc.transformSync(readFileSync(new URL('../src/app/components/'+name+'.tsx',import.meta.url),'utf8'),{filename:name+'.tsx',jsc:{parser:{syntax:'typescript',tsx:true},target:'es2022',transform:{react:{runtime:'automatic'}}},module:{type:'commonjs'}}).code;const exports={};runInNewContext(source,{exports,require:n=>deps[n]??(n==='./detail-icons'?{DetailIcon:()=>null}:require(n))});return exports;}
test('staffing icon has readable warning text and vanishes when the request is filled',()=>{
 const {StaffingWarning}=component('staffing-warning',{'../../domain/visits.ts':visits});const v={state:'planned',required_helpers:2,coordinator_id:leadId,participants:[]};const html=renderToStaticMarkup(createElement(StaffingWarning,{visit:v}));assert(html.includes('<svg'));assert(html.includes('2 helpers needed'));assert(html.includes('role="status"'));assert.equal(renderToStaticMarkup(createElement(StaffingWarning,{visit:{...v,required_helpers:0}})),'');
});
test('Add work offers an empty optional date; staffing editor has no Plan choice and preserves its legacy value',()=>{
 const {WorkForm}=component('work-form',{'next/navigation':{useRouter:()=>({})},'next/link':{default:()=>null},'../../domain/work.ts':work,'../../domain/planning-updates.ts':planning,'../work-actions':{},'../planning-update-actions':{}});
 const html=renderToStaticMarkup(createElement(WorkForm,{jobId,requestId,original:{description:'',responsible_lead:null},leads:[],inlineCreate:true,onDone:()=>{}}));assert(html.includes('Date (optional)'));assert(html.includes('name="schedule" value="null"'));assert(!html.includes('Return work'));assert(html.includes('Save work'));
 const {VisitCardEditor}=component('visit-card-editor',{'../../domain/visits.ts':visits,'../visit-actions':{}});const v={...planning.validateOptionalPlan(date,values),id:workId,work_item_id:workId,participants:[],state:'planned'};const card=renderToStaticMarkup(createElement(VisitCardEditor,{visit:v,leads:[{id:leadId,display_name:'Test lead'}],options:[],pm:true,requestId,onSaved:()=>{}}));assert(card.includes('Helpers needed'));assert(!card.includes('<label>Plan'));assert(!card.includes('Tentative</option>'));assert(card.includes('name="certainty" value="tentative"'));
});
test('material expected dates stay visible to readers with no write form',()=>{
 const {WorkMaterials}=component('work-materials',{'../../domain/planning-updates.ts':planning,'../../domain/visits.ts':visits,'../planning-update-actions':{}});const html=renderToStaticMarkup(createElement(WorkMaterials,{status:{id:workId,readiness:'waiting_date',waiting_until:material.material_expected_on,...material},canEdit:false}));assert(html.includes('Cabinets / Ordered / Expected'));assert(!html.includes('<form'));assert(!html.includes('In stock'));
});
test('planning bundle contains exact unapplied DDL/check bodies, rolls fixtures back, and guards duplicate application',()=>{
 const ddl=readFileSync(new URL('../database/migrations/0012_work_planning_and_materials.sql',import.meta.url),'utf8');const tests=readFileSync(new URL('../database/tests/0012_work_planning_and_materials.test.sql',import.meta.url),'utf8');const bundle=readFileSync(new URL('../database/batches/0012_work_planning_and_materials.sql',import.meta.url),'utf8');
 assert(bundle.includes(ddl.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'')));assert(bundle.includes(tests.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')));assert.equal((bundle.match(/^commit;$/gm)||[]).length,1);assert(bundle.indexOf('rollback to savepoint planning_fixture_checks')<bundle.indexOf('\ncommit;'));assert(bundle.includes('0012 may already be applied'));assert.equal((tests.match(/insert into pg_temp.eigsti_planning_results\(result\)/g)||[]).length,42);
});

test('live planning checks use authorized schedule RPCs without expanding direct visits-table privileges',()=>{
 const checks=readFileSync(new URL('../database/tests/0012_work_planning_and_materials.test.sql',import.meta.url),'utf8');
 const ddl=readFileSync(new URL('../database/migrations/0012_work_planning_and_materials.sql',import.meta.url),'utf8');
 assert(checks.includes('jsonb_to_recordset(public.list_job_visits('));
 assert(!/\bfrom\s+public\.visits\b/i.test(checks));
 assert(!/grant\s+select\s+on\s+(?:table\s+)?public\.visits\b/i.test(checks+'\n'+ddl));
 assert(checks.includes('language sql as $$'));assert(!/create function pg_temp\.planning_visits\([\s\S]*?security definer/i.test(checks));
});

test('one-window setup sends work, Tuesday, needed help and in-stock materials through one command',async()=>{
 const f=actions(),stock={material_name:'Windows',material_status:'in_stock',material_expected_on:null};
 const tuesday={...date,start_date:'2026-10-27',end_date:'2026-10-27',required_helpers:1};
 f.form.set('values',JSON.stringify({...values,description:'Install one window'}));f.form.set('schedule',JSON.stringify(tuesday));f.form.set('helpersNeeded','1');f.form.set('materials',JSON.stringify(stock));
 const result=await f.createQuickWorkAction({},f.form);assert.equal(result.jobId,jobId);assert.deepEqual(f.calls[0],['quick',jobId,requestId,{...values,description:'Install one window'},planning.validateOptionalPlan(tuesday,values),1,stock]);assert.equal(f.calls.filter(c=>c[0]==='quick').length,1);
});
test('quick-work retries retain the entire payload; unknown saves never report success or invalidate data',async()=>{
 const f=actions({fail:true});f.form.set('helpersNeeded','2');f.form.set('materials',JSON.stringify(material));const first=await f.createQuickWorkAction({},f.form);assert.equal(first.uncertain,true);assert.equal(first.jobId,undefined);await f.createQuickWorkAction(first,f.form);assert.deepEqual(f.calls[0],f.calls[1]);assert.equal(f.calls.length,2);
});
test('undated help persists in the command; malformed material/count and unauthorized requests never write',async()=>{
 const f=actions();f.form.set('schedule','null');f.form.set('helpersNeeded','2');f.form.set('materials',JSON.stringify(material));assert.equal((await f.createQuickWorkAction({},f.form)).jobId,jobId);assert.equal(f.calls[0][4],null);assert.equal(f.calls[0][5],2);
 for(const options of [{roles:['helper']},{roles:['lead']},{roles:['admin']},{active:false}]){const a=actions(options);a.form.set('helpersNeeded','2');a.form.set('materials','null');await a.createQuickWorkAction({},a.form);assert.equal(a.calls.length,0);}
 for(const [count,m] of [['21',material],['1',material],['2',{...material,material_status:'invented'}]]){const a=actions();a.form.set('helpersNeeded',count);a.form.set('materials',JSON.stringify(m));assert.equal((await a.createQuickWorkAction({},a.form)).jobId,undefined);assert.equal(a.calls.length,0);}
});
test('quick-work fields are visible even without a date and share one form and Save work action',()=>{
 const {WorkForm}=component('work-form',{'next/navigation':{useRouter:()=>({})},'next/link':{default:()=>null},'../../domain/work.ts':work,'../../domain/planning-updates.ts':planning,'../work-actions':{},'../planning-update-actions':{}});
 const html=renderToStaticMarkup(createElement(WorkForm,{jobId,requestId,original:{description:'',responsible_lead:null},leads:[],inlineCreate:true,onDone:()=>{}}));
 assert(html.includes('Helpers needed'));assert(html.includes('Material availability'));assert(html.includes('In stock</option>'));assert(html.includes('Date (optional)'));assert.equal((html.match(/<form /g)||[]).length,1);assert.equal((html.match(/Save work<\/button>/g)||[]).length,1);
});
test('quick-work guarded bundle preserves the applied 0012 and verifies transaction rollback and permission boundaries',()=>{
 const ddl=readFileSync(new URL('../database/migrations/0013_quick_work.sql',import.meta.url),'utf8'),checks=readFileSync(new URL('../database/tests/0013_quick_work.test.sql',import.meta.url),'utf8'),batch=readFileSync(new URL('../database/batches/0013_quick_work.sql',import.meta.url),'utf8');
 assert(batch.includes(ddl.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'')));assert(batch.includes(checks.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')));assert.equal((checks.match(/insert into pg_temp.eigsti_quick_results\(result\)/g)||[]).length,33);assert(!/\bfrom\s+public\.visits\b/i.test(checks));assert.equal((batch.match(/^commit;$/gm)||[]).length,1);assert(batch.indexOf('rollback to savepoint quick_work_fixture_checks')<batch.indexOf('\ncommit;'));assert(batch.includes('0013 may already be applied'));
});
