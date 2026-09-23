import {AssetController,features} from './controller.js';
import {rainBlades} from './assets/rain-blades.js';
const $=id=>document.getElementById(id),key='jianghu-asset-controller-v1';
const assets=[{...rainBlades,id:'rain-a',name:'A · 听雨借锋'},{...rainBlades,id:'rain-b',name:'B · 听雨借锋'}];
const controller=new AssetController(assets),times=new Map(assets.map(a=>[a.id,1.8]));
let scope='global',playing=false,last=0;
function notify(message){$('notice').textContent=message;}
try{const saved=localStorage.getItem(key);if(saved)controller.restore(JSON.parse(saved));}catch{notify('本机配置无法读取，已使用默认值。');}
function persist(){try{localStorage.setItem(key,JSON.stringify(controller.snapshot()));notify('已保存到此浏览器。');}catch{notify('浏览器禁止保存；当前调整仍然有效。');}}
const views=assets.map(a=>{
  const card=document.createElement('article');card.className='card';
  card.innerHTML=`<div class="card-top"><h2>${a.name}</h2><span>4.2s / 独立实例</span></div><canvas width="480" height="320" aria-label="${a.name}动态预览"></canvas><div class="card-info" role="status"></div>`;
  $('cards').append(card);return {asset:a,card,canvas:card.querySelector('canvas'),info:card.querySelector('.card-info')};
});
function render(){
 for(const {asset:a,card,canvas,info}of views){
  const g=canvas.getContext('2d'),o=controller.resolve(a.id),t=times.get(a.id);
  g.clearRect(0,0,480,320);g.fillStyle='#12251f';g.fillRect(0,0,480,320);
  const bg=g.createRadialGradient(240,160,10,240,160,250);bg.addColorStop(0,'#233d32');bg.addColorStop(1,'#11241f');g.fillStyle=bg;g.fillRect(0,0,480,320);
  g.strokeStyle='#96b0a015';g.beginPath();g.moveTo(225,160);g.lineTo(255,160);g.moveTo(240,145);g.lineTo(240,175);g.stroke();
  a.draw(g,t,o);card.classList.toggle('selected',scope===a.id);
  const n=Object.keys(controller.overrides[a.id]).length;
  info.textContent=`${t.toFixed(2)}s · ${o.visible!==false?'显示':'隐藏'} · ${o.motion!==false?'可推进':'已冻结'} · ${n?'单项覆盖 '+n+' 项':'全部继承全局'} · ${o.speed??1}×`;
 }
 $('time').textContent=times.get(assets[0].id).toFixed(2)+'s（A）';$('seek').value=times.get(assets[0].id);
}
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
$('play').onclick=()=>{if(!playing&&assets.every(a=>times.get(a.id)>=a.duration))assets.forEach(a=>times.set(a.id,0));setPlaying(!playing);};
$('restart').onclick=()=>{assets.forEach(a=>times.set(a.id,0));setPlaying(true);render();};
function seek(t){setPlaying(false);assets.forEach(a=>times.set(a.id,Math.min(a.duration,t)));render();}
$('seek').oninput=()=>seek(Number($('seek').value));$('peak').onclick=()=>seek(1.8);
function apply(text){try{controller.restore(JSON.parse(text));persist();controls();render();notify('配置已应用并保存。');}catch(error){notify('未应用：'+error.message+'。当前设置保持不变。');}}
$('apply').onclick=()=>apply($('config').value);
$('import').onchange=async()=>{const f=$('import').files[0];if(!f)return;if(f.size>64000){notify('未应用：配置文件超过64KB。');return;}const text=await f.text();$('config').value=text;apply(text);$('import').value='';};
$('export').onclick=()=>{const text=JSON.stringify(controller.snapshot(),null,2);$('config').value=text;const url=URL.createObjectURL(new Blob([text],{type:'application/json'})),a=document.createElement('a');a.href=url;a.download='jianghu-controls-v1.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);notify('已导出配置，下面也可复制JSON。');};
function tick(now){if(playing){const delta=Math.min((now-last)/1000,.1);for(const a of assets){const o=controller.resolve(a.id);if(o.motion===false)continue;let t=times.get(a.id)+delta*(o.speed??1);if(t>=a.duration)t=$('loop').checked?t%a.duration:a.duration;times.set(a.id,t);}if(!$('loop').checked&&assets.every(a=>controller.resolve(a.id).motion===false||times.get(a.id)>=a.duration))setPlaying(false);render();}last=now;requestAnimationFrame(tick);}
document.addEventListener('visibilitychange',()=>{if(document.hidden)setPlaying(false);});controls();render();requestAnimationFrame(tick);
