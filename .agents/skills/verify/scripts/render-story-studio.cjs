// 用法：node .agents/skills/verify/scripts/render-story-studio.cjs <StoryStudio.dc.html>  → 按画布保存的默认值无头渲染故事工作台，打印 L4 屏（JSON）；verify-hypit-video.py 的 H 检查用它核对设计稿与成片一致
const fs = require('fs');
const html = fs.readFileSync(process.argv[2], 'utf8');
const m = html.match(/<script type="text\/x-dc" data-dc-script data-props=(["'])([\s\S]*?)\1>([\s\S]*?)<\/script>/);
const props = JSON.parse(m[2].replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&'));
const defaults = {};
for (const [k, v] of Object.entries(props)) if (k[0] !== '$' && v && 'default' in v) defaults[k] = v.default;
global.DCLogic = class { constructor(p) { this.props = p || {}; this.state = {}; } setState(o) { this.state = Object.assign({}, this.state, o); } };
const Component = new Function('DCLogic', m[3] + '\nreturn Component;')(global.DCLogic);
const r = new Component(defaults).renderVals();
console.log(JSON.stringify({ defaults, chain: r.chain, screens: r.screens.map(s => ({ n: s.n, t: s.t, moment: s.momentName, cap: s.cap, vo: s.vo })), rows: r.beatRows.map(b => ({ n: b.n, cap: b.cap, vo: b.vo, ok: b.voOk })) }, null, 1));
