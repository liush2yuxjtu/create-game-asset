import {mkdirSync,writeFileSync} from 'node:fs';
import {spawnSync,execFileSync} from 'node:child_process';
const report={startedAt:new Date().toISOString(),sourceSha:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),initialStatus:execFileSync('git',['status','--porcelain'],{encoding:'utf8'}).trim(),machine:'RUNNING',browser:'NOT_RUN',steps:[]};
mkdirSync('verification',{recursive:true});
function save(){writeFileSync('verification/latest.json',JSON.stringify(report,null,2)+'\n');}
save();
for(const [name,command,args] of [
 ['skill-provenance','python3',['scripts/verify-skill-sync.py']],
 ['ynjh-contract','python3',['.agents/skills/design-system/scripts/validate.py','design-systems/ynjh']],
 ['timeline','npm',['test']],['package','npm',['run','package:asset']],
 ['asset-integrity','python3',['scripts/verify-assets.py']],['build','npm',['run','build']],
 ['whitespace','git',['diff','--check']]
]){
 console.log(`\n[verify] ${name}`);const result=spawnSync(command,args,{stdio:'inherit'});
 const passed=!result.error&&result.status===0;
 report.steps.push({name,status:passed?'PASS':'FAIL',exitCode:result.status,error:result.error?.message??null});save();
 if(!passed){report.machine='FAIL';save();process.exit(1);}
}
report.machine='PASS';report.finishedAt=new Date().toISOString();save();
console.log('\nMachine PASS. Real-browser acceptance: NOT_RUN. Follow .agents/skills/verify/SKILL.md.');
