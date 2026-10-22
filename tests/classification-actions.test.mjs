import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import {runInNewContext} from 'node:vm';
import * as domain from '../src/domain/job-classification.ts';
import * as jobs from '../src/domain/jobs.ts';
import * as access from '../src/domain/access.ts';
const id='11111111-1111-4111-8111-111111111111';
function fixture(role='pm',failure){
 const calls=[],exports={},gateway={saveClassification:async(...args)=>{calls.push(['tag',...args]);if(failure)throw new access.AppError(failure,503,'Not confirmed');return{id};},saveSubcontractor:async(...args)=>{calls.push(['directory',...args]);return{id};}};
 const dependencies={'next/cache':{revalidatePath:path=>calls.push(['refresh',path])},'../lib/session':{requireSession:async()=>({actor:{id,active:true,roles:[role]},gateway})},'../domain/access.ts':access,'../domain/job-classification.ts':domain,'../domain/jobs.ts':jobs};
 const source=stripTypeScriptTypes(readFileSync(new URL('../src/app/classification-actions.ts',import.meta.url),'utf8')).replace(/^import \{([^}]+)\} from '([^']+)';$/gm,'const {$1}=require(\'$2\');').replace(/export async function (\w+)/g,'exports.$1=async function $1');
 runInNewContext(source,{exports,require:name=>dependencies[name]});
 const form=new FormData();form.set('jobId',id);form.set('requestId',id);form.set('patch','{"rain_day":true}');
 return{calls,form,tag:()=>exports.saveClassificationAction({message:''},form),directory:()=>exports.saveSubcontractorAction({message:''},form)};
}
test('PM classification action saves once then refreshes related views; lead/helper/admin forgery denied',async()=>{
 const f=fixture();assert.equal((await f.tag()).saved,true);assert.deepEqual(f.calls.map(c=>c[0]),['tag','refresh','refresh','refresh','refresh']);
 assert.deepEqual(JSON.parse(JSON.stringify(f.calls[0])),['tag',id,id,{rain_day:true}]);
 for(const role of ['lead','helper','admin']){const denied=fixture(role);assert.equal((await denied.tag()).saved,undefined);assert.equal(denied.calls.length,0);}
 const invalid=fixture();invalid.form.set('patch','{"responsible_pm":null}');assert.equal((await invalid.tag()).saved,undefined);assert.equal(invalid.calls.length,0);
});
test('unconfirmed tag save refreshes nothing and retains exact retry identity',async()=>{
 const f=fixture('pm','connection_failed');assert.equal((await f.tag()).uncertain,true);await f.tag();assert.equal(f.calls.length,2);assert.deepEqual(f.calls[0],f.calls[1]);
});
test('directory edits transmit only changed fields and never accept lead/helper management',async()=>{
 const f=fixture('admin');f.form.set('id',id);f.form.set('patch',JSON.stringify({name:'Company',phone:'3095550101',email:'',trades:['plumbing']}));f.form.append('changed','trades');
 assert.equal((await f.directory()).saved,true);assert.deepEqual(JSON.parse(JSON.stringify(f.calls[0])),['directory',id,id,{trades:['plumbing']}]);
 for(const role of ['lead','helper']){const denied=fixture(role);assert.equal((await denied.directory()).saved,undefined);assert.equal(denied.calls.length,0);}
 const invalid=fixture();invalid.form.set('patch','{"archive":true,"name":"forged"}');assert.equal((await invalid.directory()).saved,undefined);assert.equal(invalid.calls.length,0);
});

function creation(role='pm',failure){
 const exports={},calls=[];
 class Gateway {async getActor(){return{id,active:true,roles:[role]};}async createClassifiedJob(input,tags){calls.push(['create',input,tags]);if(failure)throw new access.AppError(failure,503,'Not confirmed');return{id};}}
 const dependencies={
  'next/navigation':{},'next/cache':{revalidatePath:p=>calls.push(['refresh',p])},'next/headers':{},
  '../lib/supabase-server':{authClient:async()=>({auth:{getSession:async()=>({data:{session:{access_token:'employee'}}})}})},
  '../lib/config':{appConfig:()=>({})},'../server/supabase.ts':{SupabaseSession:Gateway},'../domain/jobs.ts':jobs,
  '../domain/job-classification.ts':domain,'../domain/job-edits.ts':{},'../domain/access.ts':access,'../server/sign-out.ts':{}
 };
 const source=stripTypeScriptTypes(readFileSync(new URL('../src/app/actions.ts',import.meta.url),'utf8')).replace(/^import \{([^}]+)\} from '([^']+)';$/gm,'const {$1}=require(\'$2\');').replace(/export async function (\w+)/g,'exports.$1=async function $1');
 runInNewContext(source,{exports,require:name=>dependencies[name]});
 const form=new FormData();for(const[k,v]of Object.entries({requestId:id,customer:'Customer',phone:'3095550101',address:'Fictional Lane',classification:'{"filler":true,"rain_day":true}'}))form.set(k,v);
 return{form,calls,run:()=>exports.createJobAction({message:''},form)};
}
test('new filler form creates job/default work/tags through one command and validates before transport',async()=>{
 const f=creation();assert.equal((await f.run()).jobId,id);assert.deepEqual(f.calls.map(c=>c[0]),['create','refresh']);
 assert.deepEqual(JSON.parse(JSON.stringify(f.calls[0][2])),{filler:true,rain_day:true});
 for(const role of ['lead','helper','admin']){const denied=creation(role);assert.equal((await denied.run()).jobId,undefined);assert.equal(denied.calls.length,0);}
 const invalid=creation();invalid.form.set('classification','{"trades":["invented"]}');assert.equal((await invalid.run()).uncertain,false);assert.equal(invalid.calls.length,0);
});
test('interrupted classified creation retains the original request and never reports navigation success',async()=>{
 const f=creation('pm','connection_failed');assert.equal((await f.run()).uncertain,true);assert.equal((await f.run()).jobId,undefined);assert.equal(f.calls.length,2);assert.deepEqual(f.calls[0],f.calls[1]);
});
