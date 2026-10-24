import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {groupJobWork} from '../src/domain/job-work-layout.ts';
import {dateLabel} from '../src/domain/visits.ts';
import {materialLabels} from '../src/domain/planning-updates.ts';
const require=createRequire(import.meta.url),swc=require('next/dist/build/swc');
const lead='lead',helper='helper';
const portion=(id,owner,extra={})=>({id,job_id:'job',description:id,responsible_lead:owner,lead_name:owner,completion:'open',remaining_note:'',planned_count:0,returns:[],...extra});
const visit=(id,work,extra={})=>({id,work_item_id:work,state:'planned',start_date:'2026-10-23',coordinator_id:'other',participants:[],...extra});
test('a lead sees owned work and current crew assignments first without hiding other shared work',()=>{
 const work=[portion('own',lead),portion('helping','other'),portion('shared','other')],visits=[visit('v','helping',{participants:[{id:lead,duty:'helping'}]})];
 const result=groupJobWork({id:lead,active:true,roles:['lead']},work,visits);
 assert.deepEqual(result.primary.map(w=>w.id),['own','helping']);assert.deepEqual(result.other.map(w=>w.id),['shared']);
 assert.equal(result.byWork.get('helping').length,1);assert.deepEqual(work.map(w=>w.id),['own','helping','shared']);
});
test('helper priority uses planned participation, not old completed or cancelled staffing',()=>{
 const work=[portion('active',lead),portion('old',lead),portion('cancelled',lead)];
 const visits=[visit('a','active',{participants:[{id:helper}]}),visit('b','old',{state:'completed',participants:[{id:helper}]}),visit('c','cancelled',{state:'cancelled',participants:[{id:helper}]})];
 const result=groupJobWork({id:helper,active:true,roles:['helper']},work,visits);
 assert.deepEqual(result.primary.map(w=>w.id),['active']);assert.equal(result.other.length,2);
});
test('unfinished returns/plans remain active even if portion completion data is inconsistent',()=>{
 const work=[portion('done',lead,{completion:'completed'}),portion('return',lead,{completion:'completed',returns:[{state:'open'}]}),portion('plan',lead,{completion:'completed'})];
 const result=groupJobWork({id:'pm',active:true,roles:['pm']},work,[visit('v','plan')]);
 assert.deepEqual(result.primary.map(w=>w.id),['return','plan']);assert.deepEqual(result.completed.map(w=>w.id),['done']);
});
test('PM sees every active portion; historical visits remain linked and chronologically ordered',()=>{
 const result=groupJobWork({id:'pm',active:true,roles:['pm']},[portion('a',lead),portion('b','other')],[visit('late','a',{start_date:'2026-10-26'}),visit('early','a',{state:'completed'})]);
 assert.equal(result.primary.length,2);assert.equal(result.other.length,0);assert.deepEqual(result.byWork.get('a').map(v=>v.id),['early','late']);
});

async function rendered(role,isOpen=true){
 const actor={id:role==='helper'?helper:role==='lead'?lead:'pm',active:true,roles:[role]};
 const work=[portion('Cabinets',lead,{remaining_note:'Fit return trim',planned_count:1,returns:[{id:'return',note:'Fit return trim',state:'open',owner_name:lead,due_date:'2026-10-26',planned_count:0}]}),portion('Other trade','other')];
 const visits=[visit('appointment','Cabinets',{coordinator_id:lead,participants:[{id:helper,duty:'helping'}]}),visit('history','Cabinets',{state:'completed'})];
 const reads=[];const gateway={jobProgress:async()=>work,jobVisits:async()=>visits,listWork:async()=>work,workStatus:async()=>[{id:'Cabinets',readiness:'waiting_unknown',waiting_until:null}],listLeads:async()=>{reads.push('leads');return[];}};
 const stub=(name)=>(props)=>createElement('div',{'data-component':name,'data-editable':props.editable,'data-command':props.command,'data-disabled':props.disabled,'data-visit':props.visit?.id},name);
 const dependencies={
  'node:crypto':{randomUUID:()=> 'request'},'../../lib/visit-session':{visitSession:async()=>({actor,gateway})},
  '../../domain/job-work-layout.ts':{groupJobWork},'../../domain/visits.ts':{dateLabel},
  '../../domain/planning-updates.ts':{materialLabels},'./work-materials':{WorkMaterials:()=>null},
  './inline-visit':{InlineVisit:stub('InlineVisit')},'./visit-editor':{VisitEditor:stub('VisitEditor')},
  './work-card-editor':{WorkCardEditor:stub('WorkCardEditor')},'./work-form':{InlineNewWork:stub('InlineNewWork')}
 };
 const toolsSource=swc.transformSync(readFileSync(new URL('../src/app/components/work-tools.tsx',import.meta.url),'utf8'),{filename:'work-tools.tsx',jsc:{parser:{syntax:'typescript',tsx:true},target:'es2022',transform:{react:{runtime:'automatic'}}},module:{type:'commonjs'}}).code;
 const toolExports={};runInNewContext(toolsSource,{exports:toolExports,require:name=>name==='./detail-icons'?{DetailIcon:()=>null}:dependencies[name]??require(name)});
 dependencies['./work-tools']=toolExports;
 const source=swc.transformSync(readFileSync(new URL('../src/app/components/job-workspace.tsx',import.meta.url),'utf8'),{filename:'job-workspace.tsx',jsc:{parser:{syntax:'typescript',tsx:true},target:'es2022',transform:{react:{runtime:'automatic'}}},module:{type:'commonjs'}}).code;
 const exports={};runInNewContext(source,{exports,require:name=>dependencies[name]??require(name)});
 const element=await exports.JobWorkspace({jobId:'job',isOpen,children:createElement('p',null,'Support details')});
 return{html:renderToStaticMarkup(element),reads};
}
test('combined helper view is read-only, retains its assignment, and does not load the lead directory',async()=>{
 const {html,reads}=await rendered('helper');assert.ok(html.includes('My work'));assert.ok(html.includes('Fit return trim'));assert.ok(html.includes('Other project work'));
 assert.ok(!html.includes('data-command='));assert.ok(!html.includes('WorkCardEditor'));assert.ok(!html.includes('VisitEditor'));assert.ok(!html.includes('data-editable="true"'));assert.equal(reads.length,0);
 assert.ok(html.indexOf('Support details')<html.indexOf('Work history'));
});
test('PM planning controls have no completion or return check-offs and show history only once',async()=>{
 const {html,reads}=await rendered('pm');assert.ok(html.includes('Project work'));assert.ok(html.includes('aria-label="Edit work and leads"'));assert.ok(html.includes('Add work'));assert.ok(!html.includes('WorkCardEditor'));assert.ok(!html.includes('InlineNewWork'));assert.equal(reads.length,1);
 for(const command of ['finish_visit','complete_work','resolve_return','reopen_work'])assert.ok(!html.includes('data-command="'+command+'"'));
 assert.ok(!html.includes('Complete this work'));assert.ok(!html.includes('Mark return handled'));assert.ok(!html.includes('data-command='));assert.ok(!html.includes('Add return work'));assert.ok(!html.includes('Plan return'));assert.ok(!html.includes('Handled returns'));assert.ok(html.includes('Waiting'));assert.ok(!html.includes('>Ready<'));
 assert.equal((html.match(/data-visit="appointment"/g)||[]).length,1);assert.equal((html.match(/data-visit="history"/g)||[]).length,1);
 assert.equal((html.match(/Fit return trim/g)||[]).length,1);assert.ok(html.includes('Target: Mon, Oct 26'));assert.ok(!html.includes('Return work'));
});
test('closed job view has no mutation controls or directory lookup',async()=>{
 const {html,reads}=await rendered('pm',false);assert.ok(!html.includes('data-command='));assert.ok(!html.includes('WorkCardEditor'));assert.ok(!html.includes('InlineNewWork'));assert.ok(!html.includes('data-editable="true"'));assert.equal(reads.length,0);
});

