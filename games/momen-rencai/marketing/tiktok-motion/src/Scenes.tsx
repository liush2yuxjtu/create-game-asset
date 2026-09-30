import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {C, W, H, BEAT, clamp, lerp, prog, smooth, outExpo, outBack, rand, smoothPath, shake} from './lib';
import {Sprite, SPRITE_W, SPRITE_H} from './Sprite';
import pix from './pixtext.json';

const SERIF = '"Noto Serif CJK SC", serif';
const SANS = '"Noto Sans CJK SC", sans-serif';

const Caption: React.FC<{text: string; y?: number; size?: number; color?: string; o?: number; hl?: string}> = ({
  text,
  y = 250,
  size = 64,
  color = C.ink,
  o = 1,
  hl,
}) => (
  <div
    style={{
      position: 'absolute',
      top: y,
      left: 60,
      right: 60,
      textAlign: 'center',
      fontFamily: SANS,
      fontWeight: 900,
      fontSize: size,
      color,
      opacity: o,
      letterSpacing: 4,
      textShadow: '0 6px 0 rgba(0,0,0,0.85), 0 0 24px rgba(0,0,0,0.9)',
    }}
  >
    <span style={{background: 'rgba(11,10,15,0.82)', padding: '8px 26px', boxDecorationBreak: 'clone'}}>
    {hl ? text.split(hl).flatMap((p, i, a) => (i < a.length - 1 ? [p, <span key={i} style={{color: C.red}}>{hl}</span>] : [p])) : text}
    </span>
  </div>
);

/* ───────── S1 · HOOK — kinetic type slam + rolling death counter (ref: pinterest-focus hard cuts & oversize type) ───────── */
export const S1Hook: React.FC<{deaths?: number}> = ({deaths = 37}) => {
  const f = useCurrentFrame();
  const chars = '你已经死了'.split('');
  const sh = shake(f, [2, 22, 50], 30);
  const n = Math.round(lerp(1, deaths, outExpo(prog(f, 20, 26))));
  const numIn = outBack(prog(f, 18, 8));
  const flash = f >= 56 ? 1 - (f - 56) / 4 : 0;
  return (
    <AbsoluteFill style={{background: C.bg, transform: `translate(${sh.x}px,${sh.y}px)`}}>
      <div style={{position: 'absolute', top: 330, width: W, display: 'flex', justifyContent: 'center'}}>
        {chars.map((ch, i) => {
          const st = i === 0 ? -3 : 4 + i * 3;
          const p = prog(f, st, 7);
          const e = outBack(p, 2.4);
          const side = i % 2 ? 1 : -1;
          return (
            <span
              key={i}
              style={{
                fontFamily: SERIF,
                fontWeight: 900,
                fontSize: i === 0 ? 230 : 170,
                color: C.ink,
                display: 'inline-block',
                opacity: p > 0 ? 1 : 0,
                transform: `translate(${(1 - e) * side * 380}px, ${i === 0 ? 0 : 20}px) scale(${lerp(i === 0 ? 3 : 1.8, 1, e)}, ${lerp(0.5, 1, e)}) rotate(${(1 - e) * side * 18}deg)`,
                lineHeight: 1,
              }}
            >
              {ch}
            </span>
          );
        })}
      </div>
      <div
        style={{
          position: 'absolute',
          top: 620,
          width: W,
          textAlign: 'center',
          fontFamily: SANS,
          fontWeight: 900,
          fontSize: 760,
          lineHeight: 1,
          color: C.red,
          letterSpacing: -40,
          transform: `scale(${lerp(2.2, 1, numIn)}) skewX(${-8 * (1 - numIn)}deg)`,
          opacity: f >= 18 ? 1 : 0,
          textShadow: `0 0 80px rgba(224,42,60,0.55)`,
        }}
      >
        {n}
      </div>
      <div
        style={{
          position: 'absolute',
          top: 1330,
          width: W,
          textAlign: 'center',
          fontFamily: SERIF,
          fontWeight: 900,
          fontSize: 150,
          color: C.ink,
          opacity: f >= 46 ? 1 : 0,
          transform: `scale(${lerp(1.8, 1, outBack(prog(f, 46, 6)))})`,
        }}
      >
        次
      </div>
      <AbsoluteFill style={{background: '#fff', opacity: clamp(flash)}} />
    </AbsoluteFill>
  );
};

