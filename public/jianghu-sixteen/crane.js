// Original procedural 2D VFX. No image pan/zoom, imported game texture or screenshot.
const sat=x=>Math.max(0,Math.min(1,x)),smooth=x=>{x=sat(x);return x*x*(3-2*x)},mix=(a,b,t)=>a+(b-a)*t;
export const duration=4.8;
export function phase(t){return t<.7?'折纸成鹤':t<2?'分路绕行':t<2.7?'展鹤为符':t<3.5?'朱砂围合':t<4.5?'纸角消散':'场域归静'}
export function drawCrane(g,t){const W=960,H=640,C=[480,288];g.clearRect(0,0,W,H);g.fillStyle='#132b29';g.fillRect(0,0,W,H);let bg=g.createRadialGradient(480,300,30,480,300,520);bg.addColorStop(0,'#29443e');bg.addColorStop(1,'#0d201f');g.fillStyle=bg;g.fillRect(0,0,W,H);
// Low-contrast ground marker stays; it is not part of the disappearing effect.
g.strokeStyle='#73907b18';g.lineWidth=1;g.beginPath();g.ellipse(480,288,27,18,0,0,Math.PI*2);g.stroke();
if(t<=0||t>=4.5)return;
const fade=1-smooth((t-3.5)/1),appear=smooth(t/.18);const ends=[[320,202],[640,202],[480,420]];
const poly=(points,fill,stroke='#8f8b66')=>{g.beginPath();points.forEach(([x,y],i)=>i?g.lineTo(x,y):g.moveTo(x,y));g.closePath();g.fillStyle=fill;g.fill();if(stroke){g.strokeStyle=stroke;g.lineWidth=.85;g.stroke()}};
function pos(j,q){const a=[480+(j-1)*24,525],b=ends[j],side=j===0?-170:j===1?170:100;return [mix(a[0],b[0],q)+Math.sin(q*Math.PI)*side,mix(a[1],b[1],q)-Math.sin(q*Math.PI)*50]}
// The three paths remain narrow, tapering behind the moving object.
for(let j=0;j<3;j++){const fly=smooth((t-.65-j*.09)/1.28),[x,y]=pos(j,fly),fold=smooth(t/.65)*(1-smooth((t-2.05)/.56)),unfold=1-fold;
if(t>.65&&t<2.7){for(let k=0;k<22;k++){const q=Math.max(0,fly-k*.018),n=pos(j,q);g.beginPath();g.arc(n[0],n[1],Math.max(.35,2-k*.07),0,Math.PI*2);g.fillStyle=`rgba(127,187,165,${(1-k/22)*.22*fade})`;g.fill()}}
g.save();g.translate(x,y);const orient=mix(-.1,(j-1)*.43,smooth((t-.7)/1.1));g.rotate(orient);g.globalAlpha=appear*fade;
const flap=(Math.sin(t*13+j)*10)*smooth((t-.6)/.2)*(1-smooth((t-1.7)/.3));
// Same vertex topology continuously unfolds from the crane silhouette into paper.
const closed=[[-5,-23],[-58,-38-flap],[-24,4],[-7,22],[7,22],[24,4],[58,-38-flap],[5,-23]];
const open=[[-25,-44],[-25,-44],[-25,0],[-25,44],[25,44],[25,0],[25,-44],[25,-44]];
const pts=closed.map((p,k)=>[mix(p[0],open[k][0],unfold),mix(p[1],open[k][1],unfold)]);
g.shadowColor='#b0bb9677';g.shadowBlur=5;poly(pts,'#e9e1c2');g.shadowBlur=0;
poly([[0,-20],pts[1],pts[2],[0,17]],'#b9bb9c');poly([[0,-20],pts[6],pts[5],[0,17]],'#f4edd4');
if(fold>.02){g.globalAlpha=appear*fade*fold;poly([[-6,-10],[0,-35],[12,-44],[5,-20],[7,14]],'#f2ead3');poly([[0,15],[-4,30],[-14,42],[8,24]],'#c6c5a3');}
g.globalAlpha=appear*fade*unfold;
g.strokeStyle='#ad5440';g.lineWidth=2;g.beginPath();g.moveTo(-18,-34);g.lineTo(18,-34);g.moveTo(-18,34);g.lineTo(18,34);g.stroke();
const inkProgress=smooth((t-2.4-j*.08)/.55);g.save();g.beginPath();g.rect(-24,-40,48,80*inkProgress);g.clip();g.strokeStyle='#b85e44';g.lineWidth=2.2;g.beginPath();g.moveTo(-9,-23);g.lineTo(9,-23);g.lineTo(-6,-12);g.lineTo(10,-6);g.lineTo(-9,4);g.lineTo(9,11);g.lineTo(-4,23);g.moveTo(0,-28);g.lineTo(0,28);g.stroke();g.restore();
if(t>2.65){g.shadowColor='#e9c379';g.shadowBlur=10;g.fillStyle='#f4d698';for(const [cx,cy]of[[-21,-39],[21,39]])g.fillRect(cx-1.5,cy-1.5,3,3);g.shadowBlur=0;}g.restore();}
const seal=smooth((t-2.65)/.34)*fade;if(seal>0){g.save();g.globalAlpha=seal*.75;g.strokeStyle='#a75640';g.lineWidth=1.3;g.beginPath();ends.forEach(([x,y],j)=>{const p=smooth((t-2.65-j*.07)/.32),next=ends[(j+1)%3];g.moveTo(x,y);g.lineTo(mix(x,next[0],p),mix(y,next[1],p))});g.stroke();g.restore();const pulse=Math.exp(-Math.pow((t-3.12)/.15,2));const light=g.createRadialGradient(...C,0,...C,25+20*pulse);light.addColorStop(0,`rgba(255,236,186,${.75*pulse})`);light.addColorStop(.3,`rgba(237,193,115,${.24*pulse})`);light.addColorStop(1,'rgba(200,160,90,0)');g.fillStyle=light;g.fillRect(430,238,100,100);}
if(t>3.35){const p=smooth((t-3.35)/1.1);for(let j=0;j<27;j++){const e=ends[j%3],a=j*2.399,x=e[0]+Math.cos(a)*p*70,y=e[1]+Math.sin(a)*p*45-p*15;g.save();g.translate(x,y);g.rotate(a+p);g.globalAlpha=(1-p)*.55;poly([[0,-3],[4,2],[-3,3]],j%5===0?'#bd6450':'#d7cfac',null);g.restore();}}
}
