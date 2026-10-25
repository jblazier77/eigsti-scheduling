import test from 'node:test';
import assert from 'node:assert/strict';
import {withDatabasePassword} from '../scripts/ops/update-backup-password.mjs';
test('private password update preserves host, username and database while encoding symbols exactly once',()=>{
 const source='postgresql://postgres.aaaaaaaaaaaaaaaaaaaa:old@aws-0-example.pooler.supabase.com:5432/postgres';
 for(const raw of ['synthetic@#%?&!:/[]','synthetic%40literal',"synthetic'quote\"$",'synthetic café']){
  const url=new URL(withDatabasePassword(source,encodeURIComponent(raw)));
  assert.equal(decodeURIComponent(url.password),raw);assert.equal(url.hostname,new URL(source).hostname);assert.equal(url.username,new URL(source).username);assert.equal(url.pathname,'/postgres');assert.equal(url.port,'5432');
 }
 assert.throws(()=>withDatabasePassword(source,''));assert.throws(()=>withDatabasePassword(source,'%0A'));assert.throws(()=>withDatabasePassword(source,'%invalid'));
});
