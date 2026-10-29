import {mkdirSync,copyFileSync,readdirSync,statSync,existsSync} from 'node:fs';import {join} from 'node:path';
const root='public/pricing-engine';mkdirSync(root,{recursive:true});
function copy(a,b){if(!existsSync(b)||statSync(a).size!==statSync(b).size||statSync(a).mtimeMs>statSync(b).mtimeMs)copyFileSync(a,b);}
function tree(a,b){mkdirSync(b,{recursive:true});for(const f of readdirSync(a)){const x=join(a,f),y=join(b,f);if(statSync(x).isDirectory())tree(x,y);else copy(x,y);}}
copy('node_modules/pdfjs-dist/legacy/build/pdf.worker.min.mjs',root+'/pdf.worker.min.mjs');tree('node_modules/pdfjs-dist/cmaps',root+'/cmaps');tree('node_modules/pdfjs-dist/standard_fonts',root+'/standard_fonts');copy('node_modules/tesseract.js/dist/worker.min.js',root+'/worker.min.js');mkdirSync(root+'/core',{recursive:true});for(const f of readdirSync('node_modules/tesseract.js-core'))if(f.endsWith('.wasm')||f.endsWith('.wasm.js'))copy('node_modules/tesseract.js-core/'+f,root+'/core/'+f);mkdirSync(root+'/lang',{recursive:true});copy('node_modules/@tesseract.js-data/eng/4.0.0_best_int/eng.traineddata.gz',root+'/lang/eng.traineddata.gz');

tree('node_modules/pdfjs-dist/wasm',root+'/wasm');tree('node_modules/pdfjs-dist/iccs',root+'/iccs');
