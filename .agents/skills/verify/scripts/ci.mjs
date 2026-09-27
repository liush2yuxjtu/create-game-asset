// 完整门禁：npm run verify:ci。Pages 工作流只负责装环境然后调用这里，本地与 CI 跑同一套检查（测试左移）。
// 顺序：机器检查 verify.mjs → Godot 游戏 verify-games.mjs → Hypit 视频（games/verify.json 的 videos）→ 真实浏览器 playground → 发布一致性（生成物已提交、build-info 干净）。
// 需要 Godot（GODOT）、ffmpeg/ffprobe 与 Playwright + Chromium（browser-requirements.txt），缺失即 FAIL，不静默跳过。
import {spawn, spawnSync, execFileSync} from 'node:child_process';
import {readFileSync} from 'node:fs';

const here = '.agents/skills/verify/scripts';
const port = process.env.VERIFY_PREVIEW_PORT || '4196';
const run = (name, command, args) => {
  console.log(`\n[verify:ci] ${name}`);
  const r = spawnSync(command, args, {stdio: 'inherit'});
  if (r.error || r.status !== 0) { console.error(`[verify:ci] FAIL: ${name}`); process.exit(1); }
};

run('machine', process.execPath, [`${here}/verify.mjs`]);
run('games', process.execPath, [`${here}/verify-games.mjs`]);
for (const v of JSON.parse(readFileSync('games/verify.json', 'utf8')).videos ?? []) {
  run(`hypit-video ${v.path}`, 'python3', [`${here}/verify-hypit-video.py`, v.path, '--video', v.video, '--out', `verification/hypit-${v.path.split('/').pop()}`]);
}

console.log(`\n[verify:ci] playground preview on :${port}`);
const preview = spawn(process.execPath, ['node_modules/vite/bin/vite.js', 'preview', '--host', '127.0.0.1', '--port', port, '--strictPort'], {stdio: 'ignore'});
process.on('exit', () => preview.kill());
const url = `http://127.0.0.1:${port}/playground/`;
let up = false;
for (let i = 0; i < 30 && !up; i++) {
  up = await fetch(url).then((r) => r.ok, () => false);
  if (!up) await new Promise((r) => setTimeout(r, 1000));
}
if (!up) { console.error(`[verify:ci] FAIL: preview ${url} 未就绪`); process.exit(1); }
run('playground-browser', 'python3', [`${here}/verify-playground.py`, '--url', url, '--out', process.env.VERIFY_PLAYGROUND_OUT || 'verification/playground-ci']);
preview.kill();

run('committed-generated-assets', 'git', ['diff', '--exit-code']);
const info = JSON.parse(readFileSync('dist/build-info.json', 'utf8'));
const sha = process.env.GITHUB_SHA || execFileSync('git', ['rev-parse', 'HEAD'], {encoding: 'utf8'}).trim();
if (info.dirty || info.sourceSha !== sha) {
  console.error(`[verify:ci] FAIL: build-info ${JSON.stringify(info)} 与源码 ${sha} 不一致或工作区不干净（先提交再跑）`);
  process.exit(1);
}
console.log('\n[verify:ci] PASS（机器 + 游戏 + Hypit 视频 + playground 浏览器 + 发布一致性）。其余真实浏览器验收仍按 SKILL.md 手动完成。');
