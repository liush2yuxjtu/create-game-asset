// 小游戏机器验收：npm run verify:games
// 读取 games/verify.json，对每个游戏版本：剧情穷举（python）→ Godot 导入 → 无头验收（--storytest / --autotest）
// → 重新导出 Web .pck 并与 public/ 下已提交的包逐字节比对（源码改了但忘了重新导出会失败）。
// 需要 Godot（环境变量 GODOT 或 PATH 中的 godot），缺失即 FAIL，不静默跳过。
import {createHash} from 'node:crypto';
import {existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {execFileSync, spawnSync} from 'node:child_process';

const manifest = JSON.parse(readFileSync('games/verify.json', 'utf8'));
const godot = process.env.GODOT || 'godot';
const report = {
  startedAt: new Date().toISOString(),
  sourceSha: execFileSync('git', ['rev-parse', 'HEAD'], {encoding: 'utf8'}).trim(),
  godot, godotVersion: null, machine: 'RUNNING', browser: 'NOT_RUN', steps: [],
};
mkdirSync('verification', {recursive: true});
const save = () => writeFileSync('verification/games.json', JSON.stringify(report, null, 2) + '\n');
save();

function step(name, command, args, cwd) {
  console.log(`\n[verify:games] ${name}`);
  const r = spawnSync(command, args, {cwd, encoding: 'utf8', timeout: 15 * 60 * 1000});
  const out = `${r.stdout ?? ''}${r.stderr ?? ''}`;
  process.stdout.write(out.split('\n').filter((l) => /✔|✘|RESULT|ERROR|SCRIPT ERROR|Error|最短/.test(l)).join('\n') + '\n');
  // Godot 脚本/引擎报错时进程仍可能退出 0，额外拦截 ERROR / SCRIPT ERROR 行
  const passed = !r.error && r.status === 0 && !/^(SCRIPT )?ERROR/m.test(out);
  report.steps.push({name, status: passed ? 'PASS' : 'FAIL', exitCode: r.status, error: r.error?.message ?? null});
  save();
  if (!passed) {
    console.log(out.slice(-4000));
    report.machine = 'FAIL'; save(); process.exit(1);
  }
  return out;
}

const version = spawnSync(godot, ['--version'], {encoding: 'utf8'});
if (version.error || version.status !== 0) {
  report.machine = 'FAIL';
  report.steps.push({name: 'godot-available', status: 'FAIL', error: `找不到 Godot（${godot}）。设置 GODOT=/path/to/godot`});
  save();
  console.error(`[verify:games] FAIL: 找不到 Godot ${manifest.godotVersion}（${godot}）`);
  process.exit(1);
}
report.godotVersion = version.stdout.trim();
if (!report.godotVersion.startsWith(manifest.godotVersion)) {
  report.machine = 'FAIL';
  report.steps.push({name: 'godot-version', status: 'FAIL', error: `需要 ${manifest.godotVersion}，实际 ${report.godotVersion}`});
  save();
  console.error(`[verify:games] FAIL: Godot 版本 ${report.godotVersion}，需要 ${manifest.godotVersion}`);
  process.exit(1);
}

for (const g of manifest.games) {
  const cwd = resolve(g.path);
  for (const args of g.python ?? []) step(`${g.path} python ${args.join(' ')}`, 'python3', args, cwd);
  step(`${g.path} import`, godot, ['--headless', '--path', '.', '--import'], cwd);
  for (const args of g.godot ?? []) {
    const out = step(`${g.path} ${args.join(' ')}`, godot, ['--headless', '--path', '.', '--', ...args], cwd);
    if (!/RESULT: \S+ PASS/.test(out)) {
      report.steps.at(-1).status = 'FAIL'; report.machine = 'FAIL'; save();
      console.error(`[verify:games] FAIL: ${args.join(' ')} 没有输出 PASS`);
      process.exit(1);
    }
  }
  if (g.webPack) {
    const out = join(mkdtempSync(join(tmpdir(), 'games-pck-')), 'index.pck');
    step(`${g.path} export-pack ${g.webPack.preset}`, godot, ['--headless', '--path', '.', '--export-pack', g.webPack.preset, out], cwd);
    const sha = (f) => createHash('sha256').update(readFileSync(f)).digest('hex');
    const committed = g.webPack.committed;
    const same = existsSync(out) && existsSync(committed) && sha(out) === sha(committed);
    report.steps.push({name: `${g.path} web-pack-in-sync`, status: same ? 'PASS' : 'FAIL',
      fresh: existsSync(out) ? sha(out) : null, committed: existsSync(committed) ? sha(committed) : null});
    save();
    console.log(`\n[verify:games] ${g.path} web-pack-in-sync: ${same ? 'PASS' : 'FAIL'}`);
    if (!same) {
      report.machine = 'FAIL'; save();
      console.error(`已提交的 ${committed} 与源码重新导出的不一致。运行：\n  cd ${g.path} && godot --headless --path . --export-pack "${g.webPack.preset}" ${resolve(committed)}`);
      process.exit(1);
    }
  }
}
report.machine = 'PASS'; report.finishedAt = new Date().toISOString(); save();
console.log('\nGames machine PASS. Real-browser acceptance: NOT_RUN. Follow .agents/skills/verify/SKILL.md.');
