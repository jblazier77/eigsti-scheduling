import test from 'node:test';
import assert from 'node:assert/strict';
import { appConfig, secureSessionCookies, workspaceLabel } from '../src/lib/config.ts';

const keys = ['SUPABASE_URL','SUPABASE_PUBLISHABLE_KEY','EIGSTI_ENVIRONMENT','EIGSTI_EXPECTED_PROJECT_REF','NODE_ENV','EIGSTI_DATA_MODE','VERCEL_ENV'];
function withConfig(values, callback) {
  const previous=Object.fromEntries(keys.map(k=>[k,process.env[k]]));
  try { for(const key of keys) { if(values[key]===undefined) delete process.env[key]; else process.env[key]=values[key]; } return callback(); }
  finally { for(const key of keys) {if(previous[key]===undefined)delete process.env[key];else process.env[key]=previous[key];} }
}
const config={SUPABASE_URL:'https://aaaaaaaaaaaaaaaaaaaa.supabase.co',SUPABASE_PUBLISHABLE_KEY:'sb_publishable_synthetic_test',EIGSTI_EXPECTED_PROJECT_REF:'aaaaaaaaaaaaaaaaaaaa',EIGSTI_ENVIRONMENT:'test',NODE_ENV:'development'};

test('app starts without credentials without opening any live data connection',()=>{
  withConfig({},()=>assert.equal(appConfig(),null));
});
test('configured project must match explicitly recorded environment',()=>{
  withConfig(config,()=>assert.equal(appConfig().environment,'test'));
  withConfig({...config,EIGSTI_EXPECTED_PROJECT_REF:'bbbbbbbbbbbbbbbbbbbb'},()=>assert.throws(appConfig,/does not match/));
  withConfig({...config,EIGSTI_ENVIRONMENT:undefined},()=>assert.throws(appConfig,/environment/));
  withConfig({...config,SUPABASE_PUBLISHABLE_KEY:'sb_secret_not_allowed'},()=>assert.throws(appConfig,/administrative secret/));
});
test('production sessions require secure cookies; local development test sessions work on loopback HTTP',()=>{
  withConfig(config,()=>assert.equal(secureSessionCookies(),false));
  withConfig({...config,NODE_ENV:'production'},()=>assert.equal(secureSessionCookies(),true));
  withConfig({...config,EIGSTI_ENVIRONMENT:'production'},()=>assert.equal(secureSessionCookies(),true));
});

test('real pilot mode cannot run in a test environment or a Vercel preview',()=>{
 withConfig(config,()=>assert.equal(workspaceLabel(),'Test workspace / Fictional customer information only'));
 withConfig({...config,EIGSTI_DATA_MODE:'pilot'},()=>assert.throws(appConfig,/production environment/));
 withConfig({...config,EIGSTI_DATA_MODE:'pilot',EIGSTI_ENVIRONMENT:'production',VERCEL_ENV:'preview'},()=>assert.throws(appConfig,/never a preview/));
 withConfig({...config,EIGSTI_DATA_MODE:'pilot',EIGSTI_ENVIRONMENT:'production',VERCEL_ENV:'production'},()=>assert.equal(workspaceLabel(),'Limited pilot / Company use'));
 withConfig({...config,EIGSTI_DATA_MODE:'unknown'},()=>assert.throws(appConfig,/explicit/));
});

test('a production connection is rejected from preview even when the label says synthetic',()=>withConfig({...config,EIGSTI_ENVIRONMENT:'production',VERCEL_ENV:'preview',EIGSTI_DATA_MODE:'synthetic'},()=>assert.throws(appConfig,/separate test environment/)));
