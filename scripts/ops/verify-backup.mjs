import {existsSync} from 'node:fs';
import {verifyArchive} from './archive.mjs';
try {
 if(existsSync('.env.ops.local'))process.loadEnvFile('.env.ops.local');
 if(!process.argv[2])throw new Error();
 console.log(JSON.stringify(await verifyArchive(process.argv[2],process.env.EIGSTI_BACKUP_PASSPHRASE),null,2));
}catch{console.error('Backup verification failed. Check the file and private passphrase; no restore is confirmed.');process.exitCode=1;}
