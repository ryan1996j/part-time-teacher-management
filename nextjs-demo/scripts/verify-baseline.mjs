import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';
const manifest=JSON.parse(fs.readFileSync('docs/baseline-assets.json','utf8'));let failed=0;
for(const [name,hash] of Object.entries(manifest)){const p=path.join('public/legacy',name);if(!fs.existsSync(p)||crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex')!==hash){console.error('Mismatch:',name);failed++}}
if(failed)process.exit(1);console.log(`PASS: ${Object.keys(manifest).length} prototype assets unchanged`);
