// Original, deterministic mock scenery. No extracted game images or gameplay logic.
export const WORLD = Object.freeze({ width: 960, height: 600 });
export const fixtures = Object.freeze([
  {id:'courtyard',name:'青石试剑庭',description:'单目标 · 清晰轮廓',terrain:'stone',targets:[[590,270]],obstacles:[]},
  {id:'crowd',name:'八方木人阵',description:'八目标 · 范围与遮挡',terrain:'stone',targets:[[480,160],[590,185],[665,270],[610,365],[480,395],[370,365],[305,270],[365,185]],obstacles:[]},
  {id:'bamboo',name:'竹径窄巷',description:'狭窄地形 · 墙边裁切',terrain:'grass',targets:[[575,270],[650,270]],obstacles:[[235,120,480,80],[235,395,480,65]]},
  {id:'snow',name:'月白雪庭',description:'浅色地面 · 亮部可读性',terrain:'snow',targets:[[590,270],[690,330]],obstacles:[]},
  {id:'night',name:'夜泊深潭',description:'深色地面 · 泛光可读性',terrain:'night',targets:[[590,270],[420,200]],obstacles:[]},
]);
export function fixtureById(id){return fixtures.find(f=>f.id===id)||fixtures[0];}
export function sceneDefaults(){return {fixture:'courtyard',caster:{x:360,y:330},target:{x:570,y:270},radius:110,scale:1.3,rotation:0,grid:false,actors:true,telegraph:true};}
export function screenToWorld(x,y,rect){return {x:Math.max(36,Math.min(924,(x-rect.left)/rect.width*960)),y:Math.max(45,Math.min(555,(y-rect.top)/rect.height*600))};}
const noise=(x,y)=>{const v=Math.sin(x*127.1+y*311.7)*43758.5453;return v-Math.floor(v);};
function rect(g,x,y,w,h,c){g.fillStyle=c;g.fillRect(x,y,w,h);}
export function drawGround(g,f,grid=false){
 const light=f.terrain==='snow',night=f.terrain==='night';
 rect(g,0,0,960,600,light?'#d8dfd6':night?'#101f27':'#203d34');
 for(let y=0;y<600;y+=24)for(let x=0;x<960;x+=24){const n=noise(x,y);if(n>.55){rect(g,x+5,y+9,3,5,light?'#bccbc4':night?'#1b3139':'#315247');if(n>.8)rect(g,x+9,y+6,2,7,light?'#c6d3ca':'#42614c');}}
 const stone=light?['#cbd5cf','#d5ddd4','#c4cfc8']:night?['#25373c','#263b40','#223439']:['#56635a','#5c695e','#506156'];
 for(let y=72;y<530;y+=38)for(let x=120;x<840;x+=48){const n=noise(x,y);rect(g,x+1,y+1,46,36,stone[Math.floor(n*3)]);rect(g,x+2,y+2,44,2,light?'#e2e8df':night?'#35454a':'#738072');if(n>.8)rect(g,x+34,y+25,8,3,light?'#b6c4bb':'#384e42');}
 // Pond/bridge and perimeter plants establish scale without competing with the effect.
 rect(g,0,395,112,205,night?'#112d38':'#1d4b51');for(let i=0;i<22;i++){const x=noise(i,7)*96,y=408+noise(i,13)*182;rect(g,x,y,12,2,night?'#224450':'#376568');}
 for(let x=0;x<138;x+=14){rect(g,x,434,12,56,'#6a6048');rect(g,x,436,10,3,'#938363');}
 for(const [x,y] of [[76,92],[878,94],[880,487]]){rect(g,x-4,y,8,50,'#625843');for(let k=0;k<7;k++){const a=k*2.4;rect(g,x+Math.cos(a)*26-20,y+Math.sin(a)*16-32,38,24,light?'#a4b7a4':night?'#1c3b37':'#3d6250');}}
 for(const [x,y] of [[174,70],[786,70],[176,526],[784,526]]){rect(g,x-4,y,8,18,'#554d3b');rect(g,x-10,y-22,20,25,'#b69d69');rect(g,x-7,y-18,14,17,'#ecd59a');rect(g,x-13,y-25,26,4,'#343f38');}
 for(const [x,y,w,h] of f.obstacles){rect(g,x+5,y+8,w,h,'#263b30');rect(g,x,y,w,h,'#405649');for(let i=x+6;i<x+w;i+=18){rect(g,i,y,5,h,'#72836b');rect(g,i,y+18,5,2,'#293b31');}}
 if(grid){g.save();g.strokeStyle=light?'#30473b40':'#c6e7d129';g.lineWidth=1;for(let x=0;x<=960;x+=48){g.beginPath();g.moveTo(x,0);g.lineTo(x,600);g.stroke();}for(let y=0;y<=600;y+=48){g.beginPath();g.moveTo(0,y);g.lineTo(960,y);g.stroke();}g.restore();}
}
function actor(g,x,y,player){g.save();g.translate(Math.round(x),Math.round(y));g.fillStyle='#0b171a55';g.beginPath();g.ellipse(0,4,16,7,0,0,Math.PI*2);g.fill();if(player){rect(g,-10,-28,20,24,'#a5c5b1');rect(g,-13,-22,5,20,'#537b69');rect(g,7,-22,6,20,'#d7dbb9');rect(g,-6,-43,12,15,'#d2b58b');rect(g,-8,-45,16,7,'#21372e');rect(g,-3,-51,7,8,'#26392e');rect(g,-8,-5,6,11,'#21372e');rect(g,3,-5,6,11,'#21372e');rect(g,14,-29,3,34,'#d7d9c8');rect(g,10,-3,11,3,'#c6a667');}else{rect(g,-5,-26,10,31,'#977952');rect(g,-18,-25,36,6,'#b49a6b');rect(g,-10,-39,20,14,'#b69b6d');rect(g,-7,-36,14,8,'#786342');rect(g,-11,0,22,5,'#755f43');}g.restore();}
export function drawActors(g,f,s,foreground=false){if(!s.actors)return;const list=[{...s.caster,player:true},...f.targets.map(([x,y])=>({x,y,player:false}))].sort((a,b)=>a.y-b.y);for(const a of list)if((a.y>s.target.y)===foreground)actor(g,a.x,a.y,a.player);}
export function drawLabels(g,s){if(s.actors){g.font='12px system-ui';g.textAlign='center';g.fillStyle='#101f24';g.fillRect(s.caster.x-30,s.caster.y+14,60,20);g.fillStyle='#d5ebdf';g.fillText('施法者',s.caster.x,s.caster.y+28);}g.save();g.strokeStyle='#e6c97d';g.lineWidth=1.5;const{x,y}=s.target;g.beginPath();g.moveTo(x-7,y);g.lineTo(x+7,y);g.moveTo(x,y-7);g.lineTo(x,y+7);g.stroke();g.restore();}
export function drawTelegraph(g,s,t,duration){if(!s.telegraph||t<=0||t>=duration)return;g.save();g.setLineDash([6,6]);g.lineWidth=1.5;g.strokeStyle='#e5c77c99';g.beginPath();g.arc(s.target.x,s.target.y,s.radius*s.scale,0,Math.PI*2);g.stroke();g.setLineDash([3,6]);g.strokeStyle='#d0e4cd66';g.beginPath();g.moveTo(s.caster.x,s.caster.y);g.lineTo(s.target.x,s.target.y);g.stroke();g.restore();}
