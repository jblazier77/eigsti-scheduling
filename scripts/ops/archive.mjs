// Operator-only encrypted recovery archive. Never import from application code.
import {createCipheriv,createDecipheriv,randomBytes,scryptSync,createHash} from 'node:crypto';
import {createReadStream,createWriteStream} from 'node:fs';
import {promises as fs} from 'node:fs';
import {Readable,Transform} from 'node:stream';
import {pipeline} from 'node:stream/promises';
import {resolve,join,dirname,basename,relative,sep,isAbsolute} from 'node:path';
import {tmpdir} from 'node:os';
const MAGIC=Buffer.from('EIGSTI01'),MAX_TOTAL=64*1024**3;
export function requirePassphrase(value){if(typeof value!=='string'||value.length<32)throw new Error('A backup passphrase of at least 32 characters is required.');return value;}
export function safeEntry(name){if(typeof name!=='string'||name.length>300||!/[a-z0-9]/i.test(name)||!/^[a-zA-Z0-9._/-]+$/.test(name)||name.split('/').some(p=>!p||p==='.'||p==='..'||p.endsWith('.')||/^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(p)))throw new Error('Unsafe archive path.');return name;}
export function outsideRepository(path,repository){const target=resolve(path),rel=relative(resolve(repository),target);if(!rel||(!isAbsolute(rel)&&rel!=='..'&&!rel.startsWith('..'+sep)))throw new Error('Recovery files must be stored outside the repository.');return target;}
export async function hashFile(path){const hash=createHash('sha256');for await(const chunk of createReadStream(path))hash.update(chunk);return hash.digest('hex');}
export async function removeTemporary(path,base=tmpdir()){
 const actual=await fs.realpath(path),parent=await fs.realpath(base),info=await fs.lstat(path);
 if(info.isSymbolicLink()||dirname(actual)!==parent||!basename(actual).startsWith('eigsti-ops-'))throw new Error('Temporary cleanup path rejected.');
 await fs.rm(actual,{recursive:true,force:true});
}
export async function sealArchive(root,names,output,passphrase){
 requirePassphrase(passphrase);const unique=new Set(names);if(unique.size!==names.length)throw new Error('Duplicate archive entries.');
 const salt=randomBytes(16),iv=randomBytes(12),header=Buffer.concat([MAGIC,salt,iv]);
 const cipher=createCipheriv('aes-256-gcm',scryptSync(passphrase,salt,32),iv);cipher.setAAD(header);
 async function* records(){let total=0;for(const name of names){safeEntry(name);const file=join(root,...name.split('/')),info=await fs.lstat(file);if(!info.isFile()||info.isSymbolicLink()||info.size>MAX_TOTAL||(total+=info.size)>MAX_TOTAL)throw new Error('Invalid or oversized recovery file.');const data=Buffer.from(JSON.stringify({path:name,size:info.size}));const size=Buffer.alloc(4);size.writeUInt32BE(data.length);yield size;yield data;for await(const chunk of createReadStream(file))yield chunk;}yield Buffer.alloc(4);}
 const frame=new Transform({construct(done){this.push(header);done();},transform(chunk,encoding,done){done(null,chunk);},flush(done){this.push(cipher.getAuthTag());done();}});
 await pipeline(Readable.from(records()),cipher,frame,createWriteStream(output,{flags:'wx',mode:0o600}));
 return hashFile(output);
}
async function readExactly(handle,length,position){const b=Buffer.alloc(length);let done=0;while(done<length){const {bytesRead}=await handle.read(b,done,length-done,position+done);if(!bytesRead)throw new Error('Truncated recovery archive.');done+=bytesRead;}return b;}
export async function openArchive(file,destination,passphrase){
 requirePassphrase(passphrase);const info=await fs.stat(file);if(info.size<56||info.size>MAX_TOTAL+64*1024**2)throw new Error('Invalid recovery archive size.');
 const input=await fs.open(file,'r');let header,tag;try{header=await readExactly(input,36,0);tag=await readExactly(input,16,info.size-16);}finally{await input.close();}
 if(!header.subarray(0,8).equals(MAGIC))throw new Error('Unknown recovery archive format.');
 // Authenticate completely BEFORE interpreting or writing any supplied entry paths.
 const temp=await fs.mkdtemp(join(tmpdir(),'eigsti-ops-decrypt-'));const plain=join(temp,'authenticated.frames');
 try{
  const decipher=createDecipheriv('aes-256-gcm',scryptSync(passphrase,header.subarray(8,24),32),header.subarray(24,36));decipher.setAAD(header);decipher.setAuthTag(tag);
  let bytes=0;const limit=new Transform({transform(chunk,encoding,callback){bytes+=chunk.length;callback(bytes>MAX_TOTAL+64*1024**2?new Error('Recovery archive exceeds limit.'):null,chunk);}});
  try{await pipeline(createReadStream(file,{start:36,end:info.size-17}),decipher,limit,createWriteStream(plain,{flags:'wx',mode:0o600}));}catch{throw new Error('Recovery archive authentication failed; check the passphrase and file integrity.');}
  await fs.mkdir(destination,{recursive:false,mode:0o700});
  const fd=await fs.open(plain,'r');const size=(await fd.stat()).size;let offset=0,total=0;const extracted=new Map();
  try{
   for(;;){const length=(await readExactly(fd,4,offset)).readUInt32BE();offset+=4;if(!length){if(offset!==size)throw new Error('Unexpected trailing recovery data.');break;}
    if(length>4096||extracted.size>10000)throw new Error('Recovery archive entry limit.');
    let entry;try{entry=JSON.parse((await readExactly(fd,length,offset)).toString('utf8'));}catch{throw new Error('Invalid recovery entry.');}offset+=length;
    const name=safeEntry(entry.path);if(extracted.has(name)||!Number.isSafeInteger(entry.size)||entry.size<0||(total+=entry.size)>MAX_TOTAL||offset+entry.size>size)throw new Error('Invalid recovery entry size or duplicate.');
    const target=join(destination,...name.split('/'));await fs.mkdir(dirname(target),{recursive:true,mode:0o700});
    if(entry.size)await pipeline(createReadStream(plain,{start:offset,end:offset+entry.size-1}),createWriteStream(target,{flags:'wx',mode:0o600}));else await fs.writeFile(target,'',{flag:'wx',mode:0o600});
    offset+=entry.size;extracted.set(name,{size:entry.size,sha256:await hashFile(target)});
   }
  }finally{await fd.close();}
  const manifest=JSON.parse(await fs.readFile(join(destination,'manifest.json'),'utf8'));
  if(manifest.format!==1||!/^[a-z]{20}$/.test(manifest.project_ref)||!Array.isArray(manifest.files)||!Array.isArray(manifest.storage_objects)||manifest.files.length+1!==extracted.size)throw new Error('Invalid recovery manifest.');
  const listed=new Set();for(const entry of manifest.files){safeEntry(entry.path);if(listed.has(entry.path)||entry.path==='manifest.json')throw new Error('Duplicate manifest record.');listed.add(entry.path);const actual=extracted.get(entry.path);if(!actual||actual.sha256!==entry.sha256||actual.size!==entry.size)throw new Error('Recovery content checksum mismatch.');}
  if(!listed.has('database.dump')||!listed.has('source-inventory.json'))throw new Error('Recovery package is missing required database records.');
  const objects=new Set();for(const object of manifest.storage_objects){if(!/^[a-f0-9-]{36}\/[a-f0-9-]{36}$/i.test(object.key)||objects.has((object.bucket??'eigsti-job-files')+'/'+object.key)||!['eigsti-job-files','vendor-price-sheets'].includes(object.bucket??'eigsti-job-files')||object.path!=='storage/'+(object.bucket==='vendor-price-sheets'?'vendor-price-sheets/':'')+object.key)throw new Error('Invalid storage manifest.');objects.add((object.bucket??'eigsti-job-files')+'/'+object.key);const actual=extracted.get(object.path);if(!actual||actual.sha256!==object.sha256||actual.size!==object.size)throw new Error('Storage recovery checksum mismatch.');}
  if([...listed].filter(name=>name.startsWith('storage/')).length!==objects.size)throw new Error('Unlisted storage recovery content.');
  return manifest;
 }finally{await removeTemporary(temp);}
}
export async function verifyArchive(file,passphrase){const temp=await fs.mkdtemp(join(tmpdir(),'eigsti-ops-verify-'));try{const manifest=await openArchive(file,join(temp,'content'),passphrase);return {format:manifest.format,run_id:manifest.run_id,project_ref:manifest.project_ref,files:manifest.files.length,storage_objects:manifest.storage_objects.length,sha256:await hashFile(file),integrity_verified:true,database_restore_verified:false};}finally{await removeTemporary(temp);}}
