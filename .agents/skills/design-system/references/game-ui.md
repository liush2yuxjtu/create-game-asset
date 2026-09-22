# Optional game UI extension

Use when the user asks for a game design system or a skill embedded in a battle HUD. Reference aesthetics do not determine gameplay rules, monetization or screen count.

Separate three surfaces:
1. existing standalone asset preview;
2. proposed or implemented combat HUD;
3. actual engine/game runtime.

For a HUD specify camera framing, player/target anchors, readable skill range, cooldown/resource/target information, safe areas, input method and localization. Label damage values, enemies and rewards as synthetic when they are test fixtures. Never equate a staged screen with a functioning game loop.

For each requested screen record compact/desktop layouts, loading/empty/error/interrupted states where relevant, controller/touch/keyboard focus, text growth and color-independent feedback. Viewport checks on a desktop browser do not prove actual phone usability or GPU performance.

Useful flow contract: prepare -> target -> charge -> release -> visual impact cue -> gameplay result -> recovery. A visual cue and an engine hit callback are different events; record cancellation, pausing and replay behavior independently.

Compare VFX in the HUD with the standalone version at the same time and camera: can users locate the target and read actions through the effect? Record the exact frames and assessment, not an invented parity percentage. Art approval remains a separate decision.
