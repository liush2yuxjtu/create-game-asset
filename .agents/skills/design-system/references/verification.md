# Verification by claim type

Record scope, revision, environment, method, status and evidence. Allowed check statuses are PASS, FAIL, BLOCKED, NOT_RUN. A failed or unavailable check must not disappear from the handoff.

| Claim | Necessary evidence |
| --- | --- |
| source token | exact file/revision/property; an observed inventory value must name a source |
| static screenshot match | actual images at comparable viewport/theme/frame, clearly sourced, reviewed differences |
| interactive screen | actual browser actions and visible result; include console/network failures |
| public deployment | successful deployment + matching source SHA + actual target interaction |
| engine compatibility | scene import/playback in named engine version/renderer |
| device performance | target hardware/build/scenario/measurement; no FPS claim from a preset switch |
| aesthetic acceptance | user/authorized reviewer decision; not a validator's PASS |

Machine helper `scripts/validate.py` checks system.json and optional VFX_SPEC.json. It resolves token aliases, checks IDs/references, rejects missing local evidence, rejects a PASS without evidence, and validates continuous finite VFX timing. It does not fetch remote evidence or evaluate truth, accessibility, image similarity, DTCG/Google spec compliance, browser execution or engine behavior.

A structurally valid draft can return exit 0 with readiness NOT_READY. `--require-ready` additionally fails on incomplete tokens, screens or declared checks. Do not use the default exit code as project completion. Ready is limited to the user-declared scope: a narrow screen audit cannot certify a complete game.

For a web deliverable, inspect actual controls, keyboard/focus and failure states that matter to the task. Check representative small and large viewports, loaded fonts/assets, text overflow and reduced motion where implemented. Record untested cases. Screenshot-only input cannot satisfy a runtime check.

For VFX, inspect matched charge/impact/dissipate frames, final cleanup and backwards seek. Confirm package/source hash equality and portability caveats. Compare inside the target HUD only if that HUD exists.

Use the VERIFY template to write a report and keep historical evidence tied to its revision. Future updates should refresh affected checks, not relabel old evidence as a new run.
