import {checkHost} from './host-core.mjs';
try{const report=await checkHost(process.argv[2]);console.log(JSON.stringify(report,null,2));if(!report.passed)process.exitCode=1;}catch{console.error('Hosting check failed. Supply a deployed HTTPS origin; check hosting access and environment settings.');process.exitCode=1;}
