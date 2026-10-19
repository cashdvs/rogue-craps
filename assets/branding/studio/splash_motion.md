# Tiny Anvil Games: Studio Splash Motion Spec (v1.0)

About 2.5 s on Charcoal `#1E1B1A`. **Every number in this doc is mirrored 1:1 in `splash_timings.json`**, so you can load that file as the single timing config. If this doc and the JSON ever disagree, the JSON wins.
Previews: `/workspace/dice/art/concept/studio_logo_final/splash_storyboard.png`. These frames come from the JSON plus the real PNGs (`src/splash_preview.py`).

## Conventions
- Layout space is **1920×1080 (1x)**. PNGs are **2x**, so every Sprite2D has a **base scale of 0.5**. The `scale` values below are **multipliers** on that base (Godot `scale = 0.5 * mul`).
- Each Sprite2D: `centered = false`, `offset = -pivot_px`. The node `position` is then the pivot (all pivots are in README.md and `layers.json`).
- Rotation is in degrees. In Godot (y-down), **positive = clockwise**.
- Easing uses Godot names: `Tween.TRANS_<X>` + `Tween.EASE_<Y>`. "set" means an instant assignment at that time (`tween_callback` / `set_parallel` step at 0 duration).
- All tracks of all layers run in one parallel Tween (or one per layer) started at t = 0. Use `tween_property(...).set_delay(start)`.

## Layer split and key positions (1x)
| Layer | Texture | Pivot (px in PNG) | Rest position (1x) | z |
|---|---|---|---|---|
| background | ColorRect `#1E1B1A` full screen | – | – | 0 |
| anvil | `anvil.png` (500×308) | base_center (316.6, 307.8) | (993.3, 555.0) | 1 |
| hammer | `hammer.png` (524×202), head + handle ONE layer | grip (485.2, 120.4) | (1206.9, 369.0) | 2 |
| sparks / hero | `spark.png` (83×81) | center (41.6, 40.6) | starts (1000.5, 401.4) → home (863.7, 382.2) | 3 |
| sparks / burst | GPUParticles2D, `spark_particle.png` 64×64 white | center | emitter at (1000.5, 401.4) | 3 |
| wordmark / main | `wordmark_main_cream.png` (1201×169) | center (600.4, 84.4) | (960.0, 630.0) | 1 |
| wordmark / games | `wordmark_games_cream.png` (575×88) | center (287.4, 44.2) | (960.0, 716.0) | 1 |

- Anvil x 993.3 centers the anvil's *bounding box* on screen (its base is right of center because of the horn).
- Strike point = the top of the anvil face, 14.4 px right of the base center at 2x (`anvil.png` strike_point pivot (331.0, 0.6)).
- At hammer rotation 0 the striking face sits on the strike point. At rotation 80° the head is straight up above the grip.
- Single-sprite fallback: `wordmark_cream.png` (1201×301, TINY ANVIL + GAMES baked) with pivot main_center (600.4, 84.4) at (960, 630). Using it loses the GAMES delay.

## Beat sheet
| t (s) | Beat |
|---|---|
| 0.00 | Charcoal only (no black flash; the background is already `#1E1B1A`). |
| 0.15–0.40 | The anvil drops in from above the screen, stretched. |
| 0.40 | Land: squash, camera nudge, (optional) thud. |
| 0.30–0.52 | The hammer slides in raised, then winds up. |
| 0.52–0.60 | Swing. **0.60 = impact**: clang, flash, shake, spark burst. |
| 0.60–0.64 | Hammer hit-stop (it holds at 0°). |
| 0.62–0.95 | The hero spark pops out of the strike and arcs to its logo spot off the horn tip. |
| 0.64–1.00 | The hammer recoils and exits right while fading. |
| 0.90–1.40 | TINY ANVIL wipes in left → right, rising 16 px. |
| 1.15–1.50 | GAMES lands on a delay (fade, rise 10 px, tracks in from 110% width). |
| 1.50–2.20 | Hold. The spark twinkles at 1.55–1.85. |
| 2.20–2.50 | Everything fades to the charcoal background. At 2.50, emit `finished` and change scene. |

