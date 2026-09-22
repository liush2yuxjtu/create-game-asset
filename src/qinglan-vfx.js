import * as T from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {sample,DURATION} from './timeline.js';
import {noiseGLSL,vertexShader,ribbonFragment,ringFragment} from './shaders.js';
export async function createQinglanVFX({modelUrl,quality='high'}={}){
 const gltf=await new GLTFLoader().loadAsync(modelUrl);
 const root=new T.Group();root.name='QinglanV2';const swords=gltf.scene;root.add(swords);
 const mixer=new T.AnimationMixer(swords);const action=mixer.clipAction(gltf.animations[0]);action.setLoop(T.LoopOnce,1);action.clampWhenFinished=true;action.play();
 // The original remains byte-identical on disk. V2 replaces its simple VFX layers at runtime.
 for(const name of ['sigil','sword-energy','jade-fragments'])swords.getObjectByName(name).visible=false;
 const uniforms={time:{value:0},life:{value:1},dissolve:{value:0},jade:{value:new T.Color('#7bcbb0')}};
 const materials=[];
 swords.traverse(o=>{if(!o.isMesh)return;o.material=o.material.clone();const mat=o.material;
  mat.transparent=true;mat.userData.baseOpacity=mat.opacity;
  mat.onBeforeCompile=shader=>{shader.uniforms.qlDissolve=uniforms.dissolve;shader.vertexShader=shader.vertexShader.replace('#include <common>','#include <common>\nvarying vec3 qlPosition;').replace('#include <begin_vertex>','#include <begin_vertex>\nqlPosition=position;');shader.fragmentShader=shader.fragmentShader.replace('#include <common>',`#include <common>\nvarying vec3 qlPosition;uniform float qlDissolve;\n${noiseGLSL}`).replace('#include <alphatest_fragment>',`#include <alphatest_fragment>\nfloat inkNoise=fbm(qlPosition.xy*10.+qlPosition.z*3.);if(inkNoise<qlDissolve)discard;diffuseColor.rgb+=vec3(.3,.8,.58)*(1.-smoothstep(qlDissolve,qlDissolve+.06,inkNoise))*.6;`);};materials.push(mat);
 });
 const effects=new T.Group();root.add(effects);
 function shader(fragment,additive=false){return new T.ShaderMaterial({uniforms,vertexShader,fragmentShader:fragment,transparent:true,depthWrite:false,side:T.DoubleSide,blending:additive?T.AdditiveBlending:T.NormalBlending});}
 const sigil=new T.Mesh(new T.PlaneGeometry(8.8,8.8),shader(ringFragment,true));sigil.rotation.x=-Math.PI/2;sigil.position.y=.015;effects.add(sigil);
 const ribbons=new T.Group();effects.add(ribbons);
 for(let j=0;j<3;j++){
  const positions=[],uv=[],indices=[];const segments=100;
  for(let i=0;i<=segments;i++){let f=i/segments,a=f*Math.PI*1.68+j*.25;
   for(let k=0;k<2;k++){let radius=2.7+(k-.5)*(.32+Math.sin(f*Math.PI)*.5)+j*.19;
    positions.push(Math.cos(a)*radius,.3+f*2.25+j*.2+Math.sin(a*1.5)*.16,Math.sin(a)*radius);uv.push(f,k);}
   if(i<segments){let n=i*2;indices.push(n,n+1,n+2,n+1,n+3,n+2);}
  }
  const geo=new T.BufferGeometry();geo.setAttribute('position',new T.Float32BufferAttribute(positions,3));geo.setAttribute('uv',new T.Float32BufferAttribute(uv,2));geo.setIndex(indices);
  ribbons.add(new T.Mesh(geo,shader(ribbonFragment,j===1)));
 }
 const count=640,points=new Float32Array(count*3),seeds=[];
 for(let i=0;i<count;i++){const r=(Math.sin(i*127.1+43)*43758.5453)%1;seeds.push({a:i*2.399963,r:Math.abs(r),h:((i*73)%101)/101});}
 const pg=new T.BufferGeometry();pg.setAttribute('position',new T.BufferAttribute(points,3));
 const pm=new T.ShaderMaterial({transparent:true,depthWrite:false,blending:T.AdditiveBlending,uniforms:{...uniforms,pixelRatio:{value:1}},vertexShader:`uniform float pixelRatio; varying float depth; void main(){vec4 p=modelViewMatrix*vec4(position,1.);depth=-p.z;gl_Position=projectionMatrix*p;gl_PointSize=clamp(32./max(1.,depth)*pixelRatio,1.,7.);}`,fragmentShader:`uniform float life;void main(){float r=length(gl_PointCoord-.5)*2.;float a=pow(max(0.,1.-r),2.);gl_FragColor=vec4(.7,1.,.85,a*life);}`});
 const particles=new T.Points(pg,pm);effects.add(particles);
 const shock=new T.Mesh(new T.RingGeometry(.96,1,128),new T.MeshBasicMaterial({color:0xb5e9ce,transparent:true,opacity:0,side:T.DoubleSide,depthWrite:false,blending:T.AdditiveBlending}));shock.rotation.x=-Math.PI/2;shock.position.y=.06;effects.add(shock);
 const layerFlags={swords:true,sigil:true,ribbons:true,particles:true};
 function setQuality(q){quality=q;pg.setDrawRange(0,q==='low'?220:640);}
 setQuality(quality);
 function update(seconds){const f=sample(seconds);uniforms.time.value=f.t;uniforms.life.value=f.life;uniforms.dissolve.value=f.dissolve;
  // Reset before seeking so a backwards scrub after completion is deterministic.
  action.reset().play();mixer.setTime(Math.min(f.t,DURATION-.00001));
  for(const mat of materials)mat.opacity=mat.userData.baseOpacity*f.life;
  swords.visible=layerFlags.swords&&f.life>.001;effects.visible=f.life>.001;
  sigil.visible=layerFlags.sigil;sigil.rotation.z=f.t*.12;
  ribbons.visible=layerFlags.ribbons;ribbons.rotation.y=-f.t*.6-f.slash*2.6;ribbons.scale.setScalar(.3+.7*f.charge);ribbons.scale.y=.4+.6*f.charge;
  particles.visible=layerFlags.particles;
  for(let i=0;i<count;i++){const s=seeds[i],a=s.a+f.t*(.25+s.r*.25),r=.4+s.r*2.8+f.slash*s.r*1.25;
   points[i*3]=Math.cos(a)*r;points[i*3+1]=.12+s.h*(.4+f.charge*2.8)+f.slash*(1-s.r)*.8;points[i*3+2]=Math.sin(a)*r;}
  pg.attributes.position.needsUpdate=true;shock.visible=layerFlags.ribbons;shock.scale.setScalar(.5+f.slash*4.4);shock.material.opacity=f.burst*.4;
  return f;
 }
 return {root,update,setQuality,setLayer(name,value){if(!(name in layerFlags))throw new Error('Unknown layer');layerFlags[name]=!!value;},setPixelRatio(value){pm.uniforms.pixelRatio.value=value;},
  dispose(){mixer.stopAllAction();const geometries=new Set(),mats=new Set();root.traverse(o=>{if(o.geometry)geometries.add(o.geometry);if(o.material)mats.add(o.material);});geometries.forEach(g=>g.dispose());mats.forEach(m=>m.dispose());root.removeFromParent();}};
}
