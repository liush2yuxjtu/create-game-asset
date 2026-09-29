import React from 'react';
import {AbsoluteFill, Sequence, useCurrentFrame, Composition, registerRoot} from 'remotion';
import {S1Hook, S2Twist, S3Rings, S4Lens, S5Gallery, S6Branch, S7Title} from './Scenes';
import {W, H, FPS} from './lib';
import {GameClip} from './GameClip';

export const CUTS = [0, 60, 120, 195, 345, 480, 555, 630];
const SCENES = [S1Hook, S2Twist, S3Rings, S4Lens, S5Gallery, S6Branch, S7Title];

const Overlay: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill style={{pointerEvents: 'none'}}>
      <svg width={W} height={H} style={{position: 'absolute', mixBlendMode: 'overlay', opacity: 0.35}}>
        <filter id="grain"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed={f % 12} /></filter>
        <rect width={W} height={H} filter="url(#grain)" />
      </svg>
      <AbsoluteFill style={{background: 'repeating-linear-gradient(0deg, rgba(0,0,0,0.18) 0px, rgba(0,0,0,0.18) 2px, transparent 2px, transparent 6px)'}} />
      <AbsoluteFill style={{background: 'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)'}} />
    </AbsoluteFill>
  );
};

export const Main: React.FC = () => (
  <AbsoluteFill style={{background: '#0b0a0f'}}>
    {SCENES.map((S, i) => (
      <Sequence key={i} from={CUTS[i]} durationInFrames={CUTS[i + 1] - CUTS[i]}>
        <S />
      </Sequence>
    ))}
    <Overlay />
  </AbsoluteFill>
);

// v2 cut: motion scenes + real v2「忆」gameplay; claims aligned to the current game (5 章 / 17 层 / 4 结局, 死前只能带一段记忆, 第99世)
export const CUTS_V2 = [0, 60, 120, 225, 330, 450, 525, 570, 645];
const HOPS_V2 = [
  {w: '师兄', x: 0, y: 0},
  {w: '背刺', x: 150, y: -160},
  {w: '长老', x: -170, y: 90},
  {w: '药堂', x: 60, y: 210},
  {w: '妖狐', x: -120, y: -210},
  {w: '炉鼎', x: 190, y: 60},
  {w: '袖口的朱砂', x: 0, y: 30},
];
const SCENES_V2: React.FC[] = [
  () => <S1Hook deaths={99} />,
  () => <S2Twist sub="死前 只能带走一段记忆" />,
  () => <GameClip src={60} caps={[{at: 0, lines: ['第99次', '又死在师兄刀下']}, {at: 36, lines: ['只能带一段', '你会选哪一段？']}]} hl="只能带一段" />,
  () => <S4Lens hops={HOPS_V2} cap1="人人都想要你的命" cap2="但你 记得一件小事" hl1="要你的命" />,
  () => <GameClip src={236} from="left" caps={[{at: 0, lines: ['第100世', '这一幕……似曾相识']}, {at: 34, lines: ['打开「忆」', '用上那一段']}, {at: 94, lines: ['一件小事', '能改多少？']}]} hl="一件小事" />,
  () => <S6Branch rowsN={5} nEnd={4} cap="5 章 · 17 层隐藏冲突" />,
  () => <GameClip src={722} caps={[{at: 0, lines: ['还有 2 层', '没被看见']}]} hl="没被看见" />,
  () => <S7Title tag="GBA 像素 · 修仙 · 忆" q="你会带哪段记忆" cta="进下一世？评论区告诉我" />,
];
export const MainV2: React.FC = () => (
  <AbsoluteFill style={{background: '#0b0a0f'}}>
    {SCENES_V2.map((S, i) => (
      <Sequence key={i} from={CUTS_V2[i]} durationInFrames={CUTS_V2[i + 1] - CUTS_V2[i]}>
        <S />
      </Sequence>
    ))}
    <Overlay />
  </AbsoluteFill>
);

const Root: React.FC = () => (
  <>
    <Composition id="MomenRencai" component={Main} durationInFrames={630} fps={FPS} width={W} height={H} />
    <Composition id="MomenRencaiV2" component={MainV2} durationInFrames={645} fps={FPS} width={W} height={H} />
  </>
);
registerRoot(Root);