## Per-layer tracks (exact)
### anvil
| prop | at/start | dur | from → to | trans / ease |
|---|---|---|---|---|
| position:y | set @0.00 | – | -10.0 | – |
| scale | set @0.15 | – | (0.92, 1.10) fall stretch | – |
| position:y | 0.15 | 0.25 | -10.0 → 555.0 | QUAD / IN |
| scale | set @0.40 | – | (1.14, 0.84) land squash | – |
| scale | 0.40 | 0.10 | (1.14, 0.84) → (0.96, 1.05) | SINE / OUT |
| scale | 0.50 | 0.10 | (0.96, 1.05) → (1, 1) | SINE / IN_OUT |
| scale | set @0.60 | – | (1.06, 0.93) strike squash | – |
| scale | 0.60 | 0.18 | (1.06, 0.93) → (1, 1) | BACK / OUT |
| modulate rgb | 0.60 | 0.10 | 1.35 → 1.0 (hot flash; Color(k,k,k,a)) | EXPO / OUT |
| modulate:a | 2.20 | 0.30 | 1 → 0 | SINE / IN |
The pivot is the base center, so squash stays planted on the floor line.

### hammer (rest rotation 80°, alpha 0)
| prop | start | dur | from → to | trans / ease |
|---|---|---|---|---|
| position:x | 0.30 | 0.15 | 1266.9 → 1206.9 | CUBIC / OUT |
| modulate:a | 0.30 | 0.10 | 0 → 1 | LINEAR |
| rotation | 0.45 | 0.07 | 80 → 95 (wind-up) | SINE / OUT |
| rotation | 0.52 | 0.08 | 95 → 0 (swing; reaches 0 exactly at 0.60) | QUAD / IN |
| (hit-stop) | 0.60 | 0.04 | holds 0 | – |
| rotation | 0.64 | 0.10 | 0 → 16 (recoil) | BACK / OUT |
| rotation | 0.80 | 0.20 | 16 → 40 | QUAD / IN |
| position:x | 0.80 | 0.20 | 1206.9 → 1286.9 | QUAD / IN |
| modulate:a | 0.80 | 0.20 | 1 → 0 | QUAD / IN |

### sparks / hero (`spark.png`, rest scale 0)
| prop | start | dur | from → to | trans / ease |
|---|---|---|---|---|
| scale | 0.62 | 0.08 | 0 → 1.5 | BACK / OUT |
| scale | 0.70 | 0.25 | 1.5 → 1.0 | SINE / OUT |
| position:x | 0.62 | 0.33 | 1000.5 → 863.7 | CUBIC / OUT |
| position:y | 0.62 | 0.16 | 401.4 → 330.0 (arc up) | QUAD / OUT |
| position:y | 0.78 | 0.17 | 330.0 → 382.2 (settle) | SINE / IN_OUT |
| rotation | 0.62 | 0.33 | 0 → 180 (lands square, since a 4-point star is symmetric) | CUBIC / OUT |
| scale | 1.55 | 0.15 | 1.0 → 1.2 (twinkle) | SINE / IN_OUT |
| scale | 1.70 | 0.15 | 1.2 → 1.0 | SINE / IN_OUT |
| modulate:a | 2.20 | 0.30 | 1 → 0 | SINE / IN |

### sparks / burst (GPUParticles2D + ParticleProcessMaterial, fires at 0.60)
- `one_shot = true`, `emitting = true` at **0.60**, `amount = 32`, `explosiveness = 1.0`, `lifetime = 0.55`, `randomness = 0.4`, `local_coords = false`.
- `direction = (0, -1)`, `spread = 70°`, `initial_velocity 380–720 px/s`, `gravity = (0, 1400)`, `damping 60–120`, `angle 0–90°`.
- `scale_min/max = 0.25 / 0.60` (16–38 px at 1x), `scale_curve` 1 → 0 (ease-in).
- `color_ramp`: 0.0 Forge Orange `#F26A1B` α1 → 0.6 Cream `#F4EDE4` α0.9 → 1.0 Cream α0 (orange to cream, then out). Use `CanvasItemMaterial` blend **Add** for a hot read on charcoal.
- Optional secondary embers (same emitter, a 2nd GPUParticles2D): amount 10, lifetime 0.9, velocity 120–260, spread 110°, gravity (0, 500), scale 0.08–0.16, solid Forge Orange.

