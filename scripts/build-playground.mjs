import {readdirSync,writeFileSync,copyFileSync} from 'node:fs';
import {join} from 'node:path';
import {effects} from '../public/playground/registry.js';
const paths=[];
function walk(dir){for(const e of readdirSync(dir,{withFileTypes:true})){const p=join(dir,e.name).replaceAll('\\','/');if(e.isDirectory())walk(p);else if(p.endsWith('.js'))paths.push(p);}}
walk('public');walk('src');
const effectPaths=new Set(effects.map(a=>new URL(a.source,new URL('../public/playground/',import.meta.url)).pathname.split('/public/')[1]));
const files=paths.sort().map(path=>({path,url:path.startsWith('public/')?'../'+path.slice(7):'https://github.com/liush2yuxjtu/create-game-asset/blob/main/'+path,kind:effectPaths.has(path.slice(7))?'透明技能模块':/crane\.js|motion\.js/.test(path)?'完整场景绘制':path==='src/qinglan-vfx.js'?'WebGL技能':/preview\.js|gallery\.js|app\.js|main\.js/.test(path)?'播放器 / 页面':'支撑模块'}));
writeFileSync('public/playground/source-index.json',JSON.stringify({schemaVersion:1,effectCount:effects.length,files},null,2)+'\n');
copyFileSync('design.md','public/playground/design.md');
console.log(`Playground index: ${files.length} JS files; ${effects.length} compatible effects.`);
