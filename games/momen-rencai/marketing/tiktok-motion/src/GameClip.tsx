import React from 'react';
import {AbsoluteFill, OffthreadVideo, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {C, W, clamp, lerp, prog, outBack, outExpo, smoothPath} from './lib';

const SANS = '"Noto Sans CJK SC", sans-serif';

/** Real Godot gameplay (v2「忆」clean plate) inside a phone frame that moves — six-card-gallery style push/tilt. */
export const GameClip: React.FC<{src: number; caps: {at: number; lines: string[]}[]; hl?: string; from?: 'left' | 'right'}> = ({src, caps, hl, from = 'right'}) => {
  const f = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();
  const t = f / 30;
  const inE = outBack(prog(f, -4, 10), 1.6);
  const dir = from === 'right' ? 1 : -1;
  const push = lerp(1, 1.06, clamp(f / durationInFrames));
  const tilt = smoothPath(t, [[0, dir * 6], [0.4, dir * -1.5], [2, dir * 1], [4, 0]], 0.2);
  const FW = 720;
  const FH = Math.round((FW * 16) / 9);
  const cap = [...caps].reverse().find((c) => f >= c.at);
  const capE = cap ? outExpo(prog(f, cap.at, 6)) : 0;
  return (
    <AbsoluteFill style={{background: C.bg}}>
      {/* moving grid backdrop */}
      <AbsoluteFill style={{backgroundImage: `linear-gradient(${C.dim}33 2px, transparent 2px), linear-gradient(90deg, ${C.dim}33 2px, transparent 2px)`, backgroundSize: '80px 80px', backgroundPosition: `${dir * f * 3}px ${f * 2}px`}} />
      <div
        style={{
          position: 'absolute',
          left: (W - FW) / 2,
          top: 380,
          width: FW,
          height: FH,
          borderRadius: 46,
          overflow: 'hidden',
          border: `12px solid ${C.ink}`,
          boxShadow: `0 0 0 5px ${C.red}, 0 40px 90px rgba(0,0,0,0.8), 0 0 90px rgba(224,42,60,0.35)`,
          transform: `translateX(${(1 - inE) * dir * 1100}px) rotate(${tilt}deg) scale(${push})`,
          background: '#000',
        }}
      >
        <OffthreadVideo src={staticFile('gameplay_clean.mp4')} startFrom={src} muted style={{width: '100%', height: '100%', imageRendering: 'pixelated'}} />
      </div>
      {cap && (
        <div style={{position: 'absolute', top: 120, left: 40, right: 40, textAlign: 'center', transform: `translateY(${(1 - capE) * -40}px) scale(${lerp(1.25, 1, capE)})`, opacity: capE}}>
          {cap.lines.map((l, i) => (
            <div key={i} style={{fontFamily: SANS, fontWeight: 900, fontSize: 84, lineHeight: 1.18, color: hl && l.includes(hl) ? C.red : C.ink, textShadow: '0 6px 0 #000, 0 0 30px #000'}}>
              {l}
            </div>
          ))}
        </div>
      )}
    </AbsoluteFill>
  );
};
