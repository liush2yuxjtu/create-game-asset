import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync,readFileSync,readdirSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {effects,defaults,validateEffect} from '../public/playground/registry.js';
import {fixtures,sceneDefaults,screenToWorld} from '../public/playground/fixtures.js';
test('all forty compatible modules have unique validated identities and real sources',()=>{
 assert.equal(effects.length,40);assert.equal(new Set(effects.map(a=>a.id)).size,40);
 for(const a of effects){assert.equal(validateEffect(a),a);const u=new URL(a.source,new URL('../public/playground/',import.meta.url));assert.ok(existsSync(u),u.pathname);}
 const registered=effects.filter(a=>/^v\d\d$/.test(a.id)).map(a=>a.source.split('/').pop()).sort();
 assert.deepEqual(registered,readdirSync('public/asset-lab/variants').filter(s=>s.endsWith('.js')).sort());
});
test('plugin contract rejects malformed modules',()=>{
 const a=effects[0];for(const patch of [{id:'bad id'},{id:'<script>'},{name:''},{name:'x'.repeat(81)},{duration:0},{duration:Infinity},{duration:31},{draw:null}])assert.throws(()=>validateEffect({...a,...patch}));
});
test('all effect endpoints are transparent and drawing uses a time sample',()=>{
 for(const a of effects){const calls=[];const dummy=new Proxy({},{get(_t,k){return (...args)=>{calls.push([k,...args]);return {};};},set(){return true;}});
  a.draw(dummy,0,defaults);a.draw(dummy,a.duration,defaults);assert.equal(calls.length,0,a.id+' endpoints must not draw');
 }
});
test('fixture coordinates are independent, deterministic and bounded',()=>{
 assert.equal(fixtures.length,5);assert.equal(new Set(fixtures.map(f=>f.id)).size,5);assert.equal(fixtures.find(f=>f.id==='crowd').targets.length,8);
 const a=sceneDefaults(),b=sceneDefaults();a.caster.x=0;assert.equal(b.caster.x,360);
 assert.deepEqual(screenToWorld(110,120,{left:10,top:20,width:200,height:200}),{x:480,y:300});
 assert.deepEqual(screenToWorld(-1e6,1e6,{left:0,top:0,width:200,height:200}),{x:36,y:555});
});
test('source ledger preserves provenance, uncertainty, and game identity',()=>{
 const s=JSON.parse(readFileSync('public/playground/sources.json'));assert.equal(s.sources.length,12);assert.equal(new Set(s.sources.map(x=>x.id)).size,12);assert.match(s.identityBoundary,/一念逍遥/);assert.match(s.dynamicParity,/NOT_RUN/);assert.ok(s.sources.some(x=>x.type==='original-video-candidate'&&x.evidence.includes('未播放')));
});
test('new JS modules parse without browser execution',()=>{
 for(const name of ['app.js','fixtures.js','registry.js','scene.js','plugin-host.js','examples/ground-fire.js','examples/ice-step.js','examples/jade-guard.js'])execFileSync(process.execPath,['--check','public/playground/'+name]);
});
