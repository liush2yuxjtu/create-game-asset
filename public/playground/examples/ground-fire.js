// Original spatial study inspired by the historical ground-fire mechanic, NOT game art.
// Self-contained module: also suitable for the local JS sandbox importer.
export default {
 id:'ground-fire',name:'足下流火',duration:3.6,family:'spatial',familyName:'落点研究',description:'脚下成域 → 火舌外展 → 余烬退场；原创表现，非原游戏复刻。',motion:'落点范围',previewAt:.49,
 draw(g,t,o={}){
  if(o.visible===false||t<=0||t>=3.6)return;
  const p=t/3.6,a=Math.min(1,p*8)*Math.min(1,(1-p)*5),r=90*Math.min(1,p*5);
  g.save();g.translate(240,160);g.globalAlpha=a;g.strokeStyle='#e4a659';g.fillStyle='#b6523828';g.lineWidth=2;g.beginPath();g.arc(0,0,r,0,Math.PI*2);g.fill();g.stroke();
  for(let i=0;i<18;i++){const z=i*2.399,rr=r*(.2+(i%5)/6),x=Math.cos(z)*rr,y=Math.sin(z)*rr,flame=12+Math.sin(t*10+i)*6;g.fillStyle=i%3?'#dc8950':'#f3d292';g.beginPath();g.moveTo(x-5,y+5);g.quadraticCurveTo(x-11,y-4,x+Math.sin(t*4+i)*4,y-flame);g.quadraticCurveTo(x+12,y+1,x+5,y+6);g.closePath();g.fill();}g.restore();
 }
};
