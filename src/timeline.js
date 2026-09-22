export const DURATION = 3.2;
export const STATES = [
  {id:'charge',label:'蓄势',start:0,end:1.1,inspect:.8},
  {id:'slash',label:'斩击',start:1.1,end:1.8,inspect:1.48},
  {id:'dissipate',label:'消散',start:1.8,end:3.2,inspect:2.5}
];
export const clamp=(x,a=0,b=1)=>Math.max(a,Math.min(b,x));
export const smooth=(a,b,x)=>{const t=clamp((x-a)/(b-a));return t*t*(3-2*t);};
export function sample(seconds){
 if(!Number.isFinite(seconds))throw new TypeError('seconds must be finite');
 const t=clamp(seconds,0,DURATION);
 return {t,state:t===DURATION?'complete':STATES.find(s=>t>=s.start&&t<s.end).id,
 charge:smooth(0,.9,t),slash:smooth(1.1,1.8,t),
 life:smooth(0,.25,t)*(1-smooth(1.9,3.2,t)),
 dissolve:smooth(1.9,3.2,t),burst:smooth(1.1,1.2,t)*(1-smooth(1.3,2.4,t))};
}
