// Original geometric freeze marker. Historical mechanic != measured VFX timing.
export default {
 id:'ice-step',name:'前路凝霜',duration:3.5,family:'spatial',familyName:'落点研究',description:'前方一格 → 结晶展开 → 冰屑淡出；原创时序。',motion:'路径阻断',previewAt:.49,
 draw(g,t,o={}){if(o.visible===false||t<=0||t>=3.5)return;const p=t/3.5,a=Math.min(1,p*7)*Math.min(1,(1-p)*4),r=82*Math.min(1,p*4);g.save();g.translate(240,160);g.globalAlpha=a;g.strokeStyle='#b9e2e4';g.fillStyle='#86c5d12a';g.lineWidth=1.5;g.beginPath();for(let i=0;i<6;i++){const z=i*Math.PI/3;const x=Math.cos(z)*r,y=Math.sin(z)*r;i?g.lineTo(x,y):g.moveTo(x,y);}g.closePath();g.fill();g.stroke();for(let i=0;i<6;i++){const z=i*Math.PI/3;g.save();g.rotate(z);g.beginPath();g.moveTo(0,0);g.lineTo(r,0);g.moveTo(r*.4,0);g.lineTo(r*.62,-15);g.moveTo(r*.6,0);g.lineTo(r*.8,16);g.stroke();g.restore();}g.restore();}
};
