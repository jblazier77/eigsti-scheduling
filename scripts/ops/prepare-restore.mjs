import {existsSync,promises as fs} from 'node:fs';
import {resolve} from 'node:path';
import {openArchive,outsideRepository} from './archive.mjs';
// Extract only. Never connects to or changes any database.
try {
 if(existsSync('.env.ops.local'))process.loadEnvFile('.env.ops.local');
 const [file,directory]=process.argv.slice(2);if(!file||!directory)throw new Error();
 const destination=outsideRepository(directory,resolve('.'));
 outsideRepository(await fs.realpath(resolve(destination,'..')),await fs.realpath('.'));
 const manifest=await openArchive(file,destination,process.env.EIGSTI_BACKUP_PASSPHRASE);
 console.log(JSON.stringify({extracted:true,project_ref:manifest.project_ref,destination,storage_objects:manifest.storage_objects.length,database_restore_verified:false,warning:'Contains private Auth recovery data. Use only for an operator-reviewed isolated restore; remove decrypted copies afterward.'},null,2));
}catch{console.error('Extraction failed. Use a new private folder outside Git and the correct passphrase. Any partially extracted folder is unverified and must not be used.');process.exitCode=1;}
