import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import {trades} from '../src/domain/job-classification.ts';
const require=createRequire(import.meta.url),swc=require('next/dist/build/swc');
function loadMarkers(){
 const source=swc.transformSync(readFileSync(new URL('../src/app/components/job-markers.tsx',import.meta.url),'utf8'),{filename:'job-markers.tsx',jsc:{parser:{syntax:'typescript',tsx:true},target:'es2022',transform:{react:{runtime:'automatic'}}},module:{type:'commonjs'}}).code;
 const exports={};runInNewContext(source,{exports,require:name=>name.includes('job-classification')?{trades}:require(name)});return exports;
}
test('job markers have readable rain/filler labels and tap-expandable named trade scopes',()=>{
 const {JobMarkers}=loadMarkers(),html=renderToStaticMarkup(createElement(JobMarkers,{value:{rain_day:true,filler:true,trades:['plumbing','electrical']}}));
 assert.match(html,/Rain-day option/);assert.match(html,/Filler work/);assert.match(html,/<details/);assert.match(html,/aria-label="Electrical"/);assert.match(html,/Plumbing/);assert.match(html,/aria-hidden="true"/);
});
test('Whole house suppresses the icon row while preserving the underlying scope list for expansion',()=>{
 const {JobMarkers}=loadMarkers(),html=renderToStaticMarkup(createElement(JobMarkers,{value:{whole_house:true,trades:trades.map(t=>t.id)}}));
 assert.match(html,/Whole house/);assert.match(html,/<summary><span>View scopes<\/span><\/summary>/);
 for(const t of trades)assert.ok(html.includes(t.label.replaceAll('&','&amp;')));
});
