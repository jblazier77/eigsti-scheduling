import {spawn} from 'node:child_process';
// Emit only SQLSTATE + our fixed stage marker. Never expose native stderr, SQL or credentials.
export function demoFailure(stderr){const match=stderr.match(/EIGSTI_DEMO_FAILURE:([A-Z0-9]{5}):([a-z_]+)/);if(match)return 'Demo database error ['+match[1]+'] during '+match[2]+'. No demo transaction was committed.';const state=stderr.match(/(?:ERROR|FATAL):\s+([A-Z0-9]{5}):/);return state?'Demo PostgreSQL error ['+state[1]+']. No successful installation is confirmed.':'Demo PostgreSQL operation failed. Private details were suppressed.';}
export function runDemoPostgres(binary,args,env){return new Promise((accept,reject)=>{
 const child=spawn(binary,args,{env,windowsHide:true,stdio:['ignore','pipe','pipe']});let out='',errors='';let settled=false;
 const fail=message=>{if(!settled){settled=true;reject(new Error(message));}};
 const timer=setTimeout(()=>{child.kill();fail('Demo database operation timed out. Rerun to check safely.');},120000);
 child.stdout.on('data',b=>{if(out.length<1024*1024)out+=b.toString();else child.kill();});child.stderr.on('data',b=>{if(errors.length<65536)errors+=b.toString();});
 child.on('error',()=>{clearTimeout(timer);fail('PostgreSQL tools could not be started.');});
 child.on('close',code=>{clearTimeout(timer);if(code===0&&!settled){settled=true;accept(out);}else fail(demoFailure(errors));});
});}
