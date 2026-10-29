import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
import * as React from 'react';
import * as domain from '../src/domain/pricing.ts';
const require=createRequire(import.meta.url),swc=require('next/dist/build/swc'),id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const row={description:'2x12x12 Douglas Fir',comparison:'2x12x12 Douglas Fir #2',sku:'DF',unit:'each',quantity:1,price:20,source:'PDF page 1',confirmed:true};
const text=node=>Array.isArray(node)?node.map(text).join(''):node&&typeof node==='object'?text(node.props?.children):String(node??'');
const flatten=node=>Array.isArray(node)?node.flatMap(flatten):node&&typeof node==='object'?[node,...flatten(node.props?.children)]:[];
function editor(rows,transport=async()=>Response.json({ok:true,id,version:2,published:true})){
 const slots=[],calls=[],exports={};let cursor=0;
 const hooks={...React,useState:initial=>{const i=cursor++;if(!(i in slots))slots[i]=typeof initial==='function'?initial():initial;return[slots[i],value=>{slots[i]=typeof value==='function'?value(slots[i]):value;}];},useRef:initial=>{const i=cursor++;return slots[i]??= {current:initial};},useEffect:()=>{}};
 const deps={'react':hooks,'next/link':{__esModule:true,default:()=>null},'next/navigation':{useRouter:()=>({refresh:()=>calls.push('refresh'),push:()=>{}})},'../../domain/pricing.ts':domain,'../pricing-actions':{},'./subcontractor-editor':{SubcontractorEditor:()=>null}};
 const code=swc.transformSync(readFileSync(new URL('../src/app/components/pricing-workspace.tsx',import.meta.url),'utf8'),{filename:'pricing-workspace.tsx',jsc:{parser:{syntax:'typescript',tsx:true},target:'es2022',transform:{react:{runtime:'automatic'}}},module:{type:'commonjs'}}).code;
 runInNewContext(code,{exports,require:n=>deps[n]??require(n),crypto:{randomUUID:()=>id},AbortSignal,confirm:()=>{throw Error('Native dialog must not be used for publishing or checking rows');},fetch:async(url,options)=>{calls.push({url,body:options.body});return transport(url,options);}});
 const render=()=>{cursor=0;return exports.PricingReview({list:{id,vendor_id:id,catalog:'Lumber',status:'draft',version:1,filename:'pricing.pdf',mime_type:'application/pdf',effective_on:'2026-10-29'},initialRows:rows,vendor:'Fictional Vendor'});};
 return{render,calls,button:(tree,label)=>flatten(tree).find(n=>n.type==='button'&&text(n)===label),nodes:flatten};
}
const settle=()=>new Promise(resolve=>setImmediate(resolve));
test('Publish reports the first incomplete off-page item beside its controls and brings its page into view',async()=>{const rows=Array.from({length:21},()=>({...row}));rows[20].unit='';const e=editor(rows);e.button(e.render(),'Publish pricing').props.onClick();await settle();const tree=e.render(),alert=e.nodes(tree).find(n=>n.props.role==='alert');assert(text(alert).includes('Item 21'));assert(text(alert).includes('Priced per'));assert(text(tree).includes('page 2 of 2'));assert.equal(e.calls.length,0);assert.equal(e.button(tree,'Publish pricing').props.disabled,false);});
test('review confirmation and publication work without browser-native dialogs and show success',async()=>{const e=editor([{...row,confirmed:false}]);let tree=e.render();const bulk=e.nodes(tree).find(n=>n.type==='input'&&n.props.type==='checkbox'&&n.props.disabled===false);bulk.props.onChange({target:{checked:true}});tree=e.render();e.button(tree,'Publish pricing').props.onClick();assert(text(e.render()).includes('Saving...'));await settle();tree=e.render();assert(text(tree).includes('Published. Current prices are searchable.'));assert.equal(JSON.parse(e.calls.find(c=>c.body).body).rows[0].confirmed,true);assert(e.calls.includes('refresh'));assert(!e.button(tree,'Publish pricing'));});
test('an uncertain publication exposes Retry beside the message and repeats the exact request',async()=>{let attempts=0;const e=editor([{...row}],async()=>++attempts===1?Response.json({ok:false,message:'Save not confirmed. Retry.'},{status:503}):Response.json({ok:true,id,version:2,published:true}));e.button(e.render(),'Publish pricing').props.onClick();await settle();let tree=e.render();assert(text(e.nodes(tree).find(n=>n.props.role==='alert')).includes('not confirmed'));assert.equal(e.nodes(tree).find(n=>n.props['aria-label']==='Set all priced per').props.disabled,true);e.button(tree,'Retry same save').props.onClick();await settle();const writes=e.calls.filter(c=>c.body);assert.equal(writes.length,2);assert.equal(writes[0].body,writes[1].body);assert(text(e.render()).includes('Published. Current prices are searchable.'));});

test('Set all priced per updates the entire sheet, keeps prices and quantities, and requires review only for changed units',async()=>{
 const rows=Array.from({length:25},(_,i)=>({...row,unit:i===0?'each':i===1?'linear_ft':'',price:20+i,quantity:i+1}));
 const e=editor(rows);let tree=e.render(),selector=e.nodes(tree).find(n=>n.type==='select'&&n.props['aria-label']==='Set all priced per');assert.equal(selector.props.disabled,false);assert.equal(selector.props.value,'');selector.props.onChange({target:{value:'each'}});
 tree=e.render();assert.equal(e.nodes(tree).find(n=>n.props['aria-label']==='Set all priced per').props.value,'each');assert(text(tree).includes('all 25 items'));
 e.button(tree,'Next items').props.onClick();tree=e.render();assert.equal(e.nodes(tree).filter(n=>n.type==='select'&&n.props['aria-label']!=='Set all priced per').length,5);assert(e.nodes(tree).filter(n=>n.type==='select').every(n=>n.props.value==='each'));
 e.button(tree,'Save draft').props.onClick();await settle();const saved=JSON.parse(e.calls.find(c=>c.body).body).rows;assert.equal(saved.length,25);assert(saved.every(r=>r.unit==='each'));assert.equal(saved[0].confirmed,true);assert(saved.slice(1).every(r=>r.confirmed===false));for(let i=0;i<25;i++){assert.equal(saved[i].price,rows[i].price);assert.equal(saved[i].quantity,rows[i].quantity);}
});