test('compact scheduled work keeps dates, crew and warnings visible, with no mutation controls for readers',async()=>{
 const {slotLabel}=await import('../src/domain/visits.ts');
 const source=swc.transformSync(readFileSync(new URL('../src/app/components/inline-visit.tsx',import.meta.url),'utf8'),{filename:'inline-visit.tsx',jsc:{parser:{syntax:'typescript',tsx:true},target:'es2022',transform:{react:{runtime:'automatic'}}},module:{type:'commonjs'}}).code;
 const dependencies={'../../domain/visits.ts':{dateLabel,slotLabel},'../visit-editor-actions':{loadVisitEditorAction:()=>{throw new Error('Must not load until editing');}},'./visit-editor':{CancelVisit:()=>null},'./visit-card-editor':{VisitCardEditor:()=>null},'./detail-icons':{DetailIcon:()=>null},'./staffing-warning':{StaffingWarning:()=>null}};
 const exports={};runInNewContext(source,{exports,require:name=>dependencies[name]??require(name)});
 const v={...visit('v','w'),description:'Cabinets',end_date:'2026-10-23',slot:'day',certainty:'tentative',required_helpers:2,day_conflicts:1,participants:[{id:helper,name:'Test helper',duty:'helping'}]};
 for(const compact of [true,false])for(const editable of [true,false]){
  const html=renderToStaticMarkup(createElement(exports.InlineVisit,{visit:v,editable,compact,hideWorkTitle:true}));
  assert(html.includes('Fri, Oct 23'));assert(html.includes('No time set'));assert(html.includes('Test helper'));assert(html.includes('1 helper space to fill'));assert(html.includes('Other plans share this day'));
  assert.equal(html.includes('aria-label="Edit dates and crew: Cabinets"'),editable);
  assert.equal(html.includes('Edit plan &amp; crew'),false);
  assert(!html.includes('Finish'));assert(!html.includes('finish_visit'));
  assert(!html.includes('<h3>Cabinets</h3>'));
 }
});


test('scheduling uses Save work and a normal planning command, with no return-work selector',async()=>{
 const visits=await import('../src/domain/visits.ts');
 const source=swc.transformSync(readFileSync(new URL('../src/app/components/visit-editor.tsx',import.meta.url),'utf8'),{filename:'visit-editor.tsx',jsc:{parser:{syntax:'typescript',tsx:true},target:'es2022',transform:{react:{runtime:'automatic'}}},module:{type:'commonjs'}}).code;
 const dependencies={'../../domain/visits.ts':visits,'../visit-actions':{saveVisitAction:()=>{throw new Error('No action during render');}}};
 const exports={};runInNewContext(source,{exports,require:name=>dependencies[name]??require(name)});
 const html=renderToStaticMarkup(createElement(exports.VisitEditor,{work:[{id:'work',description:'Install cabinets'}],leads:[{id:'lead',display_name:'Test lead'}],pm:true,actorId:'pm',requestId:'stable-request'}));
 assert(html.includes('Save work</button>'));assert(!html.includes('Save visit'));assert(html.includes('name="operation" value="save"'));assert(!html.includes('followUpId'));assert(html.includes('No time set'));assert(html.includes('name="requestId" value="stable-request"'));
});
