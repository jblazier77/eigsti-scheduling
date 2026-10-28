// Operator-only, fictional project allowlist. Never import this file into the app.
import {readFileSync,writeFileSync,existsSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {tmpdir} from 'node:os';
import {parseEnv} from 'node:util';
import {randomBytes} from 'node:crypto';
import {createClient} from '@supabase/supabase-js';
import {runDemoPostgres} from './demo-postgres.mjs';
import {backupConfig} from './backup-core.mjs';
import {safeFailure} from './failures.mjs';
import {buildTeamDemo,buildDemoSql,demoEmployees,DEMO_KEY} from '../../demo/team-demo-data.mjs';
const REF='vglhojtrccygjgupxsrd';let temp;
try{
 const repository=resolve('.'),ops=parseEnv(readFileSync('.env.ops.local','utf8')),app=parseEnv(readFileSync('.env.local','utf8'));
 if(app.EIGSTI_EXPECTED_PROJECT_REF!==REF||ops.EIGSTI_BACKUP_EXPECTED_REF!==REF||app.EIGSTI_DATA_MODE==='pilot'||app.EIGSTI_ENVIRONMENT==='production'||app.SUPABASE_URL!=='https://'+REF+'.supabase.co')throw Error('Demo setup is restricted to the existing fictional-data project.');
 const c=backupConfig({...process.env,...ops},repository);
 const run=async sql=>{const dir=temp??=mkdtempSync(join(tmpdir(),'eigsti-team-demo-'));const file=join(dir,'command.sql');writeFileSync(file,sql,{mode:0o600});return runDemoPostgres(c.psql,['-X','--no-password','-q','-t','-A','-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose','--file',file],c.pg);};
 console.log('Checking fictional test database and existing demo...');
 const preflight=JSON.parse((await run("begin read only; select jsonb_build_object('ready',exists(select 1 from pg_constraint where conrelid='public.visits'::regclass and conname='visits_monday_saturday_check'),'installed',exists(select 1 from private.command_requests where operation='team_demo_v1'),'pm',exists(select 1 from public.app_users where active and 'pm'=any(roles))); rollback;")).trim());
 if(!preflight.ready||!preflight.pm)throw Error('Apply updates through 0023 and retain an active PM before demo setup.');
 if(preflight.installed){console.log('Team demo is already installed. Existing demo edits were preserved; nothing was reset.');process.exitCode=0;}
 else{
  mkdirSync(c.root,{recursive:true});const credentials=join(c.root,'Eigsti-Team-Demo-Accounts.private.json');
  let accounts;
  if(existsSync(credentials)){accounts=JSON.parse(readFileSync(credentials,'utf8'));if(accounts.project!==REF||accounts.demo!==DEMO_KEY||accounts.users.length!==demoEmployees.length||accounts.users.some((u,i)=>u.id!==demoEmployees[i].id||u.email!==demoEmployees[i].email||typeof u.password!=='string'||u.password.length<20))throw Error('Private demo account file does not match. Keep it and verify before proceeding.');}
  else{accounts={project:REF,demo:DEMO_KEY,note:'FICTIONAL TEST ACCOUNTS ONLY. Keep private. Existing PM/admin sign-ins remain unchanged.',users:demoEmployees.map(e=>({...e,password:randomBytes(24).toString('base64url')}))};writeFileSync(credentials,JSON.stringify(accounts,null,2),{flag:'wx',mode:0o600});}
  const client=createClient(c.origin,app.SUPABASE_ADMIN_KEY||c.key,{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
  console.log('Preparing six fictional employee sign-ins...');
  for(const u of accounts.users){
   let response=await client.auth.admin.getUserById(u.id);
   if(response.error&&response.error.status!==404)throw Error('Demo sign-in lookup failed. No database reset was performed.');
   if(!response.data.user){const created=await client.auth.admin.createUser({id:u.id,email:u.email,password:u.password,email_confirm:true,app_metadata:{eigsti_demo:DEMO_KEY}});if(created.error)throw Error('Demo sign-in creation was not confirmed. Rerun the same command to recover; no database reset was performed.');response=created;}
   if(response.data.user?.id!==u.id||response.data.user.email!==u.email||response.data.user.app_metadata?.eigsti_demo!==DEMO_KEY)throw Error('A demo identity did not match. Existing accounts were left unchanged.');
  }
  const today=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Chicago',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
  const data=buildTeamDemo(today);
  console.log('Installing demo jobs, crew, materials and subcontractor commitments in one transaction...');
  const output=await run(buildDemoSql(data));const report=JSON.parse(output.trim().split(/\r?\n/).find(line=>line.trim().startsWith('{'))??'null');
  if(report?.result!=='Demo ready'||report.jobs!==8||report.employees!==6)throw Error('Demo result was not confirmed. Rerun this command to check safely.');
  console.log(JSON.stringify(report,null,2));console.log('Private lead/helper sign-ins: '+credentials);console.log('Use your existing PM sign-in, then open http://127.0.0.1:4310/jobs');
 }
}catch(error){console.error(error?.code?safeFailure(error):error.message||'Demo setup was not confirmed.');process.exitCode=1;}
finally{if(temp)rmSync(temp,{recursive:true,force:true});}
