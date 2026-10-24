import {existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {backupConfig,createBackup,runTool} from './backup-core.mjs';
// Operator secrets stay separate from Next's environment files.
try {
 if(existsSync('.env.ops.local'))process.loadEnvFile('.env.ops.local');
 const config=backupConfig(process.env,resolve('.'));
 if(process.argv.includes('--check')) {
  await Promise.all([config.psql,config.dump,config.restore].map(binary=>runTool(binary,['--version'],config.pg)));
  console.log(JSON.stringify({configuration_valid:true,tools_available:true,project_ref:config.ref,live_backup_verified:false}));
 }else console.log(JSON.stringify(await createBackup(config),null,2));
}catch{console.error('Backup did not complete. Check private configuration, PostgreSQL tools and source access. No complete recovery package is confirmed.');process.exitCode=1;}
