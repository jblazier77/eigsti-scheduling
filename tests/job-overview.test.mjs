import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {canPreviewPhoto} from '../src/domain/files.ts';
const require=createRequire(import.meta.url),swc=require('next/dist/build/swc');
function component(name,deps){
 const source=swc.transformSync(readFileSync(new URL('../src/app/components/'+name+'.tsx',import.meta.url),'utf8'),{filename:name+'.tsx',jsc:{parser:{syntax:'typescript',tsx:true},target:'es2022',transform:{react:{runtime:'automatic'}}},module:{type:'commonjs'}}).code;
 const exports={};runInNewContext(source,{exports,require:name=>deps[name]??require(name)});return exports;
}
const icons={DetailIcon:()=>createElement('span',{'aria-hidden':true},'icon')};
test('scope is visible without an accordion; only PM receives the small edit control',()=>{
 const {JobScopeDetails}=component('job-scope-details',{'./detail-icons':icons,'./edit-job-form':{InlineJobDetails:()=>null}});
 for(const canEdit of [true,false]){const html=renderToStaticMarkup(createElement(JobScopeDetails,{jobId:'job',original:{scope:'Install kitchen cabinets'},canEdit}));assert.ok(html.includes('Install kitchen cabinets'));assert.ok(!html.includes('<details'));assert.equal(html.includes('Edit job details and scope'),canEdit);}
});
test('gallery photos use lazy same-origin previews; PDF/HEIC remain usable labeled original-file tiles',()=>{
 const {FileThumbnail}=component('file-thumbnail',{'./detail-icons':icons,'../../domain/files.ts':{canPreviewPhoto}});
 const base={id:'file',job_id:'job',filename:'Site photo.jpg',status:'ready',mime_type:'image/jpeg'};
 const photo=renderToStaticMarkup(createElement(FileThumbnail,{file:base}));assert.ok(photo.includes('src="/jobs/job/files/file/preview"'));assert.ok(photo.includes('loading="lazy"'));assert.ok(!photo.includes('supabase'));assert.ok(!photo.includes('token='));
 for(const [mime,label]of [['application/pdf','PDF'],['image/heic','Original photo']]){const html=renderToStaticMarkup(createElement(FileThumbnail,{file:{...base,mime_type:mime}}));assert.ok(html.includes(label));assert.ok(!html.includes('<img'));assert.ok(html.includes('/download'));}
 const pending=renderToStaticMarkup(createElement(FileThumbnail,{file:{...base,status:'pending'}}));assert.ok(pending.includes('Upload incomplete'));assert.ok(pending.includes('aria-disabled="true"'));assert.ok(!pending.includes('<img'));
});
