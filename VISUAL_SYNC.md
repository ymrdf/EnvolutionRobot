# RGB observation synchronization

The training connector sends step/reset observations from `_physics_process`.
A slow Python client causes Godot to batch physics catch-up ticks before drawing
its next frame. This project permits 16 physics ticks per frame. Reading a
ViewportTexture in each physics callback therefore reused one rendered image
across many steps, even though HP and actions were changing.

`Sync._training_process` now redraws all viewports once with
`RenderingServer.force_draw(false)` before reading an observation. Both eyes are
read from that draw. RGB SubViewports use `UPDATE_ALWAYS`, and sensor/camera
physics interpolation is disabled so their pose represents the physics state.
Image readback uses the SubViewport directly rather than its preview Sprite2D.
This requires a rendering-capable Godot instance; a dummy headless renderer
cannot supply RGB observations.

A reset reply now waits for the next action in the same paused callback. The
previous early return resumed physics before receiving the action and added an
uncontrolled tick, doubling the first step's HP loss after reset.

Do not replace the synchronous draw with an await of `frame_post_draw` while
pausing the scene in this physics callback. That suspends the callback with the
PhysicsServer disabled before rigid-body integration finishes. In the live
rotation probe this prevented normal camera movement.

## Reproduce the live regression check

Use the Python environment containing `godot-rl`, NumPy, and the project's
Godot .NET runtime. Set `DOTNET_ROOT` if the SDK was installed outside PATH.
The script launches and closes its own game on port 11018, with the existing
training scene (20 physics ticks/s, action_repeat=1).

```bash
conda activate envolution
python tools/check_visual_sync.py --godot /path/to/godot4 --output /tmp/visual-sync.json
```

The robot turns in place for 96 steps. The client waits 70–150 ms between
requests to reproduce catch-up rendering. After 8 warmup steps, both 320×300 RGB
eyes must change on every step, and HP loss must match one physics tick
(1/180/20 HP), including the steps immediately following repeated live resets.
Stationary images in an arbitrary scene are not inherently a failure; this
check deliberately keeps the camera rotating.

On the development GTX 1660 Ti / Godot 4.6:

| Check | Original connector | Fixed connector |
| --- | --- | --- |
| Changed images, left/right eye | 6/88 each | 88/88 each |
| Maximum HP loss error | 0.000277778 HP | < 8e-14 HP |

The original 100k V2 run had identical before/after images in 18,753 of 24,999
nonterminal decisions. The separate CUDA V2 check (`v2_visual_sync_check`)
completed 1,536 environment steps and 385 learning updates, including one death
and respawn. All 384 nonterminal decisions received changed images (zero
identical pairs); both processes exited normally. These checks measure
observation synchronization, not learned survival ability.
The additional draw per observation has a rendering cost. Previous checkpoints
remain readable, but previously collected trajectories do not gain fresh vision
retroactively; learning comparisons should use the corrected environment for
both baseline and trained policies.

API reference: https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html#class-renderingserver-method-force-draw
