import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import {runInNewContext} from 'node:vm';
import * as progress from '../src/domain/progress.ts';
import {AppError} from '../src/domain/access.ts';
const id='33333333-3333-4333-8333-333333333333';
function fixture(role='lead',failure){
 const calls=[],exports={};const deps={
  'next/cache':{revalidatePath:path=>calls.push(['refresh',path])},
  '../lib/visit-session':{visitSession:async()=>({actor:{id,active:true,roles:[role]},gateway:{progress:async input=>{calls.push(['command',input]);if(failure)throw new AppError(failure,409,'Not confirmed');return{job_id:id,work_id:id,result_id:id,visit:null};}}})},
  '../domain/progress.ts':progress,'../domain/access.ts':{AppError}
 };
 const source=stripTypeScriptTypes(readFileSync(new URL('../src/app/progress-actions.ts',import.meta.url),'utf8')).replace(/^import \{([^}]+)\} from '([^']+)';$/gm,'const {$1} = require(\'$2\');').replace(/export async function (\w+)/g,'exports.$1 = async function $1');
 runInNewContext(source,{exports,require:name=>deps[name]});
 const f=new FormData();for(const[k,v]of Object.entries({command:'finish_visit',workId:id,visitId:id,requestId:id,note:'',dueDate:''}))f.set(k,v);
 return{calls,form:f,run:()=>exports.workProgressAction({message:''},f)};
}
test('progress action issues one command and refreshes job, schedule and queue only on confirmation',async()=>{
 const f=fixture();assert.equal((await f.run()).saved,true);
 assert.deepEqual(f.calls.map(c=>c[0]),['command','refresh','refresh','refresh','refresh']);
 const helper=fixture('helper');assert.equal((await helper.run()).saved,undefined);assert.equal(helper.calls.length,0);
 const invalid=fixture();invalid.form.set('needsReturn','yes');assert.equal((await invalid.run()).saved,undefined);assert.equal(invalid.calls.length,0);
});
test('progress conflict is definite, interrupted response retains same entire retry without success refresh',async()=>{
 for(const code of ['progress_conflict','connection_failed']){const f=fixture('pm',code);const result=await f.run();assert.equal(result.saved,undefined);assert.equal(result.uncertain,code==='connection_failed');assert.equal(f.calls.length,1);await f.run();assert.deepEqual(f.calls[0],f.calls[1]);}
});
