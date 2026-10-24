// Operator-only PostgreSQL/storage backup. No password is passed in command arguments.
import {spawn} from 'node:child_process';
import {promises as fs} from 'node:fs';
import {join,resolve,isAbsolute} from 'node:path';
import {tmpdir} from 'node:os';
import {randomUUID} from 'node:crypto';
import {outsideRepository,requirePassphrase,hashFile,sealArchive,verifyArchive,removeTemporary} from './archive.mjs';
export const BUCKET='eigsti-job-files';
const KEY=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\/[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function backupConfig(env,repository){
 const ref=env.EIGSTI_BACKUP_EXPECTED_REF;if(!/^[a-z]{20}$/.test(ref??''))throw new Error('Set the source project reference.');
 if(env.VERCEL||env.NEXT_RUNTIME)throw new Error('Backup tooling must run on an operator computer, never inside the web app.');
 let db;try{db=new URL(env.EIGSTI_BACKUP_DB_URL);}catch{throw new Error('Set the operator database connection privately.');}
 if(!['postgres:','postgresql:'].includes(db.protocol)||!db.password||db.hash||db.pathname!=='/postgres'||!['','5432'].includes(db.port)||!(db.hostname==='db.'+ref+'.supabase.co'||(/^[a-z0-9.-]+\.pooler\.supabase\.com$/.test(db.hostname)&&decodeURIComponent(db.username)==='postgres.'+ref)))throw new Error('Database source must match the project; use direct/session port 5432, not a transaction pooler.');
 const key=env.EIGSTI_BACKUP_STORAGE_KEY;if(!key||!(key.startsWith('sb_secret_')||(()=>{try{return JSON.parse(Buffer.from(key.split('.')[1],'base64url').toString()).role==='service_role';}catch{return false;}})()))throw new Error('Set a private operator storage secret/service-role key.');
 if(!env.EIGSTI_BACKUP_ROOT||!isAbsolute(env.EIGSTI_BACKUP_ROOT))throw new Error('Set an absolute private backup directory outside the repository.');
 return {ref,origin:'https://'+ref+'.supabase.co',key,passphrase:requirePassphrase(env.EIGSTI_BACKUP_PASSPHRASE),root:outsideRepository(env.EIGSTI_BACKUP_ROOT,repository),repository:resolve(repository),psql:env.EIGSTI_PSQL||'psql',dump:env.EIGSTI_PG_DUMP||'pg_dump',restore:env.EIGSTI_PG_RESTORE||'pg_restore',pg:{...env,PGHOST:db.hostname,PGPORT:'5432',PGUSER:decodeURIComponent(db.username),PGPASSWORD:decodeURIComponent(db.password),PGDATABASE:'postgres',PGSSLMODE:'verify-full',PGCONNECT_TIMEOUT:'15',...(env.EIGSTI_DB_ROOT_CERT?{PGSSLROOTCERT:env.EIGSTI_DB_ROOT_CERT}:{})}};
}
export function runTool(binary,args,env){return new Promise((accept,reject)=>{const child=spawn(binary,args,{env,windowsHide:true,stdio:['ignore','pipe','pipe']});let out='';child.stdout.on('data',b=>{if(out.length<10*1024*1024)out+=b.toString();else child.kill();});child.stderr.resume();const timer=setTimeout(()=>{child.kill();reject(new Error('PostgreSQL operation timed out.'));},10*60*1000);child.on('error',()=>{clearTimeout(timer);reject(new Error('Required PostgreSQL tool is unavailable.'));});child.on('close',code=>{clearTimeout(timer);code===0?accept(out):reject(new Error('PostgreSQL operation failed. Check private connection/tool versions; output was suppressed to protect credentials.'));});});}
// Snapshot inventory is read inside the SAME transaction exported to pg_dump.
const SNAPSHOT_SQL=`begin isolation level repeatable read read only;
select 'EIGSTI_SNAPSHOT:'||jsonb_build_object(
 'snapshot',pg_export_snapshot(),'server_version',current_setting('server_version_num'),
 'counts',jsonb_build_object('jobs',(select count(*) from public.jobs),'work',(select count(*) from public.work_items),'profiles',(select count(*) from public.app_users),'auth_users',(select count(*) from auth.users)),
 'ready',coalesce((select jsonb_agg(jsonb_build_object('key',object_path,'size',byte_size)) from public.job_files where status='ready'),'[]'::jsonb),
 'objects',coalesce((select jsonb_agg(jsonb_build_object('key',name,'size',(metadata->>'size')::bigint,'mime',metadata->>'mimetype') order by name) from storage.objects where bucket_id='eigsti-job-files'),'[]'::jsonb));
`;
export function holdSnapshot(config){return new Promise((accept,reject)=>{
 const child=spawn(config.psql,['--no-psqlrc','--quiet','--tuples-only','--no-align','--no-password','--set','ON_ERROR_STOP=1'],{env:config.pg,windowsHide:true,stdio:['pipe','pipe','pipe']});let output='',resolved=false;
 const fail=()=>{if(!resolved){resolved=true;reject(new Error('Could not open a consistent read-only database snapshot.'));}};
 const timer=setTimeout(()=>{fail();child.kill();},30000);child.stderr.resume();child.on('error',()=>{clearTimeout(timer);fail();});
 const closed=new Promise(done=>child.on('close',code=>{clearTimeout(timer);fail();done(code);}));
 const close=async()=>{const closing=setTimeout(()=>child.kill(),30000);try{child.stdin.end('rollback;\n\\q\n');if(await closed!==0)throw new Error('Snapshot connection did not close cleanly.');}finally{clearTimeout(closing);}};
 child.stdout.on('data',b=>{output+=b.toString();if(output.length>10*1024*1024){fail();child.kill();return;}const line=output.split(/\r?\n/).find(v=>v.startsWith('EIGSTI_SNAPSHOT:'));if(!line||!output.endsWith('\n')||resolved)return;try{const inventory=JSON.parse(line.slice(16));if(!/^[0-9A-F]+-[0-9A-F]+-[0-9]+$/i.test(inventory.snapshot))throw Error();resolved=true;clearTimeout(timer);accept({inventory,close});}catch{fail();child.kill();}});
 child.stdin.on('error',fail);child.stdin.write(SNAPSHOT_SQL);
});}
export function validateInventory(inventory){
 if(!Array.isArray(inventory.objects)||!Array.isArray(inventory.ready)||inventory.objects.length>10000)throw new Error('Invalid/oversized storage inventory.');
 const objects=new Map();for(const object of inventory.objects){if(!KEY.test(object.key)||objects.has(object.key)||!Number.isSafeInteger(object.size)||object.size<1||object.size>10485760)throw new Error('Storage inventory has an unexpected key/size.');objects.set(object.key,object);}
 for(const file of inventory.ready){if(!KEY.test(file.key)||!objects.has(file.key)||objects.get(file.key).size!==file.size)throw new Error('A ready file is missing or does not match its storage metadata.');}
 return [...objects.values()];
}
export async function downloadObject(config,object,target,transport=fetch){
 const response=await transport(config.origin+'/storage/v1/object/authenticated/'+BUCKET+'/'+object.key,{headers:{apikey:config.key,Authorization:'Bearer '+config.key},redirect:'error',cache:'no-store',signal:AbortSignal.timeout(60000)});
 if(!response.ok||!response.body)throw new Error('A private file could not be backed up. No complete recovery archive will be published.');
 await fs.mkdir(resolve(target,'..'),{recursive:true,mode:0o700});const fd=await fs.open(target,'wx',0o600);let size=0;
 try{for await(const chunk of response.body){size+=chunk.length;if(size>object.size||size>10485760)throw new Error('Downloaded private file size mismatch.');await fd.writeFile(chunk);}}finally{await fd.close();}
 if(size!==object.size)throw new Error('Downloaded private file is incomplete.');
 return {key:object.key,path:'storage/'+object.key,size,sha256:await hashFile(target),mime:object.mime||'application/octet-stream'};
}
export async function createBackup(config,{run=runTool,snapshot=holdSnapshot,download=downloadObject,publish=fs.rename}={}){
 await fs.mkdir(config.root,{recursive:true,mode:0o700});outsideRepository(await fs.realpath(config.root),await fs.realpath(config.repository));
 const tools=await Promise.all([run(config.dump,['--version'],config.pg),run(config.psql,['--version'],config.pg),run(config.restore,['--version'],config.pg)]);
 const temp=await fs.mkdtemp(join(tmpdir(),'eigsti-ops-backup-')),runId=new Date().toISOString().replace(/[:.]/g,'-')+'-'+randomUUID();let held;
 const partial=join(config.root,runId+'.partial'),output=join(config.root,runId+'.eigsti-backup');
 try{
  held=await snapshot(config);const inventory=held.inventory,objects=validateInventory(inventory),serverMajor=Number(inventory.server_version)/10000|0;
  if(!tools.every(v=>Number(v.match(/PostgreSQL\)?\s+(\d+)/)?.[1])===serverMajor))throw new Error('Use PostgreSQL tools matching the server major version.');
  await fs.writeFile(join(temp,'source-inventory.json'),JSON.stringify(inventory),{flag:'wx',mode:0o600});
  await run(config.dump,['--format=custom','--no-owner','--no-password','--snapshot='+inventory.snapshot,'--file='+join(temp,'database.dump')],config.pg);
  await run(config.restore,['--list',join(temp,'database.dump')],config.pg);
  const stored=[];for(const object of objects)stored.push(await download(config,object,join(temp,'storage',...object.key.split('/'))));
  await held.close();held=null;
  const names=['database.dump','source-inventory.json',...stored.map(o=>o.path)],files=[];
  for(const path of names){const disk=join(temp,...path.split('/'));files.push({path,size:(await fs.stat(disk)).size,sha256:await hashFile(disk)});}
  const manifest={format:1,run_id:runId,project_ref:config.ref,created_at:new Date().toISOString(),counts:inventory.counts,postgres_major:serverMajor,storage_objects:stored,files,restore_verified:false,note:'Database archive includes Auth recovery data. Restore requires an isolated matching Supabase project and operator review; not an automatic live restore.'};
  await fs.writeFile(join(temp,'manifest.json'),JSON.stringify(manifest),{flag:'wx',mode:0o600});
  await sealArchive(temp,[...names,'manifest.json'],partial,config.passphrase);
  const report=await verifyArchive(partial,config.passphrase);await publish(partial,output);
  return {archive:output,...report};
 }finally{if(held)await held.close().catch(()=>{});await removeTemporary(temp);await fs.unlink(partial).catch(()=>{});}
}
