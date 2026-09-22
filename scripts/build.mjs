import {writeFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
const sourceSha=execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim();
const dirty=!!execFileSync('git',['status','--porcelain'],{encoding:'utf8'}).trim();
writeFileSync('public/build-info.json',JSON.stringify({sourceSha,dirty},null,2)+'\n');
execFileSync(process.execPath,['node_modules/vite/bin/vite.js','build','--base=./'],{stdio:'inherit'});
