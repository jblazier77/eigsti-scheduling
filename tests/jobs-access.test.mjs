import test from 'node:test';
import assert from 'node:assert/strict';
import { createJob, listJobs, validateCreateJob } from '../src/domain/jobs.ts';
import { canReadJob, hasRole } from '../src/domain/access.ts';
import { jobsHandler } from '../src/server/jobs-handler.ts';
import { SupabaseSession, validateConfig } from '../src/server/supabase.ts';
import { signInWithPassword, refreshSession } from '../src/server/password-auth.ts';

const pmId = '11111111-1111-4111-8111-111111111111';
const requestId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const pm = { id: pmId, active: true, roles: ['pm'] };
const config = { url: 'https://synthetic-project.supabase.co', publishableKey: 'sb_publishable_test_only', environment: 'test' };
const input = { requestId, customer: '  Synthetic Customer  ', phone: '(202) 555-0100', address: '  100 Fictional Demo Lane  ' };
const json = (body, status=200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

function transportFor(actor, lastResponse = json([])) {
  const calls = [];
  const transport = async (url, init) => {
    calls.push({ url, init });
    if (url.endsWith('/auth/v1/user')) return json({ id: pmId });
    if (url.includes('/rest/v1/app_users?')) return json(actor ? [{ ...actor, id: pmId }] : []);
    return lastResponse;
  };
  return { calls, transport };
}

test('three-field validation retains readable phone and normalizes the action value', () => {
  const valid = validateCreateJob(input);
  assert.equal(valid.customer, 'Synthetic Customer'); assert.equal(valid.address, '100 Fictional Demo Lane');
  assert.equal(valid.phone, '(202) 555-0100'); assert.equal(valid.phoneAction, '+12025550100');
  for (const patch of [{ customer: '' }, { phone: '555' }, { phone: '2025550100;alert' }, { address: '' }, { requestId: 'bad' }, { responsible_pm: 'attacker' }, { roles: ['pm'] }]) {
    assert.throws(() => validateCreateJob({ ...input, ...patch }), { code: 'invalid_input' });
  }
});

test('only active PM role can create; admin-only does not inherit operational privileges', async () => {
  let writes = 0; const gateway = { createJob: async valid => { writes++; return valid; } };
  for (const actor of [null, { ...pm, active: false }, ...['admin', 'lead', 'helper'].map(role => ({ ...pm, roles: [role] }))]) {
    await assert.rejects(createJob(actor, input, gateway));
  }
  assert.equal(writes, 0);
  await createJob({ ...pm, roles: ['admin','pm'] }, input, gateway);
  assert.equal(writes, 1);
});

test('job visibility follows assigned context, including lead helping without changing account role', () => {
  const access = { responsiblePm: 'other-pm', leadIds: ['lead1'], helperIds: ['helper1', 'lead2'], lifecycle: 'open' };
  assert(canReadJob(pm, access));
  assert(canReadJob({ id: 'lead1', active: true, roles: ['lead'] }, access));
  assert(canReadJob({ id: 'lead2', active: true, roles: ['lead'] }, access));
  assert(canReadJob({ id: 'helper1', active: true, roles: ['helper'] }, access));
  assert(!canReadJob({ id: 'stranger', active: true, roles: ['helper'] }, access));
  assert(!canReadJob({ id: 'helper1', active: false, roles: ['helper'] }, access));
  assert(!canReadJob({ id: 'helper1', active: true, roles: ['helper'] }, { ...access, lifecycle: 'closed' }));
  assert(!canReadJob({ id: 'lead1', active: true, roles: ['admin'] }, access));
  assert(!hasRole({ ...pm, active: false }, 'pm'));
});

test('PM defaults to My Jobs, can choose All Jobs; helper cannot request All Jobs', async () => {
  const queries=[]; const gateway={listJobs:async query=>{queries.push(query);return []}};
  await listJobs(pm, {}, gateway); assert.equal(queries[0].responsiblePm, pmId);
  await listJobs(pm, {scope:'all'}, gateway); assert.equal(queries[1].responsiblePm, undefined);
  await assert.rejects(listJobs({...pm,roles:['helper']},{scope:'all'},gateway), {code:'not_allowed'});
  await assert.rejects(listJobs(pm,{offset:'1.1'},gateway), {code:'invalid_input'});
  await assert.rejects(listJobs(pm,{scope:'unknown'},gateway), {code:'invalid_input'});
});

test('handler denies anonymous requests before any transport calls', async () => {
  let calls=0;
  const response = await jobsHandler(config, async()=>{calls++;throw Error('must not call')})(new Request('https://app.invalid/api/jobs'));
  assert.equal(response.status,401); assert.equal(calls,0);
  assert.equal(response.headers.get('cache-control'),'no-store');
});

test('helper direct POST is denied before database RPC', async () => {
  const {transport,calls}=transportFor({...pm,roles:['helper']});
  const response=await jobsHandler(config,transport)(new Request('https://app.invalid/api/jobs',{method:'POST',headers:{Authorization:'Bearer test-user-token','Content-Type':'application/json'},body:JSON.stringify(input)}));
  assert.equal(response.status,403);
  assert.equal(calls.length,2); assert(!calls.some(c=>c.url.includes('/rpc/')));
});

test('deactivated or uninvited accounts cannot list even with accepted Auth token', async () => {
  for(const actor of [null,{...pm,active:false}]){
    const {transport,calls}=transportFor(actor);
    const response=await jobsHandler(config,transport)(new Request('https://app.invalid/api/jobs',{headers:{Authorization:'Bearer stale-token'}}));
    assert.equal(response.status,403); assert.equal(calls.length,2);
  }
});

test('PM create passes the same idempotency key to one atomic RPC and preserves user identity', async () => {
  const {transport,calls}=transportFor(pm,json({id:'demo-job',customer_name:'Synthetic Customer'}));
  const response=await jobsHandler(config,transport)(new Request('https://app.invalid/api/jobs',{method:'POST',headers:{Authorization:'Bearer verified-employee-token','Content-Type':'application/json'},body:JSON.stringify(input)}));
  assert.equal(response.status,200);
  const rpc=calls.at(-1); assert(rpc.url.endsWith('/rpc/create_job'));
  const payload=JSON.parse(rpc.init.body); assert.equal(payload.p_request_id,requestId);assert.equal(payload.p_customer,'Synthetic Customer');
  assert.deepEqual(Object.keys(payload).sort(),['p_address','p_customer','p_phone','p_request_id']);
  assert.equal(rpc.init.headers.Authorization,'Bearer verified-employee-token');
  assert.equal(rpc.init.headers.apikey,config.publishableKey);
});

test('bad JSON, oversized body, unknown fields and wrong content type never reach write RPC', async () => {
  for(const [body,type,status] of [['{','application/json',400],['x'.repeat(9000),'application/json',413],[JSON.stringify({...input,roles:['pm']}),'application/json',400],[JSON.stringify(input),'text/plain',415]]){
    const {transport,calls}=transportFor(pm);
    const response=await jobsHandler(config,transport)(new Request('https://app.invalid/api/jobs',{method:'POST',headers:{Authorization:'Bearer test-token','Content-Type':type},body}));
    assert.equal(response.status,status); assert(!calls.some(c=>c.url.includes('/rpc/')));
  }
});

test('database permission denial and request collision return controlled errors', async () => {
  for(const [code,status] of [['42501',403],['23505',409],['22023',400]]){
    const {transport}=transportFor(pm,json({code,message:'do not expose private SQL values'},400));
    const response=await jobsHandler(config,transport)(new Request('https://app.invalid/api/jobs',{method:'POST',headers:{Authorization:'Bearer test-token','Content-Type':'application/json'},body:JSON.stringify(input)}));
    assert.equal(response.status,status); assert(!(await response.text()).includes('private SQL'));
  }
});

test('failed transport is never returned as a confirmed saved result', async () => {
  const {transport}=transportFor(pm);
  const failOnWrite=async(url,init)=>url.includes('/rpc/')?Promise.reject(new Error('lost response')):transport(url,init);
  const response=await jobsHandler(config,failOnWrite)(new Request('https://app.invalid/api/jobs',{method:'POST',headers:{Authorization:'Bearer test-token','Content-Type':'application/json'},body:JSON.stringify(input)}));
  assert.equal(response.status,503); assert.match((await response.json()).message,/not been confirmed saved/);
});

test('data client rejects administrative keys and unsafe origins', () => {
  assert.throws(()=>validateConfig({...config,publishableKey:'sb_secret_not_a_user_key'}));
  const serviceJwt='e30.'+Buffer.from(JSON.stringify({role:'service_role'})).toString('base64url')+'.signature';
  assert.throws(()=>validateConfig({...config,publishableKey:serviceJwt}));
  assert.throws(()=>validateConfig({...config,url:'http://example.com'}));
  assert.throws(()=>validateConfig({...config,url:'https://secret@example.com'}));
  assert.throws(()=>validateConfig({...config,url:'http://localhost:54321',environment:'production'}));
});

test('profile is checked again for each employee request, regardless of stale JWT roles', async () => {
  let active=true;
  const transport=async(url)=>url.endsWith('/auth/v1/user')?json({id:pmId}):json(active?[pm]:[]);
  const session=new SupabaseSession(config,'old-pm-token',transport);
  assert.equal((await session.getActor()).roles[0],'pm'); active=false;
  await assert.rejects(session.getActor(),{code:'access_disabled'});
});

test('password sign-in delegates to Auth, verifies active app membership and never sends Google requests', async () => {
  const calls=[];
  const transport=async(url,init)=>{
    calls.push({url,init});
    if(url.includes('/auth/v1/token?'))return json({access_token:'test-access',refresh_token:'test-refresh',expires_in:3600});
    if(url.endsWith('/auth/v1/user'))return json({id:pmId});
    return json([pm]);
  };
  const session=await signInWithPassword(config,' DEMO@example.invalid ','synthetic-password',transport);
  assert.equal(session.actor.id,pmId);assert.equal(session.refreshToken,'test-refresh');
  assert.equal(JSON.parse(calls[0].init.body).email,'demo@example.invalid');
  assert(calls.every(c=>new URL(c.url).origin===config.url));
  await refreshSession(config,'test-refresh',transport);
  assert(calls.some(c=>c.url.endsWith('grant_type=refresh_token')));
});

test('Auth success alone cannot admit an uninvited employee; throttling is retained', async () => {
  const transport=async(url)=>url.includes('/token?')?json({access_token:'test-access',refresh_token:'test-refresh',expires_in:3600}):url.endsWith('/user')?json({id:pmId}):json([]);
  await assert.rejects(signInWithPassword(config,'demo@example.invalid','synthetic-password',transport),{code:'access_disabled'});
  await assert.rejects(signInWithPassword(config,'demo@example.invalid','synthetic-password',async()=>json({},429)),{code:'try_later'});
});
