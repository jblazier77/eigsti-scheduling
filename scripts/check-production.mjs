// A fresh output directory avoids locked Windows caches and leaves dev output alone.
import {promises as fs} from 'node:fs';
import {spawn} from 'node:child_process';
import {randomBytes} from 'node:crypto';
const config='.tsconfig-check.json',directory='.next-check-'+randomBytes(8).toString('hex');let created=false;
try{
 await fs.writeFile(config,JSON.stringify({extends:'./tsconfig.json',compilerOptions:{incremental:false},include:['next-env.d.ts','src/**/*.ts','src/**/*.tsx',directory+'/types/**/*.ts']}),{flag:'wx'});created=true;
 const code=await new Promise((done,reject)=>{const child=spawn(process.execPath,['node_modules/next/dist/bin/next','build'],{env:{...process.env,EIGSTI_BUILD_DIRECTORY:directory},stdio:'inherit',windowsHide:true});child.on('error',reject);child.on('exit',code=>done(code??1));});
 process.exitCode=code;
}catch{console.error('Isolated build failed. If another verification build is running, let it finish first.');process.exitCode=1;}
finally{if(created)await fs.unlink(config);}
