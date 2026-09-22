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
