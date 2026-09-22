import {readFile,writeFile,mkdir,rm,copyFile} from 'node:fs/promises';import {execFileSync} from 'node:child_process';import {createHash} from 'node:crypto';
execFileSync('python3',['scripts/generate-sprites.py']);
const dest='public/assets/qinglan/v2/qinglan-v2-runtime.zip',tmp='.asset-package-tmp';
await rm(tmp,{recursive:true,force:true});await mkdir(tmp,{recursive:true});
const files={
 'models/qinglan-v1-source.glb':'public/assets/qinglan/v1/qinglan-sword-formation.glb',
 'runtime/qinglan-vfx.js':'src/qinglan-vfx.js','runtime/timeline.js':'src/timeline.js','runtime/shaders.js':'src/shaders.js',
 'asset-spec.json':'public/assets/qinglan/v2/asset-spec.json','sprites/ink-burst-atlas.png':'public/assets/qinglan/v2/ink-burst-atlas.png','sprites/sprite-manifest.json':'public/assets/qinglan/v2/sprite-manifest.json',
 'INTEGRATION.md':'docs/qinglan-v2.md','THREE-LICENSE.txt':'node_modules/three/LICENSE'};
const hashes={};for(const [name,source] of Object.entries(files)){await mkdir(`${tmp}/${name.split('/').slice(0,-1).join('/')}`,{recursive:true});await copyFile(source,`${tmp}/${name}`);hashes[name]=createHash('sha256').update(await readFile(source)).digest('hex');}
const spec=JSON.parse(await readFile(`${tmp}/asset-spec.json`));spec.canonical_reference='models/qinglan-v1-source.glb';await writeFile(`${tmp}/asset-spec.json`,JSON.stringify(spec,null,2)+'\n');hashes['asset-spec.json']=createHash('sha256').update(await readFile(`${tmp}/asset-spec.json`)).digest('hex');
await writeFile(`${tmp}/manifest.json`,JSON.stringify({id:'qinglan-vfx',version:'2.0.0',runtime:'three@0.170.0',entry:'runtime/qinglan-vfx.js',model:'models/qinglan-v1-source.glb',duration:3.2,glb_is_v1_source:true,v2_effects_require_runtime:true,sha256:hashes},null,2)+'\n');
await rm(dest,{force:true});execFileSync('zip',['-q','-r',`../${dest}`,'.'],{cwd:tmp});await rm(tmp,{recursive:true});console.log(`Packaged ${Object.keys(files).length} assets + manifest: ${dest}`);