/* ───────── S2 · TWIST — "但这一次" → giant 你 记 得 crowd the frame (ref: pinterest-focus "BABY" squeeze) ───────── */
export const S2Twist: React.FC<{sub?: string}> = ({sub = '带着前世记忆 · 重生魔门'}) => {
  const f = useCurrentFrame();
  if (f < 12) {
    return (
      <AbsoluteFill style={{background: C.bg, justifyContent: 'center', alignItems: 'center'}}>
        <div style={{fontFamily: SANS, fontWeight: 900, fontSize: 96, color: C.ink, letterSpacing: 30}}>
          但<span style={{opacity: f >= 5 ? 1 : 0}}>这一次</span>
        </div>
      </AbsoluteFill>
    );
  }
  const g = f - 12;
  const sh = shake(g, [0, 6, 12], 34);
  const L = [
    {ch: '你', x: -120, y: 120, r: -13, st: 0, c: C.ink, s: 820},
    {ch: '记', x: 250, y: 720, r: 9, st: 6, c: C.jade, s: 900},
    {ch: '得', x: -60, y: 1250, r: -5, st: 12, c: C.ink, s: 820},
  ];
  const push = lerp(1, 1.12, smooth(prog(g, 14, 34)));
  return (
    <AbsoluteFill style={{background: C.red, overflow: 'hidden', transform: `translate(${sh.x}px,${sh.y}px)`}}>
      <AbsoluteFill style={{transform: `scale(${push})`}}>
        {L.map((l, i) => {
          const e = outBack(prog(g, l.st, 7), 2.2);
          const from = i % 2 ? 1 : -1;
          return (
            <div
              key={i}
              style={{
                position: 'absolute',
                left: l.x,
                top: l.y - 330,
                fontFamily: SERIF,
                fontWeight: 900,
                fontSize: l.s,
                lineHeight: 1,
                color: l.c,
                opacity: g >= l.st ? 1 : 0,
                transform: `translateX(${(1 - e) * from * 900}px) rotate(${l.r + (1 - e) * from * 30}deg) scaleX(${lerp(0.6, 1, e)})`,
                textShadow: '0 20px 0 rgba(0,0,0,0.35)',
              }}
            >
              {l.ch}
            </div>
          );
        })}
      </AbsoluteFill>
      <div
        style={{
          position: 'absolute',
          top: 1420,
          left: 0,
          right: 0,
          textAlign: 'center',
          opacity: g >= 22 ? 1 : 0,
        }}
      >
        <span style={{background: C.bg, color: C.ink, fontFamily: SANS, fontWeight: 900, fontSize: 60, padding: '10px 28px', letterSpacing: 6}}>
          {sub}
        </span>
      </div>
    </AbsoluteFill>
  );
};

