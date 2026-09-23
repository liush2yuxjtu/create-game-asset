// Versioned, renderer-independent feature contract. No DOM or clock ownership.
export const features = Object.freeze({
  visible: { label: '显示资产', type: 'boolean', default: true },
  body: { label: '主体', type: 'boolean', default: true },
  sigil: { label: '地面纹', type: 'boolean', default: true },
  trails: { label: '运动尾迹', type: 'boolean', default: true },
  particles: { label: '细碎粒子', type: 'boolean', default: true },
  glow: { label: '柔光', type: 'boolean', default: true },
  impact: { label: '生效脉冲', type: 'boolean', default: true },
  ink: { label: '墨色笔触', type: 'boolean', default: true },
  motion: { label: '时间推进', type: 'boolean', default: true },
  speed: { label: '速度', type: 'number', min: .25, max: 2, step: .25, default: 1 },
  intensity: { label: '强度', type: 'number', min: 0, max: 1.5, step: .1, default: 1 },
  scale: { label: '范围大小', type: 'number', min: .5, max: 1.3, step: .1, default: 1 },
  density: { label: '粒子密度', type: 'number', min: 0, max: 1, step: .1, default: .7 },
  palette: { label: '配色', type: 'select', options: { jade: '青玉 · 旧金', cinnabar: '朱砂 · 旧金', moon: '月白 · 青灰' }, default: 'jade' },
});
const own = (o,k) => Object.prototype.hasOwnProperty.call(o,k);
export function validateValue(key,value) {
  if (!own(features,key)) throw new Error('未知控制项：'+key);
  const f=features[key];
  if(f.type==='boolean' && typeof value==='boolean') return value;
  if(f.type==='number' && typeof value==='number' && Number.isFinite(value) && value>=f.min && value<=f.max) return value;
  if(f.type==='select' && typeof value==='string' && own(f.options,value)) return value;
  throw new Error('无效控制值：'+key);
}
export class AssetController {
  constructor(assets) {
    this.assets = new Map();
    for(const asset of assets){
      if(!asset.id || this.assets.has(asset.id) || !Array.isArray(asset.supports)) throw new Error('资产标识重复或能力声明缺失');
      for(const key of asset.supports) if(!own(features,key)) throw new Error('未知资产能力：'+key);
      this.assets.set(asset.id,asset);
    }
    this.reset();
  }
  reset(){this.global=Object.fromEntries(Object.entries(features).map(([k,f])=>[k,f.default]));this.overrides=Object.fromEntries([...this.assets.keys()].map(id=>[id,{}]));}
  asset(id){if(!this.assets.has(id))throw new Error('未知资产：'+id);return this.assets.get(id);}
  setGlobal(key,value){this.global[key]=validateValue(key,value);}
  setAsset(id,key,value){if(!this.asset(id).supports.includes(key))throw new Error('资产不支持：'+key);if(value===null)delete this.overrides[id][key];else this.overrides[id][key]=validateValue(key,value);}
  clearAsset(id){this.asset(id);this.overrides[id]={};}
  resolve(id){const a=this.asset(id);return Object.fromEntries(a.supports.map(k=>[k,own(this.overrides[id],k)?this.overrides[id][k]:this.global[k]]));}
  snapshot(){return JSON.parse(JSON.stringify({version:1,global:this.global,overrides:this.overrides}));}
  // Validate on a fresh controller, then atomically replace state. Reject wrong versions/IDs/values.
  restore(data){
    if(!data || data.version!==1 || !data.global || typeof data.global!=='object' || !data.overrides || typeof data.overrides!=='object' || Array.isArray(data.global) || Array.isArray(data.overrides))throw new Error('配置格式或版本不支持');
    const next=new AssetController([...this.assets.values()]);
    for(const [k,v]of Object.entries(data.global))next.setGlobal(k,v);
    for(const [id,values]of Object.entries(data.overrides)){
      next.asset(id);if(!values||typeof values!=='object'||Array.isArray(values))throw new Error('资产覆盖格式错误');
      for(const [k,v]of Object.entries(values))next.setAsset(id,k,v);
    }
    this.global=next.global;this.overrides=next.overrides;
  }
}
