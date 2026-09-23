import {AssetController,features} from './controller.js';
import {catalog} from './catalog.js';
import {validateCatalog} from './catalog-contract.js';
import {saveConfiguration} from './persistence.js';
const $=id=>document.getElementById(id),key='jianghu-36-controller-v1';
const assets=validateCatalog(catalog),byId=new Map(assets.map(a=>[a.id,a]));
const controller=new AssetController(assets),times=new Map(assets.map(a=>[a.id,a.duration*a.previewAt]));
let scope='global',playing=false,last=0,slots=['v01','v25'];
function active(){return slots.map(id=>byId.get(id));}
function notify(message){$('notice').textContent=message;}
try{const saved=localStorage.getItem(key);if(saved)controller.restore(JSON.parse(saved));const ids=JSON.parse(localStorage.getItem(key+'-slots'));if(Array.isArray(ids)&&ids.length===2&&ids[0]!==ids[1]&&ids.every(id=>byId.has(id)))slots=ids;}catch{notify('本机配置无法读取，已使用可用设置。');}
function persist(){let saved=false;try{saved=saveConfiguration(localStorage,key,controller.snapshot(),slots);}catch{/* Access to localStorage itself may be denied. */}notify(saved?'已保存到此浏览器。':'本机保存失败；当前调整仍然有效，刷新后可能丢失。');return saved;}
const views=[0,1].map(slot=>{
 const card=document.createElement('article');card.className='card';card.innerHTML=`<div class="card-top"><label>${slot?'B':'A'}<select aria-label="预览 ${slot?'B':'A'} 技能"></select></label><span class="family-tag"></span></div><canvas width="720" height="480"></canvas><p class="asset-story"></p><div class="card-info" role="status"></div><a class="source-link" target="_blank" rel="noopener">查看独立 JS ↗</a>`;
 const select=card.querySelector('select');for(const a of assets)select.add(new Option(String(a.number).padStart(2,'0')+' · '+a.name,a.id));select.onchange=()=>selectAsset(slot,select.value);
 $('cards').append(card);return {card,select,canvas:card.querySelector('canvas'),info:card.querySelector('.card-info'),story:card.querySelector('.asset-story'),family:card.querySelector('.family-tag'),source:card.querySelector('a')};
});
function background(g,w,h){g.clearRect(0,0,w,h);g.fillStyle='#10231e';g.fillRect(0,0,w,h);const bg=g.createRadialGradient(w/2,h/2,10,w/2,h/2,w*.6);bg.addColorStop(0,'#233d32');bg.addColorStop(1,'#10231e');g.fillStyle=bg;g.fillRect(0,0,w,h);}
function selectAsset(slot,id){const other=1-slot;if(slots[other]===id)slots[other]=slots[slot];slots[slot]=id;scope=id;setPlaying(false);active().forEach(a=>times.set(a.id,a.duration*a.previewAt));refreshSlots();controls();render();persist();}
function refreshSlots(){const current=scope;$('scope').replaceChildren(new Option('全局 · 所有继承项','global'));slots.forEach((id,i)=>$('scope').add(new Option((i?'B':'A')+' · '+byId.get(id).name,id)));scope=slots.includes(current)?current:'global';$('scope').value=scope;
 slots.forEach((id,i)=>{const a=byId.get(id),v=views[i];v.select.value=id;v.canvas.setAttribute('aria-label',(i?'B':'A')+' · '+a.name+'动态预览');v.story.textContent=a.description;v.family.textContent=a.familyName;v.source.href='./variants/'+a.id+'-'+a.family+'.js';});
 document.querySelectorAll('.catalog-card').forEach(card=>{const index=slots.indexOf(card.dataset.id);card.classList.toggle('chosen',index>=0);card.querySelector('.slot-mark').textContent=index<0?'':index===0?'预览 A':'预览 B';});
}
function render(){active().forEach((a,i)=>{const {card,canvas,info}=views[i],g=canvas.getContext('2d'),o=controller.resolve(a.id),t=times.get(a.id);background(g,720,480);g.save();g.scale(1.5,1.5);a.draw(g,t,o);g.restore();card.classList.toggle('selected',scope===a.id);const n=Object.keys(controller.overrides[a.id]).length;info.textContent=`${t.toFixed(2)} / ${a.duration.toFixed(1)}s · ${o.visible!==false?'显示':'隐藏'} · ${o.motion!==false?'可推进':'已冻结'} · ${n?'覆盖 '+n+' 项':'继承全局'} · ${o.speed??1}×`;});const a=active()[0],progress=times.get(a.id)/a.duration*100;$('time').textContent=progress.toFixed(1)+'%（A）';$('seek').value=progress;$('exact-progress').value=progress.toFixed(1);}
function controls(){
 $('controls').replaceChildren();const global=scope==='global',resolved=global?controller.global:controller.resolve(scope);
 $('scope-note').textContent=global?'修改全局默认值。已有单项覆盖的设置会保持自己的值。':'默认继承全局。勾选“单独设置”后，该项可独立调整。';$('inherit').hidden=global;
 for(const [name,f] of Object.entries(features)){
  const supported=global||controller.asset(scope).supports.includes(name);if(!supported)continue;
  const row=document.createElement('div');row.className='control';const head=document.createElement('div');head.className='control-head';
  const label=document.createElement('label');label.htmlFor='feature-'+name;label.textContent=f.label;head.append(label);
  const value=resolved[name],out=document.createElement('output');out.textContent=f.type==='number'?value:'';head.append(out);
  const input=document.createElement(f.type==='select'?'select':'input');input.id='feature-'+name;
  if(f.type==='boolean'){input.type='checkbox';input.checked=value;label.prepend(input);}
  else if(f.type==='number'){input.type='range';input.min=f.min;input.max=f.max;input.step=f.step;input.value=value;}
  else for(const [v,title]of Object.entries(f.options)){const opt=new Option(title,v);input.add(opt);input.value=value;}
  const overridden=!global&&Object.hasOwn(controller.overrides[scope],name);input.disabled=!global&&!overridden;
  if(!global){const l=document.createElement('label');l.className='override';const override=document.createElement('input');override.type='checkbox';override.checked=overridden;override.setAttribute('aria-label',f.label+'单独设置');l.append(override,document.createTextNode('单独设置'));head.append(l);override.onchange=()=>{controller.setAsset(scope,name,override.checked?resolved[name]:null);persist();controls();render();};}
  input.addEventListener('input',()=>{const v=f.type==='boolean'?input.checked:f.type==='number'?Number(input.value):input.value;if(global)controller.setGlobal(name,v);else controller.setAsset(scope,name,v);out.textContent=f.type==='number'?v:'';persist();render();});
  row.append(head);if(f.type!=='boolean')row.append(input);$('controls').append(row);
 }
}
$('scope').onchange=()=>{scope=$('scope').value;controls();render();};
$('inherit').onclick=()=>{controller.clearAsset(scope);persist();controls();render();};
$('reset').onclick=()=>{controller.reset();persist();controls();render();};
function setPlaying(value){playing=value;last=performance.now();$('play').textContent=value?'暂停':'播放';}
$('play').onclick=()=>{if(!playing&&active().every(a=>times.get(a.id)>=a.duration))active().forEach(a=>times.set(a.id,0));setPlaying(!playing);};
$('restart').onclick=()=>{active().forEach(a=>times.set(a.id,0));setPlaying(true);render();};
function seek(percent){setPlaying(false);active().forEach(a=>times.set(a.id,a.duration*Math.max(0,Math.min(1,percent/100))));render();}
$('sample').onclick=()=>seek(Number($('exact-progress').value)||0);$('seek').oninput=()=>seek(Number($('seek').value));$('peak').onclick=()=>seek(49);
function apply(text){try{controller.restore(JSON.parse(text));const saved=persist();controls();render();notify(saved?'配置已应用并保存。':'配置已应用，但本机保存失败；刷新后可能丢失。');}catch(error){notify('未应用：'+error.message+'。当前设置保持不变。');}}
$('apply').onclick=()=>apply($('config').value);
$('import').onchange=async()=>{const f=$('import').files[0];if(!f)return;if(f.size>64000){notify('未应用：配置文件超过64KB。');return;}const text=await f.text();$('config').value=text;apply(text);$('import').value='';};
$('export').onclick=()=>{const text=JSON.stringify(controller.snapshot(),null,2);$('config').value=text;const url=URL.createObjectURL(new Blob([text],{type:'application/json'})),a=document.createElement('a');a.href=url;a.download='jianghu-36-controls-v1.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);notify('已导出配置，下面也可复制JSON。');};
function tick(now){if(playing){const delta=Math.min((now-last)/1000,.1);for(const a of active()){const o=controller.resolve(a.id);if(o.motion===false)continue;let t=times.get(a.id)+delta*(o.speed??1);if(t>=a.duration)t=$('loop').checked?t%a.duration:a.duration;times.set(a.id,t);}if(!$('loop').checked&&active().every(a=>controller.resolve(a.id).motion===false||times.get(a.id)>=a.duration))setPlaying(false);render();}last=now;requestAnimationFrame(tick);}
document.addEventListener('visibilitychange',()=>{if(document.hidden)setPlaying(false);});
const thumbnailOptions=Object.fromEntries(Object.entries(features).map(([k,f])=>[k,f.default]));
for(const family of [...new Set(assets.map(a=>a.family))])$('family').add(new Option(assets.find(a=>a.family===family).familyName,family));
for(const a of assets){
 const card=document.createElement('button');card.className='catalog-card';card.dataset.id=a.id;card.setAttribute('aria-label',String(a.number).padStart(2,'0')+' '+a.name+' · '+a.motion);card.innerHTML=`<div class="catalog-meta"><span>${String(a.number).padStart(2,'0')} / ${a.familyName}</span><span class="slot-mark"></span></div><canvas width="360" height="240" aria-hidden="true"></canvas><strong>${a.name}</strong><span class="motion-label">${a.motion}</span><span class="catalog-story">${a.description}</span>`;
 const canvas=card.querySelector('canvas'),g=canvas.getContext('2d');background(g,360,240);g.save();g.scale(.75,.75);a.draw(g,a.duration*a.previewAt,thumbnailOptions);g.restore();
 card.onclick=()=>{selectAsset(Number($('target').value),a.id);notify(a.name+' 已载入预览 '+($('target').value==='0'?'A':'B')+'。');$('cards').scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth',block:'start'});};$('catalog').append(card);
}
function filterCatalog(){const q=$('search').value.trim().toLowerCase(),family=$('family').value;let count=0;document.querySelectorAll('.catalog-card').forEach(card=>{const a=byId.get(card.dataset.id),match=(family==='all'||a.family===family)&&[a.name,a.familyName,a.description,a.motion].join(' ').toLowerCase().includes(q);card.hidden=!match;if(match)count++;});$('count').textContent=count+' / 36';$('empty').hidden=count!==0;}
$('search').oninput=filterCatalog;$('family').onchange=filterCatalog;
let surprise=0;const pairs=[['v02','v35'],['v11','v24'],['v09','v20'],['v17','v29'],['v05','v34'],['v27','v33']];
$('surprise').onclick=()=>{slots=[...pairs[surprise++%pairs.length]];scope='global';refreshSlots();controls();active().forEach(a=>times.set(a.id,0));setPlaying(true);persist();$('cards').scrollIntoView({behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth',block:'start'});notify('惊喜配对：'+active().map(a=>a.name).join(' × '));};
refreshSlots();controls();render();requestAnimationFrame(tick);
