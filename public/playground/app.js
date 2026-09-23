import {effects,standalone,defaults} from './registry.js';
import {fixtures,fixtureById,sceneDefaults,screenToWorld} from './fixtures.js';
import {createEffectLayer,renderScene} from './scene.js';
import {PluginHost} from './plugin-host.js';
const $=id=>document.getElementById(id),canvas=$('stage'),g=canvas.getContext('2d'),layer=createEffectLayer();
const scene=sceneDefaults(),params=new URLSearchParams(location.search);
const number=(key,fallback,min,max)=>{const v=Number(params.get(key));return params.has(key)&&Number.isFinite(v)?Math.max(min,Math.min(max,v)):fallback;};
let effect=effects.find(a=>a.id===params.get('skill'))||effects[0],time=effect.duration*number('p',49,0,100)/100,playing=false,last=0;
scene.fixture=fixtureById(params.get('fixture')).id;scene.scale=number('scale',1.3,.6,1.8);scene.rotation=number('angle',0,0,360);scene.target={x:number('x',570,36,924),y:number('y',270,45,555)};scene.caster={x:number('cx',360,36,924),y:number('cy',330,45,555)};
for(const k of ['grid','actors','telegraph'])if(params.has(k))scene[k]=params.get(k)==='1';
let visible=params.get('visible')!=='0',local=null,localSource=null,bitmap=null,bitmapTime=-1,lastBuiltin=effect.id;
const host=new PluginHost((next,t)=>{bitmap?.close();bitmap=next;bitmapTime=t;if(effect.local)render();},message=>{removeLocal();notice('本地技能未接入：'+message);});
function option(value,text){const e=document.createElement('option');e.value=value;e.textContent=text;return e;}
function notice(text){$('notice').textContent=text;}
function persist(){if(effect.local)return;const p=new URLSearchParams({skill:effect.id,fixture:scene.fixture,p:(100*time/effect.duration).toFixed(1),scale:scene.scale,angle:scene.rotation,x:Math.round(scene.target.x),y:Math.round(scene.target.y),cx:Math.round(scene.caster.x),cy:Math.round(scene.caster.y),grid:+scene.grid,actors:+scene.actors,telegraph:+scene.telegraph,visible:+visible});history.replaceState(null,'',`${location.pathname}?${p}`);}
function sync(){
 $('skill').value=effect.id;$('skill-name').textContent=effect.name;$('skill-origin').textContent=effect.origin||'本地隔离插件';$('motion').textContent=effect.description||effect.motion||'自包含 Canvas 绘制模块';$('source-link').href=effect.local?localSource:new URL(effect.source,location.href).href;
 $('fixture').value=scene.fixture;$('fixture-caption').textContent=fixtureById(scene.fixture).name;$('fixture-description').textContent=fixtureById(scene.fixture).description;
 $('scale').value=scene.scale;$('scale-value').textContent=scene.scale.toFixed(1)+'×';$('angle').value=scene.rotation;$('angle-value').textContent=scene.rotation+'°';for(const k of ['actors','telegraph','grid'])$(k).checked=scene[k];$('effect-visible').checked=visible;
 $('play').textContent=playing?'暂停技能':'播放技能';$('play').setAttribute('aria-pressed',String(playing));$('seek').value=100*time/effect.duration;$('time').textContent=`${time.toFixed(2)} / ${effect.duration.toFixed(2)} s`;
 canvas.dataset.effect=effect.id;canvas.dataset.time=time.toFixed(6);canvas.dataset.playing=String(playing);canvas.dataset.fixture=scene.fixture;canvas.dataset.target=JSON.stringify(scene.target);canvas.dataset.caster=JSON.stringify(scene.caster);
 document.querySelectorAll('.effect-card').forEach(c=>c.classList.toggle('active',c.dataset.id===effect.id));
}
function render(){
 if(effect.local&&visible&&bitmapTime!==time)host.render(time,{...defaults,scale:1});
 renderScene(g,scene,effect,time,{layer,bitmap:effect.local?bitmap:null,visible});
 canvas.dataset.renderTime=(effect.local?bitmapTime:time).toFixed(6);sync();
}
function selectEffect(id){const next=effects.find(a=>a.id===id)||(local?.id===id?local:null);if(!next)return;effect=next;if(!next.local)lastBuiltin=id;playing=false;time=effect.duration*.49;render();persist();}
function seek(percent){playing=false;time=effect.duration*Math.max(0,Math.min(100,percent))/100;render();persist();}
for(const f of fixtures)$('fixture').append(option(f.id,f.name));for(const a of effects)$('skill').append(option(a.id,`${a.number?String(a.number).padStart(2,'0')+' · ':''}${a.name}`));
$('effect-count').textContent=String(effects.length);$('skill').addEventListener('change',e=>selectEffect(e.target.value));
$('fixture').addEventListener('change',e=>{scene.fixture=e.target.value;render();persist();});
$('play').onclick=()=>{if(time>=effect.duration)time=0;playing=!playing;last=performance.now();render();persist();};
$('replay').onclick=()=>{time=0;playing=true;last=performance.now();render();persist();};
$('seek').addEventListener('input',e=>seek(Number(e.target.value)));
for(const b of document.querySelectorAll('[data-progress]'))b.onclick=()=>seek(Number(b.dataset.progress));
$('scale').oninput=e=>{scene.scale=Number(e.target.value);render();persist();};$('angle').oninput=e=>{scene.rotation=Number(e.target.value);render();persist();};
for(const k of ['actors','telegraph','grid'])$(k).onchange=e=>{scene[k]=e.target.checked;render();persist();};$('effect-visible').onchange=e=>{visible=e.target.checked;render();persist();};
$('reset-scene').onclick=()=>{Object.assign(scene,sceneDefaults());visible=true;render();persist();};
canvas.addEventListener('pointerdown',e=>{const point=screenToWorld(e.clientX,e.clientY,canvas.getBoundingClientRect());scene[e.shiftKey||$('pointer').value==='caster'?'caster':'target']=point;canvas.focus({preventScroll:true});render();persist();});
canvas.addEventListener('keydown',e=>{const dirs={ArrowUp:[0,-12],ArrowDown:[0,12],ArrowLeft:[-12,0],ArrowRight:[12,0]};if(!dirs[e.key])return;e.preventDefault();const[x,y]=dirs[e.key];scene.caster.x=Math.max(36,Math.min(924,scene.caster.x+x));scene.caster.y=Math.max(45,Math.min(555,scene.caster.y+y));render();persist();});
$('share').onclick=async()=>{if(effect.local){notice('本地插件不上传，不能通过链接共享。请选择仓库技能。');return;}persist();try{await navigator.clipboard.writeText(location.href);notice('已复制当前场景、技能、落点与时间。');}catch{notice('复制此链接：'+location.href);}};
function frame(now){if(playing){const dt=Math.max(0,Math.min(.1,(now-last)/1000));time+=dt*Number($('speed').value);if(time>=effect.duration){if($('loop').checked)time%=effect.duration;else{time=effect.duration;playing=false;persist();}}render();}last=now;requestAnimationFrame(frame);}
document.addEventListener('visibilitychange',()=>{if(document.hidden){playing=false;sync();persist();}});
function makeCard(a){
 const card=document.createElement('article');card.className='effect-card';card.dataset.id=a.id;card.dataset.family=a.family;
 const b=document.createElement('button');b.type='button';b.setAttribute('aria-label','试放 '+a.name);b.onclick=()=>{selectEffect(a.id);canvas.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth',block:'center'});};
 const c=document.createElement('canvas');c.width=288;c.height=180;c.setAttribute('aria-hidden','true');const cg=c.getContext('2d');cg.scale(.3,.3);const s={...sceneDefaults(),target:{x:490,y:270},caster:{x:350,y:370},scale:1.75,telegraph:false};renderScene(cg,s,a,a.duration*.49,{layer:createEffectLayer(),debug:false});b.append(c);
 const body=document.createElement('div');body.className='card-body';const tag=document.createElement('small');tag.textContent=`${a.number?String(a.number).padStart(2,'0'):'＋'} / ${a.familyName}`;const title=document.createElement('h3');title.textContent=a.name;const desc=document.createElement('p');desc.textContent=a.motion||a.description;body.append(tag,title,desc);b.append(body);card.append(b);
 const meta=document.createElement('div');meta.className='card-meta';const duration=document.createElement('span');duration.textContent=a.duration.toFixed(1)+' s';const src=document.createElement('a');src.textContent='.js ↗';src.href=a.source;src.target='_blank';src.rel='noreferrer';src.setAttribute('aria-label',a.name+' 源码');meta.append(duration,src);card.append(meta);return card;
}
for(const a of effects)$('cards').append(makeCard(a));for(const [id,name] of new Map(effects.map(a=>[a.family,a.familyName])))$('family').append(option(id,name));
function filter(){const q=$('search').value.trim().toLowerCase(),family=$('family').value;let count=0;for(const card of $('cards').children){const a=effects.find(v=>v.id===card.dataset.id);const match=(family==='all'||a.family===family)&&`${a.name} ${a.description} ${a.motion} ${a.id} ${a.familyName}`.toLowerCase().includes(q);card.hidden=!match;if(match)count++;}$('catalog-count').textContent=`${count} / ${effects.length}`;$('empty').hidden=count>0;}
$('search').oninput=filter;$('family').onchange=filter;$('clear-filter').onclick=()=>{$('search').value='';$('family').value='all';filter();};filter();
for(const a of standalone){const el=document.createElement('article');el.className='runtime';const type=document.createElement('p');type.className='eyebrow';type.textContent=a.type;const h=document.createElement('h3');h.textContent=a.name;const p=document.createElement('p');p.textContent=a.note;const link=document.createElement('a');link.href=a.url;link.textContent='打开运行时 ↗';const src=document.createElement('a');src.href=a.source;src.textContent='源码 ↗';el.append(type,h,p,link,src);$('standalone').append(el);}
function removeLocal(){host.dispose();bitmap?.close();bitmap=null;bitmapTime=-1;if(localSource)URL.revokeObjectURL(localSource);localSource=null;document.querySelector('option[data-local]')?.remove();const wasLocal=effect.local;local=null;$('remove-plugin').hidden=true;if(wasLocal)selectEffect(lastBuiltin);}
async function importFile(file){if(!file)return;try{playing=false;notice('正在隔离环境中检查本地模块…');const meta=await host.load(file);bitmap?.close();bitmap=null;bitmapTime=-1;if(localSource)URL.revokeObjectURL(localSource);localSource=URL.createObjectURL(file);document.querySelector('option[data-local]')?.remove();local={...meta,id:'local-effect',local:true,origin:'本地 · 不上传',description:'隔离 Worker 中运行；此模块不会写入仓库。'};const o=option(local.id,'本地 · '+meta.name);o.dataset.local='1';$('skill').append(o);$('remove-plugin').hidden=false;selectEffect(local.id);notice('已接入本地 .js；可播放、倒退采样或切换场景。');}catch(e){notice('导入被拒绝：'+e.message);}}
$('plugin-file').onchange=e=>{importFile(e.target.files[0]);e.target.value='';};$('remove-plugin').onclick=()=>{removeLocal();notice('已移除本地技能。');};
const drop=$('drop-zone');for(const evt of ['dragenter','dragover'])drop.addEventListener(evt,e=>{e.preventDefault();drop.classList.add('dragover');});for(const evt of ['dragleave','drop'])drop.addEventListener(evt,e=>{e.preventDefault();drop.classList.remove('dragover');});drop.addEventListener('drop',e=>importFile(e.dataTransfer.files[0]));
async function json(path){const r=await fetch(path);if(!r.ok)throw new Error(`${path}: HTTP ${r.status}`);return r.json();}
json('../build-info.json').then(b=>{$('build').textContent=`${b.sourceSha.slice(0,8)}${b.dirty?' · 工作树候选':' · 已提交构建'}`;$('build').dataset.sha=b.sourceSha;}).catch(()=>$('build').textContent='版本信息不可用');
json('./source-index.json').then(data=>{$('source-count').textContent=`${data.files.length} 个模块`;for(const f of data.files){const row=document.createElement('div');row.className='source-row';const link=document.createElement('a');link.href=f.url;link.textContent=f.path;link.target='_blank';link.rel='noreferrer';const type=document.createElement('span');type.textContent=f.kind;row.append(link,type);$('source-files').append(row);}}).catch(e=>{$('source-files').textContent='源码索引未生成：'+e.message;});
json('./sources.json').then(data=>{for(const s of data.sources.filter(s=>s.featured)){const el=document.createElement('article');el.className='reference';const status=document.createElement('small');status.textContent=s.evidence+' / '+s.date;const h=document.createElement('h3');h.textContent=s.title;const p=document.createElement('p');p.textContent=s.observation;const link=document.createElement('a');link.href=s.url;link.textContent='查看原始来源 ↗';link.target='_blank';link.rel='noreferrer';el.append(status,h,p,link);$('reference-cards').append(el);}}).catch(e=>{$('reference-cards').textContent='来源读取失败：'+e.message;});
window.addEventListener('pagehide',()=>{host.destroy();bitmap?.close();if(localSource)URL.revokeObjectURL(localSource);});
render();requestAnimationFrame(frame);
