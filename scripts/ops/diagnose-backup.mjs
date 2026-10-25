// Read-only source probe. Reports fixed codes, never connection strings or stderr.
import {existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {backupConfig,runTool,holdSnapshot,validateInventory} from './backup-core.mjs';
import {safeFailure} from './failures.mjs';
let stage='configuration';
try{
 if(existsSync('.env.ops.local'))process.loadEnvFile('.env.ops.local');
 const config=backupConfig(process.env,resolve('.'));
 if(!config.pg.PGSSLROOTCERT||!existsSync(config.pg.PGSSLROOTCERT))throw Object.assign(Error(),{code:'CERTIFICATE_MISSING'});
 stage='secure connection';console.log('Checking secure database connection...');
 const version=await runTool(config.psql,['--no-psqlrc','--no-password','--tuples-only','--no-align','--set','ON_ERROR_STOP=1','--command',"select current_setting('server_version_num');"],config.pg);
 if(!/^\d+$/.test(version.trim()))throw Error();
 stage='read-only snapshot and file inventory';console.log('Secure connection passed. Checking read-only snapshot...');
 const held=await holdSnapshot(config);try{validateInventory(held.inventory);}finally{await held.close();}
 console.log('Connection, snapshot and file inventory passed. No export or restore performed.');
}catch(error){console.error('Diagnostic stopped at '+stage+'. '+safeFailure(error));process.exitCode=1;}
