import {drawGround,drawActors,drawLabels,drawTelegraph,fixtureById} from './fixtures.js';
import {defaults} from './registry.js';
export function createEffectLayer(){const c=document.createElement('canvas');c.width=480;c.height=320;return c;}
/** Host owns scenery, transforms, clocks and debug cues; plugins own transparent pixels. */
export function renderScene(g,scene,effect,time,{layer,bitmap=null,visible=true,debug=true}={}){
 const f=fixtureById(scene.fixture);g.save();g.clearRect(0,0,960,600);drawGround(g,f,scene.grid);drawActors(g,f,scene,false);
 if(debug&&visible)drawTelegraph(g,scene,time,effect.duration);
 if(visible){
  let source=bitmap;
  if(!effect.local){layer.width=480;effect.draw(layer.getContext('2d'),time,{...defaults,scale:1});source=layer;}
  if(source){g.save();g.translate(scene.target.x,scene.target.y);g.rotate(scene.rotation*Math.PI/180);g.scale(scene.scale,scene.scale);g.drawImage(source,-240,-160);g.restore();}
 }
 drawActors(g,f,scene,true);if(debug)drawLabels(g,scene);g.restore();
}
