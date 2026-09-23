---
name: verify
description: Verify Qinglan game assets, the runtime ZIP, and the exact local or GitHub Pages preview. Use for /verify, release validation, and handoff acceptance.
---

# /verify — Qinglan asset and preview verification

Report machine checks and real-browser acceptance separately. Start with the current `AGENTS.md`, `docs/handoff.md`, git status, and intended target URL. Do not reuse a historical PASS as evidence for changed code.

## 0. Scope: dynamic skill VFX first

用户当前关注技能动态特效。先读 [动态验证协议](references/dynamic-vfx-checklist.md) 与 [一念逍遥来源及证据边界](references/yinian-vfx-sources.md)。默认在特效工作台验证运动/层次/时序；演练HUD只作为可读性上下文和集成回归，不作为美术质量替代品。不为验证任务扩展UI功能。

Technical PASS、dynamic observation PASS、reference parity、user art approval分别记录。资料检索完成不等于原视频已观看；未完成参考片段验证时reference parity必须为NOT_RUN。

## JavaScript / Canvas skill-animation route

For `public/jianghu-sixteen/*.js`, first read [制作与运行验证手册](references/procedural-2d-vfx.md). It records how the original paper/crane/talisman shapes, deterministic timeline, player and browser-exported GIF were made, plus the exact local drive path and known limitations. Use this route for this Canvas surface; do not apply Qinglan's 3.2s/WebGL checklist to the 4.8s crane animation.

Maintain this project verifier when the actual launch/drive/evidence path changes. Do not copy the global skill into a second project directory. Give the scoped runtime verdict exactly one of PASS / FAIL / BLOCKED / SKIP; docs-only changes with no runtime change are SKIP. Keep machine checks, deployment, reference parity and user art approval as separate evidence fields, not substitutes for the runtime verdict. Prior screenshots establish only their recorded candidate.

## 1. Repeatable machine checks

On a new checkout run `npm ci`, then `npm run verify`.

The runner writes `verification/latest.json` with source SHA, initial working-tree status, step exit codes, and `browser: NOT_RUN`. It exits nonzero on a failed step. It does not silently skip missing Python/Node tools or browser requirements.

Checks:
- `python3 scripts/verify-skill-sync.py`: verify the complete design-system skill copy against its pinned upstream file manifest. Update the lock only after reviewing an intentional upstream sync.
- `npm test`: timeline boundaries 0/1.1/1.8/3.2, cleanup, deterministic backwards sampling, invalid times.
- `npm run package:asset`: rebuild the 16-frame RGBA sprite atlas and deterministic ZIP.
- `python3 scripts/verify-assets.py`: verify original GLB SHA, geometry identity, animation duration, ZIP inventory and internal hashes, equality with current runtime source, normalized asset specification, sprite dimensions and frame coordinates.
- `npm run build`: compile production assets and generate `build-info.json` with source SHA and dirty-tree indicator.
- `git diff --check`: reject whitespace errors.

Inspect status after regeneration. If generated files changed, include them in the implementation commit and rerun on that committed source before release. Optional dependency audit: `npm audit`; document network failures as unavailable, not a clean result.

## 2. Exact-target browser acceptance

For local validation use the production build (`npm run preview`), not just the development server. For a release, use the actual public Pages URL from the deployment. Read the browser tool's local-development instructions if applicable.

1. Confirm the page shows “WebGL 2 · V2 已就绪”; visually inspect the actual canvas. Check one main sword, six flying swords, jade/gold identity, ink-ring, ribbons and particles. This is technical visual verification, not user art approval.
2. Click 蓄势 / 斩击 / 消散. Confirm 0.80 / 1.48 / 2.50 seconds and different rendered states.
3. Play, observe time advance, pause, and verify time remains stopped. Test 0.25× speed; distinguish the UI selection from a measured speed assertion.
4. Seek to 3.20 seconds with the slider. Confirm complete state and visually empty effect scene. Seek backwards to 0.80 and confirm the effect returns. Background/grid may remain.
5. Enable loop, play through a full 3.2-second cycle, observe wrap and continued playback; then pause.
6. Toggle each sword/sigil/ribbon/particle/bloom control. Inspect visual disappearance and restoration; checkbox state alone is insufficient.
7. Select light quality, inspect continued rendering; restore high quality. Do not infer a mobile FPS budget from this check.
8. Change orbit with the supported browser interaction surface when available, and click reset view. If orbit cannot be exercised, record it as untested.
9. Test a 390×844 viewport: compare document scroll width with viewport width, inspect canvas and controls. Restore temporary viewport changes.
10. Read console warnings/errors. Resolve application errors; explicitly state relevant remaining warnings.
11. Fetch the target's ZIP, confirm success and SHA-256 equality with the verified package. Fetch `build-info.json`, confirm source SHA matches the intended deployment and `dirty` is false for the release.

