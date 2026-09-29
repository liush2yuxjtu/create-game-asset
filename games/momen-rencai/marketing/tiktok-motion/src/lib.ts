export const FPS = 30;
export const W = 1080;
export const H = 1920;
export const BEAT = 15; // 120 BPM

export const C = {
  bg: '#0b0a0f',
  ink: '#f3efe6',
  red: '#e02a3c',
  redDeep: '#7a0f1c',
  jade: '#30ffc7',
  gold: '#f2c14e',
  dim: '#4a4652',
  robe: '#2a1838',
};

export const clamp = (x: number, a = 0, b = 1) => Math.min(b, Math.max(a, x));
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
export const prog = (f: number, start: number, dur: number) => clamp((f - start) / dur);
export const smooth = (t: number) => {
  t = clamp(t);
  return t * t * t * (t * (t * 6 - 15) + 10);
};
export const outExpo = (t: number) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * clamp(t)));
export const outBack = (t: number, s = 1.9) => {
  t = clamp(t) - 1;
  return t * t * ((s + 1) * t + s) + 1;
};
export const rand = (i: number) => {
  const x = Math.sin(i * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
};

/** Piecewise-linear keyframes convolved with a gaussian → continuous position AND velocity (six-card-gallery v2 idea). */
export const smoothPath = (t: number, keys: [number, number][], sigma = 0.35) => {
  const lin = (x: number) => {
    if (x <= keys[0][0]) return keys[0][1];
    for (let i = 1; i < keys.length; i++) {
      if (x <= keys[i][0]) {
        const [t0, v0] = keys[i - 1];
        const [t1, v1] = keys[i];
        return v0 + ((v1 - v0) * (x - t0)) / (t1 - t0);
      }
    }
    return keys[keys.length - 1][1];
  };
  let s = 0;
  let w = 0;
  for (let k = -20; k <= 20; k++) {
    const dx = (k / 20) * 3 * sigma;
    const g = Math.exp(-(dx * dx) / (2 * sigma * sigma));
    s += lin(t + dx) * g;
    w += g;
  }
  return s / w;
};

/** Screen shake that decays after each impact frame. */
export const shake = (f: number, impacts: number[], amp = 26) => {
  let x = 0;
  let y = 0;
  for (const i of impacts) {
    const d = f - i;
    if (d >= 0 && d < 10) {
      const a = amp * Math.pow(1 - d / 10, 2);
      x += Math.sin(d * 9.1 + i) * a;
      y += Math.cos(d * 7.3 + i) * a;
    }
  }
  return {x, y};
};
