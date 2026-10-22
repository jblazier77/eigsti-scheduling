import test from 'node:test';
import assert from 'node:assert/strict';
import {progressInput} from '../src/domain/progress.ts';
import {VisitSession} from '../src/server/visits.ts';
const id='33333333-3333-4333-8333-333333333333';
const actor={id,active:true,roles:['lead']};
function form(command='finish_visit'){const f=new FormData();for(const[k,v]of Object.entries({command,workId:id,visitId:command==='finish_visit'?id:'',requestId:id,note:'',dueDate:''}))f.set(k,v);return f;}
test('finishing scheduled entry requires no narrative or date; return needs only short remaining note',()=>{
 const f=form();assert.deepEqual(progressInput(actor,f).values,{note:'',due_date:null,needs_return:false});
 f.set('needsReturn','yes');assert.throws(()=>progressInput(actor,f));f.set('note','  Install missing trim  ');
 assert.deepEqual(progressInput(actor,f).values,{note:'Install missing trim',due_date:null,needs_return:true});
 f.set('dueDate','2026-02-30');assert.throws(()=>progressInput(actor,f));
});
test('return reopening is explicit; finish/portion/resolve commands remain separate and immutable',()=>{
 const f=form('record_return');f.set('note','Replace trim');f.set('reopen','yes');
 assert.deepEqual(progressInput(actor,f).values,{note:'Replace trim',due_date:null,reopen:true});
 assert.deepEqual(progressInput(actor,form('complete_work')).values,{});
 assert.equal(progressInput(actor,form('reopen_work')).command,'reopen_work');
 const helper={...actor,roles:['helper']};assert.throws(()=>progressInput(helper,f));assert.throws(()=>progressInput({...actor,active:false},f));
 f.set('command','close_job');assert.throws(()=>progressInput(actor,f));
});
test('progress transport preserves parent IDs and stable retry identity in one atomic RPC',async()=>{
 const calls=[];const gateway=new VisitSession({url:'https://example.supabase.co',publishableKey:'sb_publishable_test',environment:'test'},'employee-token',async(url,options)=>{calls.push({url,body:JSON.parse(options.body),options});return Response.json({job_id:id,work_id:id,result_id:id,visit:null});});
 const input=progressInput(actor,form());await gateway.progress(input);await gateway.progress(input);
 assert.equal(calls.length,2);assert.deepEqual(calls[0].body,calls[1].body);
 assert.deepEqual(calls[0].body,{p_work_id:id,p_visit_id:id,p_follow_up_id:null,p_request_id:id,p_command:'finish_visit',p_values:{note:'',due_date:null,needs_return:false}});
 assert.equal(calls[0].options.headers.Authorization,'Bearer employee-token');assert.equal(calls[0].options.cache,'no-store');
});
