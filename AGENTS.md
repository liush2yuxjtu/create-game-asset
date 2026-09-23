# create-game-asset — agent handoff contract

## Scope and source of truth

This repository contains the create-game-asset skill and Qinglan Sword Formation V2.
Read `.agents/skills/create-game-asset/SKILL.md`, `public/assets/qinglan/v2/asset-spec.json`, and `docs/handoff.md` before continuing asset work. Use `.agents/skills/verify/SKILL.md` for `/verify`, any validation request, and before claiming work complete.

Canonical skill paths live in `.agents/skills/`; do not create divergent copies in another agent directory. These rules apply to the whole repository.

## Preserve the asset contract

- Keep `public/assets/qinglan/v1/qinglan-sword-formation.glb` byte-identical. V2 is a runtime overlay; a standalone GLB does not contain the V2 shader effects.
- Preserve one main sword, six flying swords, the specified palette, and the 3.2-second charge/slash/dissipate state sequence unless the user changes the brief.
- Runtime code: `src/qinglan-vfx.js`, `src/shaders.js`, `src/timeline.js`. Preview integration: `src/main.js`, `src/style.css`, `index.html`.
- Generated V2 sprites and ZIP must be regenerated through `npm run package:asset`, not edited by hand. Commit changed generated assets together with their source.
- Keep shader/runtime limitations explicit. No claim of Unity/UE integration, gameplay hit logic, or device performance acceptance without new evidence.

## Verification and release

1. Run `npm ci` on a new checkout, then `npm run verify`. The script runs timeline tests, deterministic packaging, asset integrity checks, production build, and whitespace checks. Any failure blocks a machine PASS.
2. Read `verification/latest.json`. Browser acceptance starts as NOT_RUN; machine PASS alone is not complete acceptance.
3. Follow the exact-target browser checklist in `/verify`. Record URL, source SHA, tested controls, screenshots/observations, console findings, and untested scope in `docs/validation.md` or a dated `docs/verification/` report. Never convert a blocked browser step to PASS.
4. For a Pages release, match live `build-info.json` to the successful deployment workflow's source SHA; verify the actual public page and ZIP. Localhost or an HTTP 200 alone cannot establish public-page acceptance.
5. Do not force-push or discard concurrent work. Inspect status and fetch before pushing. Changes to main deploy publicly through `.github/workflows/pages.yml`.

## Handoff

Update `docs/handoff.md` when behavior, verification procedure, deployment, or remaining blockers change. Include concrete paths, latest tested release/report, acceptance boundaries and next action. Keep historical local checks distinguishable from the current public release. Reply in Chinese unless requested otherwise.

No credentials, browser session material, private conversation dumps, or personal environment paths belong in this public repository. This repository's handoff files are project documentation, not a request to modify personal memory.

## Design-system skill dependency

For system-level source extraction, token/component/screen contracts or game HUD/VFX design-system work, read `.agents/skills/design-system/SKILL.md`. It is a pinned copy from the independent design-system-skill repository; `skills.lock.json` records its source revision and file hashes. It complements create-game-asset and does not replace its asset pipeline or imply that Godot/HUD is complete. Edit upstream and sync deliberately; the verifier rejects unnoticed local drift. No global skill installation is required.

## YNJH baseline and Qinglan application

`design-systems/ynjh/` is the source-based reference contract for **一念逍遥**, confirmed by the user. YNJH is a retained directory identifier, not 一念江湖. Read DESIGN.md, SCREENS.md, FLOWS.md and AUDIT.md before UI changes. Sources are GAMEUI community screenshots; flow edges are inferred, not recorded gameplay. Do not overwrite the generic pinned skill for game-specific rules.

`public/ynjh/` is an original schematic index with source links. Do not redistribute third-party screenshots/art as project assets. `src/rehearsal.js` supplies deterministic simulated UI feedback; the rehearsal's wooden dummy and 100→64 health are not engine hit logic. Preserve studio controls and original V2 runtime package. Validate rehearsal prepare/cancel/enter/cast/result/retry/back and mobile canvas/HUD separation as well as studio controls.

## Dynamic VFX verification priority

The user focuses on skill motion, not additional UI. `/verify` must load its `references/dynamic-vfx-checklist.md` and `references/yinian-vfx-sources.md`. Use actual continuous effects playback and phase/layer evidence; keep source video metadata, watched footage, technical acceptance and art approval separate. One main sword/six flying swords and 3.2s timing are our contract, not measured Yinian values. Documentation-only protocol changes do not establish fresh visual parity.
