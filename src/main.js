import * as T from 'three';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {EffectComposer} from 'three/addons/postprocessing/EffectComposer.js';
import {RenderPass} from 'three/addons/postprocessing/RenderPass.js';
import {UnrealBloomPass} from 'three/addons/postprocessing/UnrealBloomPass.js';
import {OutputPass} from 'three/addons/postprocessing/OutputPass.js';
import {createQinglanVFX} from './qinglan-vfx.js';
import {DURATION} from './timeline.js';
import './style.css';
const $=s=>document.querySelector(s),host=$('#stage');
let renderer,composer,asset,controls,resizeObserver,raf;
async function init(){
try{
 renderer=new T.WebGLRenderer({antialias:true,powerPreference:'high-performance'});
 renderer.setPixelRatio(Math.min(devicePixelRatio,1.75));renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.1;host.append(renderer.domElement);
 const scene=new T.Scene();scene.background=new T.Color('#101d19');scene.fog=new T.FogExp2('#101d19',.018);
 const camera=new T.PerspectiveCamera(38,1,.1,70);controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.minDistance=6;controls.maxDistance=20;controls.maxPolarAngle=Math.PI*.48;
 function resetCamera(){camera.position.set(8,6.4,10);controls.target.set(0,1.6,0);controls.update();}resetCamera();
 scene.add(new T.HemisphereLight(0xd9f8e3,0x172720,2.4));const key=new T.DirectionalLight(0xe6fae5,4);key.position.set(3,8,4);scene.add(key);const rim=new T.DirectionalLight(0x71cfb1,3);rim.position.set(-3,4,-3);scene.add(rim);
 const floor=new T.Mesh(new T.CircleGeometry(7,96),new T.MeshStandardMaterial({color:0x142b21,roughness:1,metalness:0}));floor.rotation.x=-Math.PI/2;floor.position.y=-.05;scene.add(floor);
 const grid=new T.GridHelper(18,36,0x315142,0x20392d);grid.material.transparent=true;grid.material.opacity=.25;grid.position.y=-.045;scene.add(grid);
 composer=new EffectComposer(renderer);composer.addPass(new RenderPass(scene,camera));const bloom=new UnrealBloomPass(new T.Vector2(800,600),.65,.65,.7);composer.addPass(bloom);composer.addPass(new OutputPass());
 asset=await createQinglanVFX({modelUrl:new URL('assets/qinglan/v1/qinglan-sword-formation.glb',document.baseURI).href});scene.add(asset.root);asset.setPixelRatio(renderer.getPixelRatio());
 let time=1.48,running=false,last=performance.now();
 function setTime(t){time=Math.max(0,Math.min(DURATION,t));const f=asset.update(time);$('#timeline').value=time;$('#time').textContent=time.toFixed(2)+' s';document.querySelectorAll('[data-time]').forEach(b=>b.classList.toggle('active',Math.abs(Number(b.dataset.time)-({charge:.8,slash:1.48,dissipate:2.5}[f.state]??-1))<.01));host.dataset.state=f.state;}
 function playing(value){running=value;$('#play').textContent=value?'暂停':'播放剑阵';$('#play').setAttribute('aria-pressed',String(value));}
 function resize(){const w=host.clientWidth,h=host.clientHeight;renderer.setSize(w,h,false);composer.setSize(w,h);camera.aspect=w/h;camera.updateProjectionMatrix();}resizeObserver=new ResizeObserver(resize);resizeObserver.observe(host);resize();setTime(time);
 $('#loading').remove();$('#render-status').textContent='WebGL 2 · V2 已就绪';
 $('#play').addEventListener('click',()=>{if(running)playing(false);else{if(time>=DURATION)setTime(0);playing(true);}});
 $('#timeline').addEventListener('input',e=>{playing(false);setTime(Number(e.target.value));});
 document.querySelectorAll('[data-time]').forEach(b=>b.addEventListener('click',()=>{playing(false);setTime(Number(b.dataset.time));}));
 document.querySelectorAll('[data-layer]').forEach(b=>b.addEventListener('change',()=>{asset.setLayer(b.dataset.layer,b.checked);setTime(time);}));
 $('#camera').addEventListener('click',resetCamera);$('#bloom').addEventListener('change',e=>{bloom.enabled=e.target.checked;});
 $('#quality').addEventListener('change',e=>{const low=e.target.value==='low';asset.setQuality(e.target.value);renderer.setPixelRatio(Math.min(devicePixelRatio,low?1:1.75));composer.setPixelRatio(renderer.getPixelRatio());asset.setPixelRatio(renderer.getPixelRatio());resize();});
 document.addEventListener('visibilitychange',()=>{last=performance.now();if(document.hidden)playing(false);});
 renderer.domElement.addEventListener('webglcontextlost',e=>{e.preventDefault();playing(false);$('#render-status').textContent='图形上下文已丢失，请刷新重试';});
 function frame(now){raf=requestAnimationFrame(frame);const dt=Math.min((now-last)/1000,.1);last=now;if(running){let t=time+dt*Number($('#speed').value);if(t>=DURATION){if($('#loop').checked)t%=DURATION;else{t=DURATION;playing(false);}}setTime(t);}controls.update();composer.render();}raf=requestAnimationFrame(frame);
 addEventListener('pagehide',()=>{cancelAnimationFrame(raf);resizeObserver.disconnect();asset.dispose();controls.dispose();bloom.dispose();composer.dispose();renderer.dispose();},{once:true});
}catch(error){console.error(error);$('#loading').textContent='三维预览加载失败。请使用支持 WebGL 2 的浏览器，或下载资产包。';$('#render-status').textContent='预览不可用';document.querySelectorAll('aside button,aside input,aside select').forEach(el=>el.disabled=true);}

}
init();
