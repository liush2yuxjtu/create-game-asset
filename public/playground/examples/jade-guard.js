// Original defensive zone sample. No shield/damage gameplay binding.
export default {
 id:'jade-guard',name:'青玉守御',duration:4,family:'spatial',familyName:'落点研究',description:'护域显形 → 八片环绕 → 合拢归静；原创护盾示意。',motion:'自身环绕',previewAt:.49,
 draw(g,t,o={}){if(o.visible===false||t<=0||t>=4)return;const p=t/4,a=Math.min(1,p*8)*Math.min(1,(1-p)*5),r=80*(.8+.2*Math.sin(p*Math.PI));g.save();g.translate(240,160);g.globalAlpha=a;g.strokeStyle='#a7d9be';g.lineWidth=3;for(let i=0;i<8;i++){const z=i*Math.PI/4+t*.24;g.beginPath();g.arc(0,0,r,z,z+.52);g.stroke();g.save();g.rotate(z+.26);g.fillStyle='#edcf8b';g.fillRect(r-3,-3,6,6);g.restore();}g.lineWidth=1;g.strokeStyle='#b3d9be50';g.beginPath();g.arc(0,0,r-13,0,Math.PI*2);g.stroke();g.restore();}
};
