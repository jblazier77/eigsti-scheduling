import test from 'node:test';
import assert from 'node:assert/strict';
import { appConfig, secureSessionCookies } from '../src/lib/config.ts';

const keys = ['SUPABASE_URL','SUPABASE_PUBLISHABLE_KEY','EIGSTI_ENVIRONMENT','EIGSTI_EXPECTED_PROJECT_REF','NODE_ENV'];
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
