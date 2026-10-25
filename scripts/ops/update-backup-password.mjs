// Updates only the local operator database password; never logs submitted input.
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
export function withDatabasePassword(connection,encoded){
 const password=decodeURIComponent(encoded);
 if(!password||password.length>1024||/[\x00-\x1f\x7f]/.test(password))throw Error('Invalid password input.');
 const url=new URL(connection);
 if(!['postgres:','postgresql:'].includes(url.protocol))throw Error('Invalid database connection.');
 url.password=encodeURIComponent(password);
 return url.href;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 try{
  // Caller URL-encodes before piping, avoiding legacy PowerShell native-pipe
  // character conversion. It is decoded and encoded once here.
  let input='';for await(const chunk of process.stdin){input+=chunk.toString('ascii');if(input.length>16384)throw Error();}
  input=input.replace(/\r?\n$/,'');
  process.loadEnvFile('.env.ops.local');
  const file='.env.ops.local',text=fs.readFileSync(file,'utf8');
  const pattern=/^EIGSTI_BACKUP_DB_URL=.*$/gm;
  if((text.match(pattern)||[]).length!==1)throw Error();
  const connection=withDatabasePassword(process.env.EIGSTI_BACKUP_DB_URL,input);
  fs.writeFileSync(file,text.replace(pattern,()=> 'EIGSTI_BACKUP_DB_URL='+JSON.stringify(connection)),{mode:0o600});
  console.log('Database password updated privately.');
 }catch{console.error('Private password update failed. No submitted values were displayed.');process.exitCode=1;}
}
