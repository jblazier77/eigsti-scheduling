import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
const require=createRequire(import.meta.url),swc=require('next/dist/build/swc');
test('employee and trade routes refresh session cookies and retain private cache headers on cookie renewal',async()=>{
 const source=readFileSync(new URL('../src/proxy.ts',import.meta.url),'utf8');
 const code=swc.transformSync(source,{filename:'proxy.ts',jsc:{parser:{syntax:'typescript'},target:'es2022'},module:{type:'commonjs'}}).code;
 const exports={},options=[];let requests=0;
 const request={cookies:{getAll:()=>[],set:()=>{}}};
 const next=()=>({headers:new Map(),cookies:{set:(...args)=>options.push(args)}});
 runInNewContext(code,{exports,require:name=>name==='@supabase/ssr'?{createServerClient:(url,key,config)=>({auth:{getClaims:async()=>{requests++;assert.equal(config.cookieOptions.httpOnly,true);assert.equal(config.cookieOptions.secure,true);config.cookies.setAll([{name:'synthetic',value:'renewed',options:{httpOnly:true}}]);}}})}:name==='next/server'?{NextResponse:{next}}:{appConfig:()=>({url:'https://synthetic.invalid',publishableKey:'synthetic'}),secureSessionCookies:()=>true}});
 for(const route of ['/employees/:path*','/subcontractors/:path*'])assert(exports.config.matcher.includes(route));
 const response=await exports.proxy(request);assert.equal(response.headers.get('Cache-Control'),'private, no-store');assert.equal(requests,1);assert.equal(options[0][0],'synthetic');
});