/* ───────── S3 · MEMORY RINGS — counter-rotating text rings around the sprite (ref: pinterest-focus "I cannot focus" rings) ───────── */
export const S3Rings: React.FC = () => {
  const f = useCurrentFrame();
  const t = f / 30;
  const cx = W / 2;
  const cy = 900;
  const intro = outBack(prog(f, 0, 12), 1.5);
  const rings = [
    {r: 300, dir: 1, text: '记忆 · 轮回 · 记忆 · 轮回 · 记忆 · 轮回 · ', size: 46, col: C.ink},
    {r: 400, dir: -1, text: '第36次 · 第35次 · 第34次 · 第33次 · 第32次 · 第31次 · 第30次 · ', size: 38, col: C.red},
    {r: 500, dir: 1, text: '死亡 · 重生 · 死亡 · 重生 · 死亡 · 重生 · 死亡 · 重生 · 死亡 · 重生 · ', size: 44, col: C.dim},
  ];
  const px = 24;
  const bob = Math.sin(t * 5) * 10;
  return (
    <AbsoluteFill style={{background: C.bg}}>
      <svg width={W} height={H} style={{position: 'absolute'}}>
        <defs>
          {rings.map((r, i) => (
            <path key={i} id={`ring${i}`} d={`M ${cx - r.r},${cy} a ${r.r},${r.r} 0 1,1 ${r.r * 2},0 a ${r.r},${r.r} 0 1,1 ${-r.r * 2},0`} />
          ))}
          <radialGradient id="aura">
            <stop offset="0" stopColor={C.red} stopOpacity="0.45" />
            <stop offset="1" stopColor={C.red} stopOpacity="0" />
          </radialGradient>
        </defs>
        <circle cx={cx} cy={cy} r={420 + Math.sin(t * 6) * 20} fill="url(#aura)" />
        {rings.map((r, i) => {
          const phase = (i * 0.12 + 0.06) * 12;
          const sc = lerp(0.3, 1, outBack(prog(f, i * 3, 12), 1.4));
          return (
            <g key={i} transform={`translate(${cx} ${cy}) rotate(${r.dir * (t * 40 + phase * 10) + (i === 1 ? Math.sin(t * 3) * 6 : 0)}) scale(${sc}) translate(${-cx} ${-cy})`}>
              <text fontFamily={SANS} fontWeight={900} fontSize={r.size} fill={r.col} letterSpacing={4}>
                <textPath href={`#ring${i}`}>{r.text}</textPath>
              </text>
            </g>
          );
        })}
        {/* memory shards orbiting */}
        {Array.from({length: 18}, (_, i) => {
          const a = rand(i) * Math.PI * 2 + t * (0.6 + rand(i + 9));
          const rr = 200 + rand(i + 3) * 420;
          const s = 10 + rand(i + 5) * 18;
          return <rect key={i} x={cx + Math.cos(a) * rr} y={cy + Math.sin(a) * rr * 0.9} width={s} height={s} fill={i % 3 ? C.jade : C.gold} opacity={0.8 * intro} />;
        })}
      </svg>
      <div style={{position: 'absolute', left: cx - (SPRITE_W * px) / 2, top: cy - (SPRITE_H * px) / 2 + bob, transform: `scale(${intro})`}}>
        <Sprite px={px} eyeGlow={0.6 + 0.4 * Math.sin(t * 8)} />
      </div>
      <Caption text={f < 38 ? '每一次死亡' : '都会被你记住'} y={230} size={78} />
    </AbsoluteFill>
  );
};