### wordmark / main (`wordmark_main_cream.png`, rest alpha 0, reveal 0)
| prop | start | dur | from → to | trans / ease |
|---|---|---|---|---|
| shader `reveal` | 0.90 | 0.50 | 0 → 1 (left→right wipe) | CUBIC / OUT |
| position:y | 0.90 | 0.40 | 646.0 → 630.0 | QUAD / OUT |
| modulate:a | 0.90 | 0.20 | 0 → 1 | LINEAR |
| scale | 0.90 | 0.50 | 0.96 → 1.0 | BACK / OUT |
| modulate:a | 2.20 | 0.30 | 1 → 0 | SINE / IN |

### wordmark / games (`wordmark_games_cream.png`, rest alpha 0): the delayed beat
| prop | start | dur | from → to | trans / ease |
|---|---|---|---|---|
| modulate:a | 1.15 | 0.20 | 0 → 1 | LINEAR |
| position:y | 1.15 | 0.30 | 726.0 → 716.0 | QUAD / OUT |
| scale | 1.15 | 0.35 | (1.10, 1.0) → (1, 1) (reads as letters tracking in) | CUBIC / OUT |
| modulate:a | 2.20 | 0.30 | 1 → 0 | SINE / IN |

Wipe shader (on wordmark/main; the texture must not be atlased, so UV is 0–1):
```glsl
shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float edge = 0.06;               // soft edge, fraction of width
void fragment() {
    vec4 c = texture(TEXTURE, UV) * COLOR;
    float m = clamp((reveal * (1.0 + edge) - UV.x) / edge, 0.0, 1.0);
    COLOR = vec4(c.rgb, c.a * m);
}
```
Tween it with `tween_property(mat, "shader_parameter/reveal", 1.0, 0.5)`.

### camera (Camera2D offset, or a root Node2D offset if there's no camera)
- **Land nudge @0.40:** offset.y +5 → 0 over 0.10 s, SINE / OUT.
- **Strike shake @0.60:** amplitude 7 px, decaying linearly to 0 over 0.18 s, ~40 Hz (noise or random per frame), both axes, with y weighted 1.0 and x 0.6.

## SFX cues (Sound Designer can supply)
| id | t (s) | notes |
|---|---|---|
| anvil_thud | 0.40 | Optional low soft thump under the land. |
| hammer_swish | 0.52 | Short air swish, ~0.08 s, peaking near 0.58. |
| **clang** | **0.60** | Transient exactly on the impact frame. A bright metallic ring with a tail ≤ 0.9 s. |
| **sizzle** | 0.61 | Spark crackle/sizzle, ~0.7 s, fading out by 1.35. |
| **whoosh** | 0.86 | Soft airy whoosh for the reveal. Lead it by ~0.04 s, peaking ~1.05, gone by 1.45. |
| games_tick | 1.15 | Optional, very soft tick as GAMES lands. Drop it if it crowds the whoosh tail. |
| twinkle | 1.55 | Optional tiny "tink" on the spark twinkle, very quiet. |
All sounds should end by 2.5 s. If the scene is skipped, fade the bus out over the 0.2 s skip fade instead of hard-cutting.

## Skip rule
- Ignore input for the first **0.15 s** (this swallows keys held over from launch). After that, any key press, mouse button, screen touch or joypad button skips. Mouse motion and joystick drift don't count.
- On skip: kill the tweens, fade all content (and SFX) to the charcoal background over **0.20 s** (SINE / IN), then emit `finished`. Don't snap to the final frame first.
- Optional: after the first full view, the splash can be skipped instantly on later launches (a setting, not required).

## Reduced motion (respects the game's reduced-motion setting; total 2.3 s)
- No drop, squash, hammer, camera nudge/shake, burst particles or wipe.
- anvil: alpha 0 → 1, 0.00–0.40, SINE / OUT, at the rest position and scale 1.
- spark hero: set to home (863.7, 382.2). Alpha 0 → 1 and scale 0.8 → 1.0, 0.45–0.70, SINE / OUT. No rotation, no twinkle.
- wordmark main: reveal = 1, y = 630. Alpha 0 → 1, 0.60–1.00, SINE / OUT.
- wordmark games: alpha 0 → 1, 0.80–1.15, SINE / OUT.
- Fade out 2.00–2.30, SINE / IN. SFX: clang @0.45 at −6 dB, whoosh @0.58 at −6 dB, no sizzle.
