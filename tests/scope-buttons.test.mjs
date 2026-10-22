import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
import {createElement} from 'react';
import {renderToStaticMarkup} from 'react-dom/server';
import * as classification from '../src/domain/job-classification.ts';
const require=createRequire(import.meta.url),swc=require('next/dist/build/swc');
function components(){
 const exports={},source=swc.transformSync(readFileSync(new URL('../src/app/components/classification-editor.tsx',import.meta.url),'utf8'),{filename:'classification-editor.tsx',jsc:{parser:{syntax:'typescript',tsx:true},target:'es2022',transform:{react:{runtime:'automatic'}}},module:{type:'commonjs'}}).code;
 const deps={'../../domain/job-classification.ts':classification,'../classification-actions':{},'./job-markers':{WorkIcon:()=>createElement('span',{'aria-hidden':true},'icon')}};
 runInNewContext(source,{exports,require:name=>deps[name]??require(name)});return exports;
}
test('every project scope remains visible as a pressed-state button, with no checkbox selector',()=>{
 const {ClassificationFields}=components(),value={...classification.emptyClassification,whole_house:true,trades:['plumbing']};
 const html=renderToStaticMarkup(createElement(ClassificationFields,{value,onChange:()=>{}}));
 assert.equal((html.match(/class="scope-toggle"/g)||[]).length,18); // 15 trades + house + 2 independent tags
 assert.equal((html.match(/aria-pressed="true"/g)||[]).length,2);
 assert.ok(!html.includes('<input'));assert.ok(!html.includes('<details'));assert.ok(html.includes('Whole house'));
 for(const trade of classification.trades)assert.ok(html.includes(trade.label.replaceAll('&','&amp;')));
});
test('readers see the same selected scopes and all inactive choices without editable controls',()=>{
 const {ReadOnlyClassification}=components(),html=renderToStaticMarkup(createElement(ReadOnlyClassification,{value:{...classification.emptyClassification,trades:['painting']}}));
 assert.equal((html.match(/disabled=""/g)||[]).length,16);assert.equal((html.match(/aria-pressed="true"/g)||[]).length,1);assert.ok(!html.includes('<form'));assert.ok(!html.includes('Save'));
});
