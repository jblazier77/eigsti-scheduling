// Standalone, fictional design review only; no database/auth/app mutations.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
const source=readFileSync(new URL('../src/app/components/job-markers.tsx',import.meta.url),'utf8');
const paths=Object.fromEntries([...source.matchAll(/^\s+(\w+):'([^']+)'/gm)].map(m=>[m[1],m[2]]));
const aliases={'cloud-rain':'rain','house':'house','align-justify':'siding','panels-top-left':'windows_doors','hammer':'framing','zap':'electrical','wrench':'general','fan':'hvac','square':'drywall','paint-roller':'painting','columns-3':'flooring','archive':'cabinetry','grid-2x2':'tile','brick-wall':'concrete','sprout':'landscaping'};
const icons=Object.fromEntries(Object.entries(aliases).map(([key,value])=>[key,paths[value]]));
let fragment=readFileSync(new URL('../eigsti-job-layout-proposal.html',import.meta.url),'utf8').replaceAll('\uFFFD','·');
const localIcons=`<script>
window.lucide={createIcons(){const paths=${JSON.stringify(icons)};document.querySelectorAll('[data-lucide]').forEach(mark=>{const path=paths[mark.dataset.lucide];if(!path){mark.remove();return;}const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('fill','none');svg.setAttribute('stroke','currentColor');svg.setAttribute('stroke-width','1.6');svg.setAttribute('stroke-linecap','round');svg.setAttribute('stroke-linejoin','round');svg.setAttribute('aria-hidden','true');const p=document.createElementNS('http://www.w3.org/2000/svg','path');p.setAttribute('d',path);svg.append(p);mark.replaceWith(svg);});}};
</script>`;
fragment=fragment.replace('<script>',localIcons+'<script>');
const html='<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Eigsti job layout proposal</title><style>body{margin:0;background:light-dark(#e8eee9,#121914);color-scheme:light dark;font-family:Arial,sans-serif}</style></head><body>'+fragment+'</body></html>';
mkdirSync(new URL('../public/previews/',import.meta.url),{recursive:true});
writeFileSync(new URL('../public/previews/job-details.html',import.meta.url),html);
console.log('Prepared standalone job-details design preview.');
