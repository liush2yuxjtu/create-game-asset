// Original top-down 2D study: falling droplets pause, sharpen, pierce, then become rain.
// Pure renderer: options arrive from the outer controller; no DOM/localStorage/RAF here.
export const rainBlades = {
  id:'rain', name:'听雨借锋', subtitle:'凝雨 · 借锋 · 归雨', duration:4.2,
  supports:['visible','body','sigil','trails','particles','glow','impact','ink','motion','speed','intensity','scale','density','palette'],
  draw(ctx, time, options){drawRain(ctx,time,options);},
};
const clamp=x=>Math.max(0,Math.min(1,x)),ease=x=>{x=clamp(x);return x*x*(3-2*x)};
export function drawRain(g,t,o){
  if(!o.visible||t<=0||t>=4.05||o.intensity<=0)return;
  const palettes={jade:['#9bcbbb','#d9b777','#294c48'],cinnabar:['#d4876e','#e2bf80','#674037'],moon:['#ccdfdf','#c4c7ac','#38494f']};
  const [main,gold,ink]=palettes[o.palette];
  const fade=ease(t/.35)*(1-ease((t-3.05)/1));
  g.save();g.translate(240,160);g.scale(o.scale,o.scale);g.globalAlpha=fade*Math.min(1,o.intensity);g.lineCap='round';
  if(o.sigil){g.strokeStyle=main+'30';g.lineWidth=1;g.beginPath();g.ellipse(0,8,120,70,0,0,Math.PI*2);g.stroke();}
  const travel=ease((t-1.35)/.48),sharp=ease((t-.75)/.5)*(1-ease((t-2)/.5));
  for(let j=0;j<7;j++){
    const x=-85+j*27,y=-48+(j%3)*35+Math.sin(j*2)*8+(1-ease(t/.6))*-30;
    const px=x+travel*44,py=y-travel*67;
    if(o.ink){g.strokeStyle=ink;g.lineWidth=4;g.beginPath();g.moveTo(x-4,y+8);g.lineTo(px-4,py+10+sharp*19);g.stroke();}
    if(o.trails && travel>0 && t<3){g.strokeStyle=main+'70';g.lineWidth=1.4;g.beginPath();g.moveTo(px,py);g.quadraticCurveTo(x-12,y+23,x-18,y+42);g.stroke();}
    if(o.body){g.save();g.translate(px,py);g.rotate(.56);g.shadowColor=main;g.shadowBlur=o.glow?14*o.intensity:0;g.fillStyle=main;g.beginPath();g.moveTo(0,-7-sharp*27);g.quadraticCurveTo(7*(1-sharp)+1,5,0,9);g.quadraticCurveTo(-7*(1-sharp)-1,5,0,-7-sharp*27);g.fill();g.restore();}
  }
  if(o.impact){const p=Math.exp(-(((t-1.85)/.18)**2));g.strokeStyle=gold;g.globalAlpha=fade*p*Math.min(1,o.intensity);g.lineWidth=1.5;g.beginPath();g.ellipse(42,-54,8+(1-p)*24,5+(1-p)*15,0,0,Math.PI*2);g.stroke();}
  g.globalAlpha=fade*Math.min(1,o.intensity)*.65;
  if(o.particles){for(let j=0;j<Math.round(42*o.density);j++){const a=j*2.399,r=26+(j%9)*12,p=clamp((t-1.5)/2);const x=Math.cos(a)*r+25*p,y=Math.sin(a)*r*.6+37*p;g.fillStyle=j%6===0?gold:main;g.beginPath();g.arc(x,y,j%4===0?1.5:.8,0,Math.PI*2);g.fill();}}
  g.restore();
}
