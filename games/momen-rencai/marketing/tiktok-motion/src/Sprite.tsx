import React from 'react';

// 16×17 pixel cultivator of the demonic sect — red glowing eyes, dark robe, blood sash.
const MAP = [
  '......HHHH......',
  '.....HHHHHH.....',
  '....HHHHHHHH....',
  '....HSSSSSSH....',
  '....SEeSSEeS....',
  '....SSSSSSSS....',
  '.....SSMMSS.....',
  '...RRRRWWRRRR...',
  '..RRRRWRRWRRRR..',
  '..RRRRRWWRRRRR..',
  '.RR.RRRRRRRR.RR.',
  '.SS.BBBBBBBB.SS.',
  '....RRRRRRRR....',
  '....RRRRRRRR....',
  '...RRRRRRRRRR...',
  '...RRR....RRR...',
  '...KKK....KKK...',
];

const COL: Record<string, string> = {
  H: '#141019',
  S: '#e8c9a8',
  E: '#ff2b44',
  e: '#ffd0d6',
  M: '#b0706a',
  R: '#2e1a3f',
  W: '#f3efe6',
  B: '#e02a3c',
  K: '#0d0b10',
};

export const Sprite: React.FC<{px: number; eyeGlow?: number}> = ({px, eyeGlow = 1}) => {
  const rects: React.ReactNode[] = [];
  MAP.forEach((row, y) =>
    row.split('').forEach((ch, x) => {
      if (ch === '.') return;
      rects.push(<rect key={`${x}-${y}`} x={x * px} y={y * px} width={px + 0.5} height={px + 0.5} fill={COL[ch]} />);
    }),
  );
  return (
    <svg width={16 * px} height={17 * px} style={{overflow: 'visible', imageRendering: 'pixelated'}}>
      {/* rim light so the dark robe reads on a dark bg */}
      <g style={{filter: `drop-shadow(0 0 ${px * 0.6}px rgba(224,42,60,0.55))`}}>{rects}</g>
      <circle cx={5.5 * px} cy={4.5 * px} r={px * 1.4} fill="#ff2b44" opacity={0.35 * eyeGlow} />
      <circle cx={9.5 * px} cy={4.5 * px} r={px * 1.4} fill="#ff2b44" opacity={0.35 * eyeGlow} />
    </svg>
  );
};

export const SPRITE_W = 16;
export const SPRITE_H = 17;