/* ───────── S4 · LENS — magnifier hops across a blurred field of threats (ref: eagle-lens focus tracking) ───────── */
const THREATS = ['夺舍', '炉鼎', '心魔', '背刺', '灭口', '天劫', '毒丹', '血祭', '长老', '师兄', '叛徒', '献祭'];
const DEFAULT_HOPS: {w: string; x: number; y: number}[] = [
  {w: '长老', x: 0, y: 0},
  {w: '炉鼎', x: 150, y: -160},
  {w: '师兄', x: -170, y: 90},
  {w: '背刺', x: 60, y: 210},
  {w: '毒丹', x: -120, y: -210},
  {w: '灭口', x: 190, y: 60},
  {w: '天劫', x: -40, y: -60},
  {w: '血祭', x: 130, y: 250},
  {w: '心魔', x: -190, y: -120},
  {w: '先下手', x: 0, y: 30},
];
export const S4Lens: React.FC<{hops?: {w: string; x: number; y: number}[]; cap1?: string; cap2?: string; hl1?: string}> = ({hops = DEFAULT_HOPS, cap1 = '魔门里 人人都想要你的命', cap2 = '但你 记得他们的每一步', hl1 = '要你的命'}) => {
  const HOPS = hops;
  const f = useCurrentFrame();
  const t = f / 30;
  const k = Math.min(HOPS.length - 1, Math.floor(f / BEAT));
  const p = smooth((f - k * BEAT) / 9);
  const prev = HOPS[Math.max(0, k - 1)];
  const next = HOPS[k];
  const x = lerp(prev.x, next.x, p);
  const y = lerp(prev.y, next.y, p);
  const cx = W / 2 + x * 0.8;
  const cy = 900 + y * 0.7;
  const r = 250;
  const last = k === HOPS.length - 1;
  const angle = smoothPath(t, [[0, -8], [1, 12], [2, -10], [3, 14], [4, -6], [5, 0]], 0.3);
  const circles = Array.from({length: 40}, (_, i) => ({
    x: ((i * 257) % 1300) - 650,
    y: ((i * 173) % 1500) - 750,
    r: 60 + ((i * 31) % 60),
    label: THREATS[i % THREATS.length],
  }));
  const field = (sharp: boolean) => (
    <g transform={`translate(${W / 2} 900) translate(${-x * 1.6} ${-y * 1.6})`}>
      {circles.map((c, i) => (
        <g key={i} transform={`translate(${c.x + Math.sin(t * 0.8 + i) * 12} ${c.y + Math.cos(t * 0.9 + i) * 14})`}>
          <circle r={c.r} fill="none" stroke={sharp ? C.red : '#3a2530'} strokeWidth={3} />
          <text y={14} textAnchor="middle" fontFamily={SANS} fontWeight={900} fontSize={40} fill={sharp ? '#b44a58' : '#3d3038'}>
            {c.label}
          </text>
        </g>
      ))}
      <g transform={`translate(${x * 2.6} ${y * 2.3})`}>
        <circle r={150} fill="#050407" stroke={last ? C.jade : C.red} strokeWidth={4} />
        <text y={last ? 22 : 26} textAnchor="middle" fontFamily={SERIF} fontWeight={900} fontSize={last ? (next.w.length > 3 ? 54 : 72) : 84} fill={last ? C.jade : C.ink}>
          {next.w}
        </text>
      </g>
    </g>
  );
  return (
    <AbsoluteFill style={{background: '#000'}}>
      <svg width={W} height={H} style={{position: 'absolute'}}>
        <defs>
          <filter id="soft">
            <feGaussianBlur stdDeviation="7" />
          </filter>
          <clipPath id="lens">
            <circle cx={cx} cy={cy} r={r} />
          </clipPath>
          <radialGradient id="glow">
            <stop offset="0" stopColor={last ? C.jade : C.red} stopOpacity="0.4" />
            <stop offset="1" stopColor="#000" stopOpacity="0" />
          </radialGradient>
        </defs>
        <g opacity={0.8} filter="url(#soft)">
          {field(false)}
        </g>
        <g clipPath="url(#lens)">
          <rect width={W} height={H} fill="#000" />
          {field(true)}
          <circle cx={cx} cy={cy} r={r} fill="url(#glow)" />
        </g>
        <g transform={`translate(${cx} ${cy}) rotate(${angle})`}>
          <circle r={r} stroke={C.ink} strokeWidth={8} fill="none" />
          <circle r={r - 14} stroke={C.ink} strokeWidth={2} fill="none" opacity={0.4} />
          <rect x={-24} y={r + 6} width={48} height={330} rx={24} fill={C.bg} stroke={C.ink} strokeWidth={8} />
        </g>
      </svg>
      <Caption text={f < (HOPS.length - 2) * BEAT ? cap1 : cap2} y={220} size={70} hl={f < (HOPS.length - 2) * BEAT ? hl1 : undefined} />
    </AbsoluteFill>
  );
};

