import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {onboardEmployee,onboardingInput} from '../src/server/employee-onboarding.ts';
const config={url:'https://synthetic-project.supabase.co',publishableKey:'sb_publishable_test',environment:'test'},key='sb_secret_synthetic_only';
const actor={id:'77777777-7777-4777-8777-777777777777',active:true,roles:['admin']};
function form(){const f=new FormData();for(const [k,v] of Object.entries({name:'Test helper',email:'Helper@example.invalid',password:'private temporary password',requestId:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',roles:'helper'}))f.append(k,v);return f;}
function fixture({missing=false,failEnroll=false,lost=false,existing=false}={}){
 let user=null,creates=0,enrolls=0,reads=0;const requests=[];
 const transport=async(url,init={})=>{
  const path=new URL(String(url)).pathname,body=init.body?JSON.parse(init.body):{};requests.push({path,method:init.method,body});
  if(path.endsWith('/employee_onboarding_ready'))return missing?Response.json({message:'missing'},{status:404}):Response.json(true);
  if(path.endsWith('/enroll_employee_account')){enrolls++;return failEnroll?Response.json({message:'private SQL error'},{status:500}):Response.json({id:user.id,display_name:body.p_values.display_name,roles:body.p_values.roles,active:true});}
  if(path==='/auth/v1/admin/users'&&init.method==='POST'){
   creates++;if(existing)return Response.json({code:'email_exists',msg:'private detail'},{status:422,headers:{'x-supabase-api-version':'2024-01-01'}});
   user={id:body.id,email:body.email,app_metadata:body.app_metadata,aud:'authenticated',created_at:'2026-10-26T00:00:00Z'};
   return lost?Response.json({code:'unexpected_failure',msg:'private detail'},{status:500}):Response.json(user);
  }
  if(path.startsWith('/auth/v1/admin/users/')){reads++;return user?Response.json(user):Response.json({code:'user_not_found',msg:'User not found'},{status:404});}
  throw new Error('Unexpected path');
 };
 return {run:(input=onboardingInput(form()),authorize=async()=>actor)=>onboardEmployee(config,key,input,authorize,transport),requests,get creates(){return creates},get enrolls(){return enrolls},get user(){return user}};
}
test('onboarding validates email, helper default payload, password bytes and roles',()=>{const f=form();assert.equal(onboardingInput(f).email,'helper@example.invalid');f.set('password','tiny');assert.throws(()=>onboardingInput(f));f.set('password','é'.repeat(37));assert.throws(()=>onboardingInput(f));f.set('password','valid test password');f.set('roles','superuser');assert.throws(()=>onboardingInput(f));});
test('only active admins may create accounts and missing SQL fails before Auth write',async()=>{const f=fixture();await assert.rejects(f.run(undefined,async()=>({...actor,roles:['pm']})));assert.equal(f.requests.length,0);const m=fixture({missing:true});await assert.rejects(m.run(),/not ready/);assert.equal(m.creates,0);});
test('create helper and identical retry creates one Auth account without password reset',async()=>{const f=fixture();const a=await f.run(),b=await f.run();assert.equal(a.id,b.id);assert.equal(f.creates,1);assert.equal(f.enrolls,2);assert(!f.requests.some(r=>r.method==='PUT'||r.method==='DELETE'));assert(!f.requests.filter(r=>r.path.includes('/rpc/')).some(r=>JSON.stringify(r.body).includes('password')));});
test('lost Auth create response recovers only the deterministic matching account',async()=>{const f=fixture({lost:true});await f.run();assert.equal(f.creates,1);assert.equal(f.enrolls,1);});
test('profile failure leaves recoverable account; existing email is never adopted',async()=>{const f=fixture({failEnroll:true});await assert.rejects(f.run(),/unchanged form/);assert(f.user);assert(!f.requests.some(r=>r.method==='DELETE'));const g=fixture({existing:true});await assert.rejects(g.run(),/already has an account/);assert.equal(g.enrolls,0);});
test('changed retry cannot change roles or password on existing account',async()=>{const f=fixture();await f.run();const changed=onboardingInput(form());changed.values.roles=['admin'];await assert.rejects(f.run(changed),/request changed/);assert.equal(f.enrolls,1);assert.equal(f.creates,1);});
test('revoked admin is checked again before account creation and enrollment',async()=>{const f=fixture();let checks=0;await assert.rejects(f.run(undefined,async()=>({...actor,active:++checks<2})));assert.equal(f.creates,0);const g=fixture();checks=0;await assert.rejects(g.run(undefined,async()=>({...actor,active:++checks<3})));assert.equal(g.creates,1);assert.equal(g.enrolls,0);});
test('0020 guarded bundle uses server-only enrollment grants and rolls fixtures back',()=>{const read=p=>readFileSync(p,'utf8'),ddl=read('database/migrations/0020_employee_accounts.sql'),checks=read('database/tests/0020_employee_accounts.test.sql'),batch=read('database/batches/0020_employee_accounts.sql');assert(batch.includes(ddl.replace(/^begin;\r?\n/m,'').replace(/commit;\s*$/,'')));assert(batch.includes(checks.replace(/^begin;\r?\n/m,'').replace(/rollback;\s*$/,'')));assert.equal((checks.match(/insert into pg_temp.eigsti_account_results values/g)||[]).length,12);assert.equal((batch.match(/^commit;$/gm)||[]).length,1);assert(batch.indexOf('rollback to savepoint account_checks')<batch.indexOf('\ncommit;'));assert(ddl.includes('to service_role'));assert(!ddl.includes('to authenticated'));assert(!ddl.includes('encrypted_password'));});

test('onboarding Server Action denies forged roles before provisioning and returns no credentials',async()=>{
 const {createRequire}=await import('node:module'),{runInNewContext}=await import('node:vm');const require=createRequire(import.meta.url),swc=require('next/dist/build/swc');
 const {AppError}=await import('../src/domain/access.ts'),employees=await import('../src/domain/employees.ts');
 const source=readFileSync('src/app/employee-create-actions.ts','utf8');
 for(const role of ['helper','lead','pm','admin']){
  const calls=[];const deps={'next/cache':{revalidatePath:()=>calls.push('refresh')},'../lib/session':{currentSession:async()=>({actor:{...actor,roles:[role]},gateway:{getActor:async()=>({...actor,roles:[role]})}})},'../lib/config':{appConfig:()=>config},'../domain/access.ts':{AppError},'../domain/employees.ts':employees,'../server/employee-onboarding.ts':{onboardingInput,onboardEmployee:async(_c,_k,_i,authorize)=>{await authorize();calls.push('create');return {id:'test'};}}};
  const {code}=swc.transformSync(source,{filename:'actions.ts',jsc:{parser:{syntax:'typescript'},target:'es2022'},module:{type:'commonjs'}});const exports={};runInNewContext(code,{exports,require:p=>deps[p],process:{env:{SUPABASE_ADMIN_KEY:'SECRET_TEST_KEY_123'}}});
  const result=await exports.createEmployeeAction({},form());assert.equal(calls.includes('create'),role==='admin');assert(!JSON.stringify(result).includes('SECRET_TEST_KEY_123'));assert(!JSON.stringify(result).includes('private temporary password'));assert.deepEqual(Object.keys(result).sort(),role==='admin'?['done','message']:['message','uncertain']);
 }
});
