# Godot migration planning — not a supplied runtime

Read this only when Godot is part of the user's target. Record exact Godot version, renderer (Compatibility/Mobile/Forward+), 2D vs 3D, platform and intended concurrent effects. Keep unknown fields null; do not claim engine compatibility from a browser or GLB load.

For a 3D starting point, investigate Node3D, AnimationPlayer, GPUParticles3D, ShaderMaterial, Marker3D and signals in the documentation for the chosen version. For 2D use the corresponding 2D types and remap camera/scale intentionally. These are candidate responsibilities, not a pretested node graph.

Planning structure (names are proposals):
```
qinglan_v2/
  scene/
  shaders/
  particles/
  animations/
  textures/
  manifest.json
```

Conversion concerns:
- Three.js GLSL and onBeforeCompile hooks do not transfer automatically to Godot shaders.
- glTF can preserve geometry/ordinary animation while custom shaders, particles and postprocessing require reconstruction.
- Keep a gameplay callback distinct from a visual impact event. Emit at most as specified per cast, and define seeking/replay/cancel behavior explicitly.
- Renderers and platforms differ in bloom, particles and transparency; verify an actual low-quality path and readable HUD.

Acceptance sequence:
1. Import and open the chosen engine scene; record version and import errors.
2. Play full state sequence and inspect intermediate frames; verify layer toggles.
3. Exercise event callback count, pause, cancel, seek and replay with a small gameplay test harness.
4. Export and launch on the target device. Record actual frame times and visual differences against the browser source at matched frames.
5. Record user art review separately.

Official documentation starting points (consult chosen version; links alone are not test results):
- https://docs.godotengine.org/en/stable/classes/class_animationplayer.html
- https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html
- https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/index.html
- https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html

No Godot executable, scene, shader port or measured device result is included in this skill release.
