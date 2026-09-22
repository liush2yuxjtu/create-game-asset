---
name: verify
description: Verify Qinglan game assets, the runtime ZIP, and the exact local or GitHub Pages preview. Use for /verify, release validation, and handoff acceptance.
---

# /verify — Qinglan asset and preview verification

Report machine checks and real-browser acceptance separately. Start with the current `AGENTS.md`, `docs/handoff.md`, git status, and intended target URL. Do not reuse a historical PASS as evidence for changed code.

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