Prefer native browser tools for visible behavior. An unavailable WebGL context, automation interruption, failed network request, or shader error is a real failure/blocker; never replace it with a source-code assertion or hidden fallback and call it PASS.

## 3. Evidence and handoff

Write a dated report under `docs/verification/` or update `docs/validation.md` with:
- Tested source SHA, target URL, environment/viewport and date.
- Each check: PASS / FAIL / NOT_RUN, concise observation, and any screenshot/artifact path.
- Machine report or workflow URL; public deployment version; package SHA-256.
- Remaining Unity/UE, gameplay, device/performance and art-approval limits.

Update `docs/handoff.md` with the latest report and next required action. Machine PASS, Pages deployment success, real-browser PASS, and final engine acceptance are distinct statuses. Only declare the scope actually tested complete.

## YNJH rehearsal extension

The default page is now a rehearsal. First verify prepare → explanation → enter → cast → result at 3.2s → retry/back. Escape cancels the native dialog and restores focus. Health starts at 100 and the visual-only cue at 1.2s changes the simulated health to 64 once; repeated sampling never compounds it. Mode changes cancel rehearsal; hidden-page interruption returns it to ready. Confirm the procedural dummy is visible in rehearsal and absent in the studio, with the HUD outside the canvas safe area. Switch to 特效工作台 to perform the original V2 checklist above. Check `/ynjh/` and its original source links; diagrams there are authored schematics, not screenshots. The new contract integrity step may PASS with reference-game interaction/art readiness NOT_READY.

## External asset controller route

For `/asset-lab/`, read `public/asset-lab/README.md`. Use production preview on an available port, e.g.4193. At the visible page: global visibility off must clear both instances; override A visibility on must restore only A; reload must preserve it; clear A override must inherit current global again. At 1.8s toggle each active layer and compare actual canvas pixels. Select B color override and motion off: A must advance while B stays frozen. Probe invalid JSON: show rejection and preserve prior settings. Apply valid JSON, reload/read back, test reset, seek end/back, loop/nonloop and390×844; restore viewport. Save screenshots plus URL/source SHA in a dated report. Existing crane.js is not connected and must stay byte-identical. Do not call unsupported capabilities or control UI state proof of rendered behavior.

### Thirty-six variant catalog

The current lab uses 36 catalog IDs (`v01`–`v36`), not rain-a/rain-b. Read `public/asset-lab/variants.json` and README. Select each via “预览 A 技能”; sample 20/49/80/100 using visible “精确进度 %” and “查看此进度”. Compare actual canvas crops: active frames nonempty, stages differ, all ends return to host background. Screenshot full-page crop coordinates must be measured for the current viewport; exclude card borders when comparing cleanup. Machine command traces do not prove pixels or artistic quality. Exercise live playback/wrap, A/B swap, filter no-results→clear, category click, per-ID override after switching away/back/reload, and390 narrow layout. A/B normalized progress aligns different durations; actual playback uses seconds and can drift between cycles. Thumbnails intentionally ignore runtime overrides. New localStorage key isolates historical two-rain config.

## Top-down playground route

For `/playground/`, read root `design.md` and `public/playground/sources.json`. Run `npm run verify`, start a production preview on an available port, then run `python3 scripts/verify-playground.py --url http://127.0.0.1:4196/playground/ --out verification/playground-local`. The browser script writes fresh pixel samples and continuous playback evidence; it is not a source-video parity test. Repeat against the actual Pages URL and match build-info.json to the deployment SHA. Keep the five mock fixtures, original-game evidence, previous ynjh (一念逍遥) baseline, and user art approval separate. Legacy crane and Qinglan remain independent renderers, not transparent Canvas plugins.
