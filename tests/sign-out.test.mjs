import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { runInNewContext } from 'node:vm';
import { signOutWithDeadline } from '../src/server/sign-out.ts';
test('remote logout is bounded and aborts on hang or failure',async()=>{
  let signal;
  assert.equal(await signOutWithDeadline(async s=>{signal=s;return new Promise(()=>{});},15),false);
  assert.equal(signal.aborted,true);
  assert.equal(await signOutWithDeadline(async()=>{throw new Error('Offline');},15),false);
  assert.equal(await signOutWithDeadline(async()=>{},15),true);
});
test('sign-out clears only current project cookies and redirects even when remote logout throws',async()=>{
  const calls=[],exports={};
  const deps={
    'next/navigation':{redirect:path=>{calls.push(['redirect',path]);throw new Error('FRAMEWORK_REDIRECT');}},
    'next/cache':{},
    'next/headers':{cookies:async()=>({getAll:()=>[{name:'sb-test-project-auth-token'},{name:'sb-test-project-auth-token.0'},{name:'sb-other-auth-token'},{name:'unrelated'}],delete:name=>calls.push(['delete',name])})},
    '../lib/supabase-server':{authClient:async(writable,signal)=>{assert.equal(writable,false);assert.ok(signal);return {auth:{signOut:async options=>{calls.push(['logout',options.scope]);throw new Error('Offline');}}};}},
    '../lib/config':{},'../server/supabase.ts':{},'../domain/jobs.ts':{},'../domain/job-edits.ts':{},'../domain/access.ts':{},'../server/sign-out.ts':{signOutWithDeadline}
  };
  const source=stripTypeScriptTypes(readFileSync(new URL('../src/app/actions.ts',import.meta.url),'utf8')).replace(/^import \{([^}]+)\} from '([^']+)';$/gm,'const {$1} = require(\'$2\');').replace(/export async function (\w+)/g,'exports.$1 = async function $1');
  runInNewContext(source,{exports,process:{env:{EIGSTI_EXPECTED_PROJECT_REF:'test-project'}},require:name=>deps[name]});
  await assert.rejects(exports.signOutAction(),/FRAMEWORK_REDIRECT/);
  assert.deepEqual(calls,[['logout','local'],['delete','sb-test-project-auth-token'],['delete','sb-test-project-auth-token.0'],['redirect','/login']]);
});
