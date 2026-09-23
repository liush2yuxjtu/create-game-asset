// Shared deterministic drawing machinery. Each variant module owns its identity and motion descriptor.
// Canvas 480x320, transparent effect only: background / clocks belong to the host.
import {features} from './controller.js';
const TAU=Math.PI*2,clamp=x=>Math.max(0,Math.min(1,x)),s=x=>{x=clamp(x);return x*x*(3-2*x)},lerp=(a,b,t)=>a+(b-a)*t;
const palettes={jade:['#9fdcc4','#e8c987','#eee8c9','#153b31','#b76650'],cinnabar:['#e3a087','#ebc589','#f2ddbb','#492d2b','#da7359'],moon:['#bcdfea','#d0ccaf','#eff2e1','#21364b','#8fa5c7']};
export function createVariant(spec){return Object.freeze({...spec,supports:Object.keys(features),draw(g,t,o){drawVariant(g,t,o,spec);}});}
function line(g,points,color,width=1){g.beginPath();points.forEach((p,i)=>i?g.lineTo(...p):g.moveTo(...p));g.strokeStyle=color;g.lineWidth=width;g.stroke();}
function poly(g,points,fill,stroke){g.beginPath();points.forEach((p,i)=>i?g.lineTo(...p):g.moveTo(...p));g.closePath();if(fill){g.fillStyle=fill;g.fill();}if(stroke){g.strokeStyle=stroke;g.lineWidth=.8;g.stroke();}}
function circle(g,x,y,r,color,fill=false){g.beginPath();g.arc(x,y,Math.max(.01,r),0,TAU);if(fill){g.fillStyle=color;g.fill();}else{g.strokeStyle=color;g.lineWidth=1;g.stroke();}}
function ellipse(g,x,y,rx,ry,color){g.beginPath();g.ellipse(x,y,Math.max(.01,rx),Math.max(.01,ry),0,0,TAU);g.strokeStyle=color;g.lineWidth=1;g.stroke();}
function petal(g,x,y,size,angle,color,vein){g.save();g.translate(x,y);g.rotate(angle);g.beginPath();g.moveTo(0,-size);g.bezierCurveTo(size*.8,-size*.3,size*.8,size*.5,0,size*.7);g.bezierCurveTo(-size*.8,size*.5,-size*.8,-size*.3,0,-size);g.fillStyle=color;g.fill();if(vein)line(g,[[0,-size*.7],[0,size*.55]],vein,.8);g.restore();}
function glyph(g,x,y,size,color){line(g,[[x-size,y-size],[x+size,y-size],[x-size*.4,y],[x+size*.6,y+size*.3],[x,y+size]],color,1.2);line(g,[[x,y-size*1.2],[x,y+size*1.3]],color,1);}
function runePaper(g,x,y,angle,scale,c){g.save();g.translate(x,y);g.rotate(angle);g.scale(scale,scale);poly(g,[[-14,-24],[14,-24],[14,24],[-14,24]],c[2],c[1]);glyph(g,0,0,9,c[4]);line(g,[[-10,-19],[10,-19]],c[4]);g.restore();}
function branch(g,x,y,length,angle,depth,c,seed=0){if(depth<=0||length<1)return;const end=[x+Math.cos(angle)*length,y+Math.sin(angle)*length];line(g,[[x,y],[(x+end[0])/2+Math.sin(seed)*5,(y+end[1])/2],end],c,depth*.55);branch(g,...end,length*.67,angle-.48,depth-1,c,seed+1);branch(g,...end,length*.58,angle+.55,depth-1,c,seed+3);}
const drawers={
 paper(g,p,v,c){const flight=s((p-.15)/.36),unfold=s((p-.52)/.14);let n=v===1?4:v===2?1:3;
  for(let i=0;i<n;i++){const a=-Math.PI/2+i*TAU/n,r=lerp(12,v===2?84:82,flight),x=Math.cos(a)*r,y=lerp(83,Math.sin(a)*r*.7,flight);g.save();g.translate(x,y);g.rotate(v===2?Math.sin(p*6)*.25:a+Math.PI/2);const fold=Math.sin(p*36+i)*7*(1-unfold);
   if(unfold>.02){g.save();g.globalAlpha*=unfold;runePaper(g,0,0,0,1.1,c);g.restore();}
   g.globalAlpha*=1-unfold;if(v===0){poly(g,[[0,0],[-37,-20-fold],[-15,13],[0,7],[15,13],[37,-20-fold]],c[2],c[1]);poly(g,[[0,8],[-4,-21],[7,-30],[3,-12],[6,14]],c[2],c[1]);line(g,[[-30,-15],[0,7],[30,-15]],c[1]);}
   if(v===1){petal(g,-13,0,23,-.9+fold*.018,c[2],c[1]);petal(g,13,0,23,.9-fold*.018,c[0],c[1]);line(g,[[0,-12],[0,15]],c[1],2);}
   if(v===2){poly(g,[[0,-35],[-26,0],[0,27],[26,0]],c[2],c[1]);line(g,[[0,-35],[0,27]],c[4]);line(g,[[-26,0],[26,0]],c[4]);line(g,[[0,27],[-9,44],[8,59],[-5,75]],c[1]);}g.restore();}
 },
 rain(g,p,v,c){let shoot=s((p-.28)/.18),soft=1-s((p-.68)/.17);const n=v===1?13:v===2?6:7;
  for(let i=0;i<n;i++){let x,y,a,sharp=shoot*soft;if(v===0){x=-85+i*26+shoot*35;y=(i%3)*29-24-shoot*45;a=.6;}else if(v===1){x=Math.sin(i*3)*lerp(68,20,shoot);y=25-shoot*90+(i%5)*16+ s((p-.7)/.2)*100;a=p>.7?0:Math.PI;}else{a=i*TAU/n;x=Math.sin(a)*(30+shoot*63);y=Math.cos(a)*(30+shoot*63)*.65;}
   g.save();g.translate(x,y);g.rotate(a);poly(g,[[0,-8-sharp*24],[3,4],[0,9],[-3,4]],c[0],c[2]);g.restore();}
  if(v===1)ellipse(g,0,58,50,13,c[1]);if(v===2){for(let k=0;k<3;k++)ellipse(g,0,0,(20+k*13)*(1-shoot*.4),12+k*8,c[0]);}
 },
 leaf(g,p,v,c){const move=s((p-.25)/.35),back=s((p-.72)/.2);
  if(v===0){const a=-1.5+move*2.4,fan=s((p-.22)/.2)*(1-back);g.save();g.rotate(a);for(let k=0;k<7;k++){const theta=(k-3)*.15;line(g,[[0,45],[Math.sin(theta)*120*fan,-70*fan]],c[0],1.3); }petal(g,0,30,25,-.2,c[0],c[1]);g.restore();}
  if(v===1)for(let i=0;i<5;i++){const a=i*TAU/5+move*3.2,r=lerp(18,90,move)*(1-back);petal(g,Math.cos(a)*r,Math.sin(a)*r*.65,18,a+.7,c[0],c[1]);}
  if(v===2)for(let i=0;i<4;i++){const h=s((p-.1-i*.06)/.28)*95,x=(i-1.5)*39;line(g,[[x,55],[x,55-h]],c[0],3);for(let j=0;j<3;j++){line(g,[[x-5,35-j*24],[x+5,35-j*24]],c[1]);petal(g,x+14*(j%2?1:-1),25-j*22-move*9,15,j%2?.9:-.9,c[0],c[1]);}}
 },
 flower(g,p,v,c){if(v===0){const b=s(p/.3);line(g,[[-95,38],[-45,20],[-15,-15],[35,-20],[73,-50]],c[0],2*b);line(g,[[-40,20],[-28,55],[8,68]],c[0],1.5*b);const points=[[-45,20],[-15,-15],[35,-20],[73,-50],[8,68]];points.forEach(([x,y],i)=>{const size=13*s((p-.22-i*.07)/.15);for(let k=0;k<5;k++)petal(g,x+Math.cos(k*TAU/5)*size*.5,y+Math.sin(k*TAU/5)*size*.5,size,k*TAU/5,c[2],c[1]);circle(g,x,y,2,c[4],true);});}
  if(v===1){const open=s((p-.1)/.3)*(1-s((p-.65)/.2));for(let ring=1;ring>=0;ring--)for(let k=0;k<6;k++){const a=k*TAU/6+ring*.5,r=(20+ring*15)*open;petal(g,Math.cos(a)*r,Math.sin(a)*r*.7,20+open*12,a+Math.PI/2,ring?c[0]:c[2],c[1]);}circle(g,0,0,5,c[1],true);}
  if(v===2){const release=s((p-.3)/.3);for(let k=0;k<20;k++){const a=k*TAU/20,r=30+release*67,x=Math.cos(a)*r,y=Math.sin(a)*r*.7;line(g,[[Math.cos(a)*12,Math.sin(a)*12],[x,y]],c[0]+'80');for(let j=-1;j<=1;j++)line(g,[[x,y],[x+Math.cos(a+j*.4)*(8+release*8),y+Math.sin(a+j*.4)*8]],c[2]);}circle(g,0,0,7,c[1],true);}
 },
 music(g,p,v,c){const pluck=Math.sin(p*25)*Math.exp(-Math.max(0,p-.35)*4),release=s((p-.25)/.42);
  if(v===0){for(let k=0;k<7;k++){const y=(k-3)*13;g.beginPath();g.moveTo(-96,y);g.quadraticCurveTo(0,y+pluck*(14-k),96,y);g.strokeStyle=k===3?c[2]:c[1];g.lineWidth=k===3?1.5:.7;g.stroke();}for(let k=0;k<3;k++){const x=-15+release*(40+k*18);g.beginPath();g.ellipse(x,-20-k*5,14+release*10,50-k*8,0,-1.1,1.1);g.strokeStyle=c[0];g.stroke();}}
  if(v===1){g.save();g.rotate(pluck*.12);poly(g,[[-19,-46],[19,-46],[26,15],[37,28],[-37,28],[-26,15]],c[3],c[1]);line(g,[[-24,-30],[24,-30]],c[1]);circle(g,0,19,5,c[1],true);g.restore();for(let k=0;k<3;k++)ellipse(g,0,8,40+release*(22+k*16),28+release*(12+k*9),c[0]+'a0');}
  if(v===2){ellipse(g,0,10,61,39,c[1]);ellipse(g,0,-7,61,39,c[2]);for(let k=0;k<12;k++){const a=k*TAU/12;circle(g,Math.cos(a)*55,Math.sin(a)*34-7,2,c[1],true);}ellipse(g,0,-7,20+release*35,14+release*22,c[0]);line(g,[[-75,-64],[-16,-12+pluck*7]],c[1],5);line(g,[[75,-64],[16,-12+pluck*7]],c[1],5);}
 },
 chess(g,p,v,c){if(v===0){for(let j=-2;j<=2;j++){line(g,[[-80,j*30],[80,j*30]],c[0]+'70');line(g,[[j*35,-65],[j*35,65]],c[0]+'70');}for(let i=0;i<4;i++){const a=Math.PI/4+i*TAU/4,fall=s((p-.08-i*.06)/.16);circle(g,Math.cos(a)*80,Math.sin(a)*70-(1-fall)*25,11*fall,c[2],true);}const drop=s((p-.38)/.1);circle(g,0,-(1-drop)*56,15,c[3],true);circle(g,0,-(1-drop)*56,15,c[1]);}
  if(v===1){const points=[];for(let i=0;i<6;i++){const a=i*TAU/6+s((p-.25)/.25)*Math.PI/3;points.push([Math.cos(a)*78,Math.sin(a)*58]);}for(let i=0;i<6;i++){line(g,[points[i],points[(i+2)%6]],c[0]);circle(g,...points[i],i%2?9:12,i%2?c[2]:c[3],true);circle(g,...points[i],i%2?9:12,c[1]);}}
  if(v===2)for(let i=0;i<8;i++){const a=-1+i*.29,fall=s((p-.15-i*.045)/.15);g.save();g.translate(Math.sin(a)*95,Math.cos(a)*25);g.rotate(-.4+fall*1.2);poly(g,[[-9,-40],[9,-40],[9,8],[-9,8]],i%2?c[2]:c[3],c[1]);line(g,[[-7,-16],[7,-16]],c[1]);circle(g,0,-27,2,c[4],true);circle(g,0,-5,2,c[4],true);g.restore();}
 },
 thread(g,p,v,c){const tighten=s((p-.35)/.25),r=lerp(78,42,tighten);g.strokeStyle=c[4];g.lineWidth=1.5;
  if(v===0){for(let k=0;k<4;k++){const a=k*Math.PI/2;g.beginPath();g.moveTo(0,0);g.bezierCurveTo(Math.cos(a+.6)*r,Math.sin(a+.6)*r,Math.cos(a-.6)*r,Math.sin(a-.6)*r,0,0);g.stroke();line(g,[[Math.cos(a)*r*.5,Math.sin(a)*r*.5],[Math.cos(a)*104,Math.sin(a)*70]],c[4]);}circle(g,0,0,4,c[1],true);}
  if(v===1){for(let k=-3;k<=3;k++){const h=60*Math.sqrt(Math.max(0,1-k*k/16));line(g,[[k*22,-h],[k*22+Math.sin(p*12+k)*7*(1-tighten),h]],c[4]);line(g,[[-h*1.5,k*16],[h*1.5,k*16]],c[4]);}poly(g,[[0,-78],[108,0],[0,78],[-108,0]],null,c[1]);}
  if(v===2){const x=lerp(-95,95,s((p-.2)/.4)),y=Math.sin(p*9)*20;line(g,[[x-23,y],[x+23,y-12]],c[2],2);g.beginPath();g.moveTo(x-20,y);g.bezierCurveTo(x-50,y+65,-75,-65,-105,35);g.stroke();ellipse(g,x-17,y-1,3,1.5,c[1]);}
 },
 ink(g,p,v,c){const grow=s((p-.12)/.33),close=s((p-.55)/.2);if(v===0){const points=[[-100,38],[-80,5],[-56,18],[-28,-57*grow],[-4,-14],[22,-35*grow],[52,9],[73,-10],[105,38]];poly(g,points,c[3],c[0]);line(g,[[-96,36],[-28,-57*grow],[-4,-14]],c[1]);for(let i=0;i<5;i++)line(g,[[-75+i*28,26],[-64+i*28,7]],c[2]+'40');}
  if(v===1){g.save();g.scale(.7+grow*.4,.7+grow*.4);poly(g,[[-62,-46],[-37,-37],[-22,-51],[0,-37],[22,-51],[37,-37],[62,-46],[48,-8],[27,28],[0,47],[-27,28],[-48,-8]],c[3],c[0]);line(g,[[-37,-15],[-16,-7],[-30,-2]],c[1],2);line(g,[[37,-15],[16,-7],[30,-2]],c[1],2);poly(g,[[-10,15],[10,15],[0,25]],c[4]);for(let i=0;i<3;i++)line(g,[[-80+i*10,38],[ -64+i*10,-22]],c[0],2);g.restore();}
  if(v===2){const gap=30*(1-close);for(const side of[-1,1]){poly(g,[[side*(gap+5),-64],[side*(gap+58),-50],[side*(gap+58),55],[side*(gap+5),66]],c[3],c[1]);line(g,[[side*(gap+16),-43],[side*(gap+44),-36],[side*(gap+44),33],[side*(gap+16),43],[side*(gap+16),-43]],c[0]);circle(g,side*(gap+16),4,3,c[4],true);}}
 },
 thunder(g,p,v,c){const grow=s((p-.16)/.28),pulse=.5+.5*Math.sin(p*75)**2;g.save();g.globalAlpha*=pulse;
  if(v===0){branch(g,0,70,55*grow,-Math.PI/2,4,c[1],3);line(g,[[-18,73],[0,66],[17,73]],c[0]);}
  if(v===1){for(const sign of[-1,1]){branch(g,sign*12,38,55*grow,-Math.PI/2+sign*.35,4,c[1],sign+5);}ellipse(g,0,45,25,10,c[0]);}
  if(v===2){const points=[];for(let i=0;i<15;i++)points.push([-105+i*15,Math.sin(i*2.6)*18+(i%2?-1:1)*16*grow]);line(g,points,c[1],2);for(let i=2;i<14;i+=3)branch(g,...points[i],22*grow,-Math.PI/2,3,c[0],i);}
  g.restore();
 },
 vessel(g,p,v,c){if(v===0){const open=s(p/.24)*(1-s((p-.5)/.22)),r=18+open*62;g.save();g.rotate(p*.8);const pts=[];for(let k=0;k<10;k++){const a=k*TAU/10;pts.push([Math.cos(a)*r,Math.sin(a)*r*.72]);}poly(g,pts,c[3],c[2]);for(const pt of pts)line(g,[[0,0],pt],c[1]);circle(g,0,0,6,c[4],true);g.restore();if(p>.52)line(g,[[0,0],[120*s((p-.52)/.18),-45]],c[0],2);}
  if(v===1){const x=Math.sin(p*4)*23;g.save();g.translate(x,-8);poly(g,[[-20,-36],[20,-36],[28,-18],[25,23],[14,36],[-14,36],[-25,23],[-28,-18]],c[3],c[1]);for(let k=-1;k<=1;k++)line(g,[[k*12,-33],[k*17,0],[k*12,32]],c[1]);ellipse(g,0,-42,12,8,c[1]);line(g,[[0,36],[0,62]],c[4],2);petal(g,0,0,12,Math.sin(p*8)*.1,c[1]);g.restore();for(let k=0;k<12;k++){const a=k*2.399,r=95*(1-s((p-.1)/.5));circle(g,x+Math.cos(a)*r,Math.sin(a)*r*.6,1.5,c[1],true);}}
  if(v===2){g.save();g.translate(-78,23);g.rotate(-.7);ellipse(g,0,-15,13,16,c[1]);ellipse(g,0,14,21,23,c[1]);line(g,[[-5,-30],[5,-30]],c[2],4);g.restore();const end=s((p-.12)/.48);for(let k=0;k<35*end;k++){const q=k/35,x=-56+q*157,y=Math.sin(q*9)*24-15;circle(g,x,y,2+Math.sin(q*12)**2*3,c[1],true);if(q<end-.13)petal(g,x,y-6,8+Math.sin(q*17)**2*8,-.2,c[4]);}}
 },
 scroll(g,p,v,c){const open=s((p-.1)/.28)*(1-s((p-.61)/.18));if(v===0){const w=12+open*86;poly(g,[[-w,-56],[w,-56],[w,56],[-w,56]],c[2],c[1]);for(const side of[-1,1]){line(g,[[side*w,-67],[side*w,67]],c[1],7);line(g,[[side*w,-61],[side*w,61]],c[3],2);}if(w>28){line(g,[[-w*.8,25],[-w*.5,-9],[-w*.25,7],[0,-29],[w*.35,12],[w*.7,-5]],c[3],2);circle(g,w*.6,-30,6,c[4],true);}}
  if(v===1){const angle=.15+open*2.3;g.save();g.translate(0,58);const pts=[[0,0]];for(let i=0;i<=12;i++){const a=-Math.PI/2-angle/2+angle*i/12;pts.push([Math.cos(a)*112,Math.sin(a)*112]);}poly(g,pts,c[2],c[1]);for(let i=0;i<=12;i++){const a=-Math.PI/2-angle/2+angle*i/12;line(g,[[0,0],[Math.cos(a)*112,Math.sin(a)*112]],c[1]);}circle(g,0,0,4,c[4],true);g.restore();}
  if(v===2){const drop=s((p-.28)/.12),y=-40*(1-drop);g.save();g.translate(0,y);poly(g,[[-37,-35],[28,-48],[48,-29],[48,32],[-18,48],[-37,30]],c[3],c[1]);poly(g,[[-37,30],[-18,48],[48,32],[28,14]],c[4],c[1]);glyph(g,0,-5,17,c[1]);g.restore();if(drop>.9){poly(g,[[-51,42],[51,42],[51,70],[-51,70]],null,c[4]);for(let k=0;k<4;k++)line(g,[[-43+k*25,48],[-43+k*25,64]],c[4],2);}}
 },
 void(g,p,v,c){const r=18+s((p-.18)/.35)*73;if(v===0){for(let k=0;k<16;k++){const a=k*TAU/16;line(g,[[Math.cos(a)*r,Math.sin(a)*r*.68],[Math.cos(a)*111,Math.sin(a)*77]],c[0]+'a0');}ellipse(g,0,0,r,r*.68,c[2]);g.save();g.globalAlpha*=.09;g.fillStyle=c[2];g.beginPath();g.ellipse(0,0,r,r*.68,0,0,TAU);g.fill();g.restore();glyph(g,0,0,8,c[4]);}
  if(v===1){circle(g,0,0,54,c[2],true);g.save();g.beginPath();g.arc(0,0,54,0,TAU);g.clip();circle(g,Math.sin(p*TAU)*47,-8,52,c[3],true);g.restore();ellipse(g,0,0,84,64,c[0]+'70');circle(g,Math.cos(p*TAU)*84,Math.sin(p*TAU)*64,4,c[1],true);}
  if(v===2){const collapse=s((p-.53)/.23);for(let k=0;k<6;k++){const a=k*TAU/6+p*.8,d=67*(1-collapse);g.save();g.translate(Math.cos(a)*d,Math.sin(a)*d*.7);g.rotate(a);poly(g,[[0,-27],[17,-4],[7,25],[-17,7]],c[3],c[0]);line(g,[[-5,-17],[8,13]],c[2]);g.restore();}circle(g,0,0,4+collapse*5,c[1],true);}
 },
};
export function drawVariant(g,t,o,a){if(o.visible===false||t<=0||t>=a.duration*.96||o.intensity<=0)return;const p=t/a.duration,v=a.variant,c=palettes[o.palette]||palettes.jade,fade=s(p/.09)*(1-s((p-.77)/.19));g.save();g.translate(240,160);g.scale(o.scale??1,o.scale??1);g.lineCap='round';g.lineJoin='round';g.globalAlpha=fade*Math.min(1,o.intensity??1);
 if(o.sigil){const n=3+(a.number%5),r=103;g.save();g.globalAlpha*=.32;const pts=[];for(let k=0;k<n;k++){const angle=k*TAU/n-Math.PI/2;pts.push([Math.cos(angle)*r,Math.sin(angle)*r*.68]);}poly(g,pts,null,c[0]);for(let k=0;k<n;k++)circle(g,...pts[k],2,c[1],true);g.restore();}
 if(o.trails){g.save();g.globalAlpha*=.36;for(let k=0;k<3;k++){g.beginPath();for(let j=0;j<35;j++){const q=j/34,angle=q*(1.3+v*.25)+p*2+k*1.7+a.number*.3;const r=65+q*44;const x=Math.cos(angle)*r,y=Math.sin(angle)*r*.65;j?g.lineTo(x,y):g.moveTo(x,y);}g.strokeStyle=k===0?c[1]:c[0];g.lineWidth=.65+k*.2;g.stroke();}g.restore();}
 if(o.ink){g.save();g.translate(3,5);g.globalAlpha*=.23;drawers[a.family](g,p,v,[c[3],c[3],c[3],c[3],c[3]]);g.restore();}
 if(o.body){g.save();g.shadowColor=c[0];g.shadowBlur=o.glow?7*(o.intensity??1):0;drawers[a.family](g,p,v,c);g.restore();}
 if(o.impact){const pulse=Math.exp(-(((p-.56)/.06)**2));g.save();g.globalAlpha*=pulse;const rg=g.createRadialGradient(0,0,1,0,0,27);rg.addColorStop(0,c[2]);rg.addColorStop(.3,c[1]+'70');rg.addColorStop(1,c[1]+'00');g.fillStyle=rg;g.fillRect(-28,-28,56,56);g.restore();}
 if(o.particles){g.save();g.globalAlpha*=.65;const n=Math.round(34*(o.density??.7));for(let k=0;k<n;k++){const angle=k*2.399+a.seed,r=36+(k%7)*12+(p-.5)*20,x=Math.cos(angle)*r,y=Math.sin(angle)*r*.65-(p-.3)*13;circle(g,x,y,k%5===0?1.4:.7,k%4?c[0]:c[1],true);}g.restore();}g.restore();}
