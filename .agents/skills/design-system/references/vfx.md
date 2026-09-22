# Optional VFX contract

One canonical asset identity feeds states and runtime packages. Record silhouette, palette, material rules, layer names, coordinate axes, authored scale, origin and usage. Keep source art/models intact; identify every derived package's source revision.

State timeline: start/end seconds, easing, visible layers, opacity/dissolve behavior and interruption rules. Make visual event cues explicit; mark whether gameplay binding is absent, proposed or implemented. Test start/end, backwards seek, replay, pause and frame-rate independence when implemented. Do not mutate gameplay during editor scrubbing.

Layers may be swords, ground sigil, ribbons, particles and postprocess bloom, but match the actual effect. Bloom belongs to the renderer/engine configuration and may not travel in GLB. A mesh export, shader, sprite atlas and engine scene have different portability limits.

Quality budget: count, texture dimensions, blend mode, draw calls, screen coverage/overdraw, resolution/pixel ratio and simultaneous effects. A low-quality switch is configuration evidence, not measured performance. Device results need hardware, engine/renderer, build, resolution, scenario, duration and frame-time observations.

Use VFX_SPEC.json for planned assets, with nulls and NOT_RUN where unknown. Its schema is this skill's tracking contract. Verify a supplied example without changing the existing asset's semantics. Templates do not constitute a Godot port or a shader compiler.
