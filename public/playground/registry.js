import {catalog} from '../asset-lab/catalog.js';
import {rainBlades} from '../asset-lab/assets/rain-blades.js';
import fire from './examples/ground-fire.js';
import ice from './examples/ice-step.js';
import guard from './examples/jade-guard.js';
import {features} from '../asset-lab/controller.js';
export const defaults=Object.fromEntries(Object.entries(features).map(([k,v])=>[k,v.default]));
export function validateEffect(a){
 if(!a||typeof a.id!=='string'||!/^[a-z][a-z0-9-]{0,63}$/.test(a.id)||typeof a.name!=='string'||!a.name.trim()||a.name.length>80||!Number.isFinite(a.duration)||a.duration<=0||a.duration>30||typeof a.draw!=='function')throw new Error('JS 合同无效：需要 id、name、duration(0–30秒)、draw(ctx,t,options)。');
 return a;
}
export const effects=[...catalog.map(a=>({...a,source:`../asset-lab/variants/${a.id}-${a.family}.js`,origin:'既有36式'})),{...rainBlades,id:'rain-legacy',name:'听雨借锋 · 初版',family:'legacy',familyName:'历史样件',description:'保留初版纯绘制函数，与36式并排检查。',motion:rainBlades.subtitle,source:'../asset-lab/assets/rain-blades.js',origin:'既有独立JS'},...[fire,ice,guard].map(a=>({...a,source:`./examples/${a.id}.js`,origin:'原创空间研究'}))];
for(const a of effects)validateEffect(a);
if(new Set(effects.map(a=>a.id)).size!==effects.length)throw new Error('重复技能ID');
export const standalone=[
 {name:'纸鹤衔令 · 4.8秒',type:'独立Canvas播放器',url:'../jianghu-sixteen/animation.html',source:'../jianghu-sixteen/crane.js',note:'原函数自带清屏与背景，保持原样，不伪装成透明插件。'},
 {name:'江湖十六念 · 四项动作研究',type:'概念与动作研究',url:'../jianghu-sixteen/',source:'../jianghu-sixteen/motion.js',note:'05 / 09 / 14 / 16 使用完整场景绘制，保留原入口。'},
 {name:'青岚剑阵 V2',type:'Three.js / WebGL 2',url:'../',source:'https://github.com/liush2yuxjtu/create-game-asset/blob/main/src/qinglan-vfx.js',note:'3.2秒、一主剑六飞剑；独立WebGL运行时，未转成Canvas插件。'},
 {name:'36式 · A/B外部控制器',type:'已有参数工作台',url:'../asset-lab/',source:'../asset-lab/preview.js',note:'全局/单项覆盖、JSON配置与A/B比较保留。'},
];
