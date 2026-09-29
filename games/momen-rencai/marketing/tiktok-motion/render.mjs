import {bundle} from '@remotion/bundler';
import {renderMedia, renderStill, selectComposition} from '@remotion/renderer';
const browserExecutable = '/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell';
const serveUrl = await bundle({entryPoint: new URL('./src/Video.tsx', import.meta.url).pathname});
const composition = await selectComposition({serveUrl, id: process.env.COMP || 'MomenRencai', browserExecutable});
if (process.argv.includes('--stills')) {
  const frames = (process.argv[process.argv.indexOf('--stills') + 1] || '5,40,70,100,160,230,330,380,450,520,580,600,627').split(',').map(Number);
  for (const frame of frames) {
    await renderStill({serveUrl, composition, frame, output: `stills/${process.env.COMP || 'v1'}-f${String(frame).padStart(3, '0')}.png`, browserExecutable, scale: 0.5});
  }
} else {
  await renderMedia({serveUrl, composition, codec: 'h264', outputLocation: `out/${process.env.COMP || 'MomenRencai'}-silent.mp4`, browserExecutable, crf: 16, concurrency: 2,
    onProgress: ({progress}) => { if (Math.round(progress * 100) % 20 === 0) process.stdout.write(`${Math.round(progress * 100)}% `); }});
}
console.log('done');
