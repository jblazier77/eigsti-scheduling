import test from 'node:test';
import assert from 'node:assert/strict';
import {alphabeticalContacts, changedContactFields, emptyContact, validateContact} from '../src/domain/contacts.ts';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
const require=createRequire(import.meta.url),swc=require('next/dist/build/swc');

test('contacts sort case-insensitively by name including the customer, with deterministic ties and no mutation',()=>{
 const rows=[{id:'z',name:'Zoe'},{id:'primary',name:'bob'},{id:'b',name:'Alice'},{id:'a',name:'alice'},{id:'n',name:'Crew 10'},{id:'m',name:'Crew 2'}];
 assert.deepEqual(alphabeticalContacts(rows).map(row=>row.id),['a','b','primary','m','n','z']);
 assert.equal(rows[0].id,'z');
});
test('existing relationship/trade labels survive narrow edits; subcontractor type uses the existing validated field',()=>{
 const legacy={...emptyContact,name:'SYNTHETIC Company',relationship:'Electrician'};
 assert.deepEqual(changedContactFields(legacy,{...legacy,phone:'312-555-0100'}),{phone:'312-555-0100'});
 assert.equal(validateContact({...legacy,relationship:'Subcontractor'}).relationship,'Subcontractor');
});
test('compact contact reader sorts primary with other names, exposes useful actions and hides edits from helpers',()=>{
 const source=swc.transformSync(readFileSync(new URL('../src/app/components/contact-list.tsx',import.meta.url),'utf8'),{filename:'contact-list.tsx',jsc:{parser:{syntax:'typescript',tsx:true},target:'es2022',transform:{react:{runtime:'automatic'}}},module:{type:'commonjs'}}).code;
 const exports={};runInNewContext(source,{exports,require:name=>name==='../../domain/contacts.ts'?{alphabeticalContacts}:name==='./contact-form'?{ContactForm:()=>null}:name==='./contact-commitments'?{ContactCommitments:()=>null}:name==='../../domain/commitments.ts'?{isSubcontractor:value=>value.trim().toLowerCase()==='subcontractor'}:name==='./detail-icons'?{DetailIcon:()=>null}:require(name)});
 const props={jobId:'job',isPm:false,canAdd:false,directory:[],directoryUnavailable:false,primary:{name:'Zoe Customer',phone:'312-555-0101',phoneAction:'+13125550101'},contacts:[{...emptyContact,id:'a',job_id:'job',name:'Alpha Plumbing',relationship:'Subcontractor',phone_action:'+13125550100',email:'test@example.com',notes:'Use side door'}]};
 const html=renderToStaticMarkup(createElement(exports.ContactList,props));
 assert(html.indexOf('Alpha Plumbing')<html.indexOf('Zoe Customer'));
 assert(html.includes('Subcontractor'));assert(html.includes('aria-label="Call Alpha Plumbing"'));assert(html.includes('aria-label="Text Alpha Plumbing"'));assert(html.includes('aria-label="Email Alpha Plumbing"'));assert(!html.includes('aria-label="Edit '));assert(!html.includes('Add contact'));
 const pm=renderToStaticMarkup(createElement(exports.ContactList,{...props,isPm:true,canAdd:true}));assert(pm.includes('aria-label="Edit Alpha Plumbing"'));assert(!pm.includes('aria-label="Edit Zoe Customer"'));assert(pm.includes('Add contact'));
});
