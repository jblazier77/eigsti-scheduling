import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {buildTeamDemo,buildDemoSql,demoEmployees,demoId} from '../demo/team-demo-data.mjs';
import {validateWork} from '../src/domain/work.ts';
import {validateCreateJob} from '../src/domain/jobs.ts';
import {classificationPatch} from '../src/domain/job-classification.ts';
import {validateOptionalPlan,validateMaterial} from '../src/domain/planning-updates.ts';
import {optionalNumber} from '../src/domain/planning-review.ts';
test('team demo contains eight valid fictional jobs, six least-privilege demo employees and valid quick-work inputs',()=>{
 const d=buildTeamDemo('2026-10-28');assert.equal(d.jobs.length,8);assert.equal(d.employees.length,6);assert.equal(new Set(d.employees.map(e=>e.id)).size,6);assert(d.employees.every(e=>e.email.endsWith('@eigsti-demo.invalid')&&e.roles.every(r=>['lead','helper'].includes(r))));
 for(const j of d.jobs){assert(j.name.startsWith('DEMO - '));validateCreateJob({requestId:j.id,customer:j.name,phone:j.phone,address:j.address});classificationPatch({rain_day:j.rain,filler:j.filler,whole_house:j.whole,trades:j.trades});optionalNumber(j.priority,'priority');for(const w of j.work){const owner=d.employees.find(e=>e.key===w.lead),values=validateWork({description:w.name,responsible_lead:owner?.id??null});optionalNumber(w.days,'days');const named=w.names.map(k=>d.employees.find(e=>e.key===k)?.id);assert(named.every(Boolean));assert(!named.includes(owner?.id));assert(named.length<=w.needed);assert(w.date||!named.length);validateOptionalPlan(w.date?{start_date:w.date,end_date:w.date,slot:'day',required_helpers:w.needed}:null,values);validateMaterial({material_name:w.item,material_status:w.status,material_expected_on:w.arrival});}}
});
test('demo covers Saturday work, lead helping another lead, shortages, lead needed, rain/filler and multiple material states',()=>{
 const d=buildTeamDemo('2026-10-28'),work=d.jobs.flatMap(j=>j.work);assert(work.some(w=>w.date==='2026-10-31'));assert(work.some(w=>w.names.includes('lead-a')&&w.lead==='lead-b'));assert(work.some(w=>w.needed>w.names.length));assert(work.some(w=>w.date&&!w.lead&&w.names.length));assert(d.jobs.some(j=>j.rain&&j.filler));assert(d.jobs.some(j=>j.whole));assert.deepEqual([...new Set(work.map(w=>w.status))].sort(),['in_stock','need_to_order','not_needed','ordered']);assert(work.some(w=>!w.date));
 for(const start of ['2026-10-31','2026-11-01','2026-12-30'])for(const w of buildTeamDemo(start).jobs.flatMap(j=>j.work))if(w.date)assert.notEqual(new Date(w.date+'T12:00:00Z').getUTCDay(),0);
});
test('demo SQL atomically archives throwaway data, preserves PM/admin access and guards replay before reset',()=>{
 const sql=buildDemoSql(buildTeamDemo('2026-10-28'));assert(sql.startsWith('begin;'));assert.equal((sql.match(/^commit;$/gm)||[]).length,1);assert(sql.indexOf('Demo already installed')<sql.indexOf('update public.visits'));assert(sql.includes("not roles && array['pm','admin']"));assert(sql.includes('public.create_job_workspace'));assert(sql.includes('public.save_contact_commitment'));assert(sql.includes('public.save_subcontractor'));assert(!/delete from (public|auth)\./i.test(sql));assert(!/drop table|truncate|encrypted_password|password/i.test(sql));assert(sql.includes("'Fictional '||(j->'sub'->>'trade')||' contractor.'"));assert.equal(demoId('seed-receipt'),demoId('seed-receipt'));
});
test('operator runner checks allowlisted synthetic environment before provisioning, and never sends passwords through SQL',()=>{
 const source=readFileSync(new URL('../scripts/ops/setup-team-demo.mjs',import.meta.url),'utf8');assert(source.includes("const REF='vglhojtrccygjgupxsrd'"));assert(source.indexOf('preflight=JSON.parse')<source.indexOf('auth.admin.createUser'));assert(source.includes("app.EIGSTI_DATA_MODE==='pilot'"));assert(source.includes('response.data.user.app_metadata?.eigsti_demo!==DEMO_KEY'));assert(!source.includes('updateUserById'));assert(!source.includes('deleteUser'));assert(source.includes("flag:'wx'"));assert(source.includes('credentials=join(c.root'));assert(source.includes('buildDemoSql(data)'));
});

test('demo seed local IDs do not shadow schema columns and access cleanup is qualified',()=>{
 const sql=buildDemoSql(buildTeamDemo('2026-10-28'));assert(!sql.includes(' job_id uuid;'));assert(!sql.includes(' contact_id uuid;'));assert(sql.includes('v_job_id uuid;'));assert(sql.includes('public.create_job_contact(v_job_id,'));assert(sql.includes('public.save_contact_commitment(v_job_id,v_contact_id,'));assert(sql.includes('where a.job_id=any(old_jobs)'));assert(sql.includes('EIGSTI_DEMO_FAILURE:'));assert(sql.includes("v_step:='create_workspace'"));
});
test('demo diagnostics expose only safe SQLSTATE and fixed stage, never private stderr or SQL context',async()=>{
 const {demoFailure}=await import('../scripts/ops/demo-postgres.mjs');const secret='DO_NOT_EXPOSE_SECRET';
 assert.equal(demoFailure('ERROR: EIGSTI_DEMO_FAILURE:42702:archive_old_demo\nCONTEXT: '+secret),'Demo database error [42702] during archive_old_demo. No demo transaction was committed.');
 assert.equal(demoFailure('FATAL: 28P01: password authentication failed '+secret),'Demo PostgreSQL error [28P01]. No successful installation is confirmed.');assert(!demoFailure(secret).includes(secret));
});
