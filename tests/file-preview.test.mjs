import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import {runInNewContext} from 'node:vm';
import {FileSession} from '../src/server/files.ts';
import {AppError} from '../src/domain/access.ts';
import {fileUuid,canPreviewPhoto} from '../src/domain/files.ts';
const job='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',origin='https://synthetic.supabase.co';
const file={id,job_id:job,object_path:job+'/'+id,status:'ready',filename:'photo.jpg',mime_type:'image/jpeg',byte_size:3};
function fixture(patch={},options={}){
 const calls=[];
 const gateway=new FileSession({url:origin,publishableKey:'sb_publishable_test',environment:'test'},'employee-token',async(url,init)=>{
  calls.push({url:String(url),init});
  if(String(url).includes('/rest/v1/job_files'))return Response.json(options.absent?[]:[{...file,...patch}]);
  if(String(url).includes('?token='))return new Response(new Uint8Array([1,2,3]),{headers:{'content-type':options.mime??'image/jpeg'}});
  if(String(url).includes('/storage/v1/object/sign/'))return Response.json({signedURL:options.signed??'/object/sign/eigsti-job-files/'+file.object_path+'?token=preview-test'});
  throw new Error('Unexpected request');
 });return{gateway,calls};
}
test('photo preview checks scoped metadata and signs exactly its object, without sending employee credentials to image fetch',async()=>{
 const f=fixture(),result=await f.gateway.photoPreview(job,id);
 assert.equal(result.mime,'image/jpeg');assert.deepEqual([...new Uint8Array(await new Response(result.body).arrayBuffer())],[1,2,3]);
 assert.equal(f.calls.length,3);
 const params=new URL(f.calls[0].url).searchParams;assert.equal(params.get('job_id'),'eq.'+job);assert.equal(params.get('id'),'eq.'+id);
 assert.equal(new Headers(f.calls[0].init.headers).get('authorization'),'Bearer employee-token');
 assert.equal(new Headers(f.calls[1].init.headers).get('authorization'),'Bearer employee-token');assert.equal(JSON.parse(f.calls[1].init.body).expiresIn,60);
 assert.equal(new URL(f.calls[2].url).searchParams.has('download'),false);assert.equal(f.calls[2].init.headers,undefined);assert.equal(f.calls[2].init.credentials,'omit');assert.equal(f.calls[2].init.cache,'no-store');assert.equal(f.calls[2].init.redirect,'error');
});
test('unavailable, pending, archived, unsupported and forged-file metadata never obtain preview capability',async()=>{
 for(const patch of [{status:'pending'},{status:'archived'},{mime_type:'application/pdf'},{mime_type:'image/heic'},{mime_type:'image/svg+xml'},{object_path:'other/file'},{job_id:id},{id:job},{byte_size:20*1024*1024}]){
  const f=fixture(patch);await assert.rejects(f.gateway.photoPreview(job,id),{code:'file_unavailable'});assert.equal(f.calls.length,1);
 }
 const missing=fixture({},{absent:true});await assert.rejects(missing.gateway.photoPreview(job,id));assert.equal(missing.calls.length,1);
 assert.equal(canPreviewPhoto({status:'ready',mime_type:'image/png'}),true);
});
test('preview refuses a foreign signing response or a mismatched content type',async()=>{
 const foreign=fixture({},{signed:'https://other.invalid/image'});await assert.rejects(foreign.gateway.photoPreview(job,id),{code:'invalid_storage_url'});assert.equal(foreign.calls.length,2);
 const html=fixture({},{mime:'text/html'});await assert.rejects(html.gateway.photoPreview(job,id),{code:'file_unavailable'});
});
function handler({signedIn=true,actorError,previewError}={}){
 const exports={},calls=[];
 class Gateway{async getActor(){calls.push('actor');if(actorError)throw actorError;return{id:job,active:true,roles:['helper']};}async photoPreview(j,f){calls.push(['preview',j,f]);if(previewError)throw previewError;return{body:new ReadableStream({start(c){c.enqueue(new Uint8Array([1]));c.close();}}),mime:'image/jpeg'};}}
 const deps={
  '../../../../../../lib/supabase-server':{authClient:async()=>({auth:{getSession:async()=>({data:{session:signedIn?{access_token:'employee'}:null}})}})},
  '../../../../../../lib/config':{appConfig:()=>({})},'../../../../../../server/files.ts':{FileSession:Gateway},'../../../../../../domain/access.ts':{AppError},'../../../../../../domain/files.ts':{fileUuid}
 };
 const source=stripTypeScriptTypes(readFileSync(new URL('../src/app/jobs/[id]/files/[fileId]/preview/route.ts',import.meta.url),'utf8')).replace(/^import \{([^}]+)\} from '([^']+)';$/gm,'const {$1}=require(\'$2\');').replace('export const dynamic','const dynamic').replace('export async function GET','exports.GET=async function GET');
 runInNewContext(source,{exports,Response,ReadableStream,require:name=>deps[name]});
 return{calls,run:()=>exports.GET(null,{params:Promise.resolve({id:job,fileId:id})})};
}
test('preview route authorizes before reading and returns private inline bytes, not a signed redirect',async()=>{
 const f=handler(),response=await f.run();assert.equal(response.status,200);assert.equal(response.headers.get('content-type'),'image/jpeg');assert.equal(response.headers.get('cache-control'),'private, no-store');assert.equal(response.headers.get('content-disposition'),'inline');assert.equal(response.headers.get('x-content-type-options'),'nosniff');assert.equal(response.headers.has('location'),false);assert.deepEqual(f.calls,['actor',['preview',job,id]]);
});
test('anonymous, disabled and revoked preview requests never return image bytes or capabilities',async()=>{
 const anonymous=handler({signedIn:false});assert.equal((await anonymous.run()).status,401);assert.equal(anonymous.calls.length,0);
 const disabled=handler({actorError:new AppError('access_disabled',403,'Disabled')});assert.equal((await disabled.run()).status,403);assert.deepEqual(disabled.calls,['actor']);
 const revoked=handler({previewError:new AppError('file_unavailable',404,'Hidden')});const response=await revoked.run();assert.equal(response.status,404);assert.equal(response.headers.has('location'),false);
});