/* ───────── S5 · CHAPTER GALLERY — 7 cards, gaussian-smoothed camera (ref: six-card-gallery v2 continuous camera) ───────── */
const CHAPTERS = ['入门试炼', '炉鼎之约', '血祭大典', '叛出师门', '夺舍之夜', '魔尊归来', '？？？'];
const NUM = ['一', '二', '三', '四', '五', '六', '七'];
const SKY = [
  ['#1b1030', '#4a1a3a'],
  ['#0d1a2a', '#2b4a5a'],
  ['#2a0808', '#8a1a1a'],
  ['#101010', '#3a3a4a'],
  ['#1a0a2a', '#5a2a6a'],
  ['#050505', '#6a0a14'],
  ['#000000', '#1a1a1a'],
];
const PixelScene: React.FC<{i: number; w: number; h: number; t: number}> = ({i, w, h, t}) => {
  const P = 20;
  const cols = Math.ceil(w / P);
  const rows = Math.ceil(h / P);
  const blocks: React.ReactNode[] = [];
  for (let c = 0; c < cols; c++) {
    const hgt = Math.floor(rows * (0.35 + 0.18 * Math.sin(c * 0.55 + i) + 0.08 * rand(c + i * 13)));
    for (let r = rows - hgt; r < rows; r++) {
      blocks.push(<rect key={`${c}-${r}`} x={c * P} y={r * P} width={P} height={P} fill={r === rows - hgt ? SKY[i][1] : '#07060a'} />);
    }
  }
  const moonX = w * (0.25 + 0.5 * rand(i + 2));
  return (
    <svg width={w} height={h}>
      <defs>
        <linearGradient id={`sky${i}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={SKY[i][0]} />
          <stop offset="1" stopColor={SKY[i][1]} />
        </linearGradient>
      </defs>
      <rect width={w} height={h} fill={`url(#sky${i})`} />
      {i === 6 ? (
        <text x={w / 2} y={h * 0.55} textAnchor="middle" fontFamily={SERIF} fontWeight={900} fontSize={260} fill={C.red} opacity={0.5 + 0.5 * Math.sin(t * 10)}>
          ？
        </text>
      ) : (
        <rect x={moonX} y={h * 0.14} width={P * 5} height={P * 5} fill={i % 2 ? C.ink : C.red} opacity={0.9} />
      )}
      {blocks}
      {i !== 6 && (
        <g transform={`translate(${w / 2 - 8 * 9} ${h - 17 * 9 - 60 + Math.sin(t * 6 + i) * 4})`}>
          <Sprite px={9} />
        </g>
      )}
    </svg>
  );
};
export const S5Gallery: React.FC = () => {
  const f = useCurrentFrame();
  const t = f / 30;
  const CW = 500;
  const CH = 640;
  const GAP = 90;
  // camera x travels across the 7 cards laid out in two staggered rows
  const camX = smoothPath(t, [[0, 0], [0.9, 0], [1.6, 1], [2.3, 2], [3.0, 3.2], [3.6, 3.9], [4.5, 3.9]], 0.3);
  const camY = smoothPath(t, [[0, 0], [1.2, 0.2], [2.4, -0.2], [3.6, 0.1], [4.5, 0]], 0.4);
  const zoom = smoothPath(t, [[0, 1.25], [0.9, 1], [3.4, 1], [4.2, 0.9], [4.5, 0.9]], 0.35);
  const cards = CHAPTERS.map((name, i) => ({
    name,
    i,
    x: i * (CW * 0.62 + GAP * 0.5),
    y: i % 2 ? 1330 : 700,
    depth: i % 2 ? 0.85 : 1,
  }));
  const cur = clamp(Math.round(camX * 1.6), 0, 6);
  return (
    <AbsoluteFill style={{background: C.bg, overflow: 'hidden'}}>
      <svg width={W} height={H} style={{position: 'absolute', opacity: 0.25}}>
        {Array.from({length: 30}, (_, i) => (
          <line key={i} x1={((i * 80 - camX * 300) % 2400) - 200} y1={0} x2={((i * 80 - camX * 300) % 2400) - 200} y2={H} stroke={C.dim} strokeWidth={1} />
        ))}
      </svg>
      <AbsoluteFill style={{transform: `scale(${zoom})`}}>
        {cards.map((c) => {
          const px = W / 2 + (c.x - camX * (CW * 0.62 + GAP * 0.5) * 1.6) * c.depth - CW / 2;
          const py = c.y - camY * 80 - CH / 2;
          const inE = outBack(prog(f, c.i * 2, 10), 1.3);
          return (
            <div
              key={c.i}
              style={{
                position: 'absolute',
                left: px,
                top: py,
                width: CW,
                height: CH,
                background: C.ink,
                padding: 16,
                boxSizing: 'border-box',
                transform: `scale(${inE * c.depth}) rotate(${(c.i % 2 ? 1 : -1) * 2}deg)`,
                boxShadow: c.i === cur ? `0 0 0 8px ${C.red}, 0 30px 60px rgba(0,0,0,0.7)` : '0 30px 60px rgba(0,0,0,0.7)',
              }}
            >
              <PixelScene i={c.i} w={CW - 32} h={CH - 180} t={t} />
              <div style={{fontFamily: SANS, fontWeight: 900, fontSize: 38, color: C.red, marginTop: 14, letterSpacing: 6}}>第{NUM[c.i]}章</div>
              <div style={{fontFamily: SERIF, fontWeight: 900, fontSize: 74, color: C.bg, lineHeight: 1.1}}>{c.name}</div>
            </div>
          );
        })}
      </AbsoluteFill>
      <Caption text={f < 66 ? '7 章剧情' : '每个选择 都会被记住'} y={210} size={80} />
    </AbsoluteFill>
  );
};

/* ───────── S6 · BRANCH & CONVERGE — Detroit-style flowchart drawing itself ───────── */
export const S6Branch: React.FC<{rowsN?: number; nEnd?: number; cap?: string}> = ({rowsN = 7, nEnd = 8, cap = '分支 → 收束 → 再分支'}) => {
  const f = useCurrentFrame();
  const t = f / 30;
  const top = 380;
  const step = rowsN > 5 ? 150 : 190;
  const nodes: {x: number; y: number; row: number}[] = [];
  const edges: {a: [number, number]; b: [number, number]; row: number}[] = [];
  for (let r = 0; r < rowsN; r++) {
    const y = top + r * step;
    const main: [number, number] = [W / 2, y];
    nodes.push({x: main[0], y: main[1], row: r});
    if (r < rowsN - 1) {
      const n = 2 + (r % 2);
      for (let k = 0; k < n; k++) {
        const bx = W / 2 + (k - (n - 1) / 2) * 280;
        const mid: [number, number] = [bx, y + step / 2];
        nodes.push({x: bx, y: mid[1], row: r + 0.5});
        edges.push({a: main, b: mid, row: r});
        edges.push({a: mid, b: [W / 2, y + step], row: r + 0.5});
      }
    }
  }
  const endY = top + (rowsN - 1) * step + 220;
  const endings = Array.from({length: nEnd}, (_, i) => ({x: W / 2 + (i - (nEnd - 1) / 2) * (nEnd > 4 ? 128 : 200), y: endY + (i % 2) * 40}));
  const reveal = (row: number) => clamp((f + 4 - row * 5) / 6);
  const endRev = (i: number) => clamp((f - 40 - i * 2) / 5);
  return (
    <AbsoluteFill style={{background: C.bg}}>
      <svg width={W} height={H} style={{position: 'absolute'}}>
        {edges.map((e, i) => {
          const len = Math.hypot(e.b[0] - e.a[0], e.b[1] - e.a[1]);
          const p = reveal(e.row);
          return (
            <line key={i} x1={e.a[0]} y1={e.a[1]} x2={e.b[0]} y2={e.b[1]} stroke={C.ink} strokeWidth={5} strokeDasharray={len} strokeDashoffset={len * (1 - p)} opacity={0.85} />
          );
        })}
        {endings.map((e, i) => {
          const a: [number, number] = [W / 2, top + (rowsN - 1) * step];
          const len = Math.hypot(e.x - a[0], e.y - a[1]);
          return <line key={`l${i}`} x1={a[0]} y1={a[1]} x2={e.x} y2={e.y} stroke={i === nEnd - 1 ? C.jade : C.red} strokeWidth={4} strokeDasharray={len} strokeDashoffset={len * (1 - endRev(i))} />;
        })}
        {nodes.map((n, i) => {
          const s = outBack(reveal(Math.floor(n.row) + (n.row % 1 ? 0.6 : 0)), 2);
          const isMain = n.row % 1 === 0;
          return isMain ? (
            <polygon key={i} points={`${n.x},${n.y - 34 * s} ${n.x + 34 * s},${n.y} ${n.x},${n.y + 34 * s} ${n.x - 34 * s},${n.y}`} fill={C.red} stroke={C.ink} strokeWidth={3} />
          ) : (
            <circle key={i} cx={n.x} cy={n.y} r={18 * s} fill={C.bg} stroke={C.ink} strokeWidth={5} />
          );
        })}
        {endings.map((e, i) => (
          <circle key={`e${i}`} cx={e.x} cy={e.y} r={34 * outBack(endRev(i), 2)} fill={i === nEnd - 1 ? C.jade : C.red} stroke={C.ink} strokeWidth={4} />
        ))}
        {endings.map((e, i) => (
          <text key={`t${i}`} x={e.x} y={e.y + 13} textAnchor="middle" fontFamily={SANS} fontWeight={900} fontSize={36} fill={C.bg} opacity={endRev(i)}>
            {i + 1}
          </text>
        ))}
      </svg>
      <Caption text={cap} y={200} size={66} />
      <div
        style={{
          position: 'absolute',
          top: endY + 110,
          width: W,
          textAlign: 'center',
          fontFamily: SERIF,
          fontWeight: 900,
          fontSize: 120,
          color: C.ink,
          opacity: f >= 50 ? 1 : 0,
          transform: `scale(${lerp(1.6, 1, outBack(prog(f, 50, 7)))}) rotate(${Math.sin(t * 20) * (f < 58 ? 3 : 0)}deg)`,
        }}
      >
        <span style={{color: C.red}}>{nEnd}</span> 种结局
      </div>
    </AbsoluteFill>
  );
};

/* ───────── S7 · TITLE — pixels fly in to form 魔门人材, CTA, then loop back to the hook's "你" ───────── */
export const S7Title: React.FC<{tag?: string; q?: string; cta?: string; loopAt?: number}> = ({tag = 'GBA 像素 · 修仙 · 轮回', q = '你会选哪条路？', cta = '评论区告诉我 · 第 38 次轮回见', loopAt = 69}) => {
  const f = useCurrentFrame();
  const rows = (pix as {title: string[]}).title;
  const P = 9;
  const tw = rows[0].length * P;
  const ox = (W - tw) / 2;
  const oy = 640;
  const cells: React.ReactNode[] = [];
  let idx = 0;
  const sweep = ((f - 26) / 20) * (tw + 400) - 200;
  rows.forEach((row, y) =>
    row.split('').forEach((b, x) => {
      if (b !== '1') return;
      idx++;
      const d = rand(idx);
      const p = outExpo(prog(f, d * 10, 16));
      const sx = (rand(idx + 1) - 0.5) * 2400;
      const sy = (rand(idx + 2) - 0.5) * 3000;
      const tx = ox + x * P;
      const ty = oy + y * P;
      const lit = Math.abs(x * P - sweep) < 60;
      cells.push(<rect key={idx} x={lerp(tx + sx, tx, p)} y={lerp(ty + sy, ty, p)} width={P} height={P} fill={lit ? C.jade : C.red} />);
    }),
  );
  const loop = f >= loopAt;
  if (loop) {
    // last frames echo the opening slam → seamless loop into S1
    const e = outBack(prog(f, loopAt, 5), 2.4);
    return (
      <AbsoluteFill style={{background: C.bg}}>
        <div style={{position: 'absolute', top: 330, width: W, textAlign: 'center'}}>
          <span style={{fontFamily: SERIF, fontWeight: 900, fontSize: 230, color: C.ink, display: 'inline-block', transform: `translateX(-340px) scale(${lerp(3, 1.3, e)})`, lineHeight: 1}}>你</span>
        </div>
      </AbsoluteFill>
    );
  }
  return (
    <AbsoluteFill style={{background: C.bg}}>
      <svg width={W} height={H} style={{position: 'absolute', filter: 'drop-shadow(0 0 22px rgba(224,42,60,0.6))'}}>
        {cells}
      </svg>
      <div style={{position: 'absolute', top: 470, width: W, textAlign: 'center', fontFamily: SANS, fontWeight: 900, fontSize: 44, color: C.dim, letterSpacing: 18, opacity: f > 14 ? 1 : 0}}>
        {tag}
      </div>
      <div style={{position: 'absolute', top: 1020, width: W, textAlign: 'center', fontFamily: SANS, fontWeight: 900, fontSize: 76, color: C.ink, opacity: f > 26 ? 1 : 0, transform: `translateY(${(1 - outExpo(prog(f, 26, 8))) * 40}px)`}}>
        {q}
      </div>
      <div style={{position: 'absolute', top: 1130, width: W, textAlign: 'center', fontFamily: SANS, fontWeight: 900, fontSize: 52, color: C.red, opacity: f > 36 ? 1 : 0}}>
        {cta}
      </div>
      <div style={{position: 'absolute', left: W / 2 - 8 * 11, top: 1270 + Math.sin(f / 4) * 6}}>
        <Sprite px={11} />
      </div>
    </AbsoluteFill>
  );
};
