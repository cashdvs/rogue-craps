# DICE OF THE DAMNED — PoC in Top-Down 3D (v0.1)
For: Godot Dev. **Godot 4.4+**, Forward+ (PC). Mobile-renderer fallbacks are noted inline as **[Mobile]**.
Builds on `poc_feel.md` (timings, VFX beats, colors, SFX, readability) and `style_guide.md` (palette). **Where this doc doesn't say otherwise, `poc_feel.md` still rules.** The 2D sounds and timings carry over unchanged.
**Scope (unchanged):** 2 plain bone dice, Pass Line only, point puck, chips/Coin with **tap-to-stack bets of 5–25 Coin**, Soul meter (2D UI), and the moments Natural, Craps, Point set, Point hit and Seven-out. **A Pass Line loss costs Soul AND the chips.**
Reference image: `poc_3d_reference` (see README_ASSETS.md). Mood only; the numbers here win.

Units: 1 Godot unit = 1 m. The felt surface is at **y = 0**. +Z points toward the player, -Z toward the dealer.

---
## 1. Camera
**Recommendation: perspective, pitch −55°, FOV 36° (vertical), placed far back.** The narrow FOV flattens the perspective into a "diorama" read: the table edges stay nearly parallel, and the dice stay the same size anywhere on the felt, which keeps them readable. It still gives real depth, rail parallax and lamp-cone volume, which an orthographic camera loses. (Orthographic is the fallback if dice readability at the far end ever fails. Use `size` 1.9 with the same pitch.)

| Setting | Value |
|---|---|
| Camera3D projection | Perspective, `fov` 36, `keep_aspect` KEEP_HEIGHT |
| Pivot (look-at target) | (0, 0, 0.05), the felt center slightly toward the player |
| Pitch / yaw | −55° / 0° |
| Distance from pivot | **2.5 m** (the vertical view at the pivot ≈ 1.62 m → ≈ 2.9 m wide at 16:9, so the 2.4 m table fills ~83% of the width; ≈ 667 px per m at 1080p) |
| near / far | 0.1 / 20 |
| DOF (Forward+ only, optional) | far blur begin 3.0 m, amount 0.05 (a soft dealer/background). Off on [Mobile]. |

- **16:9 framing:** the table fills the middle 85% of the width, and the near rail sits at ~88% of screen height. The dealer's head and eyes sit at ~12–18% from the top, under the lamp. Leave the left 9% of the screen for the 2D Soul meter and the bottom-right corner for the 2D ROLL button (both on a CanvasLayer).
- **Portrait (later):** rotate the *table* 90° in the scene (long axis along screen Y), not the camera. Pitch −60°, FOV 40°, distance ≈ 3.2 m (tune until the table's short side fills ~90% of the width). The dealer sits at the top. Soul goes to the top bar and ROLL to the bottom-center (per `poc_feel.md`).
- **Reveal follow/zoom:** after the dice settle (`poc_feel` reveal 0.00 s), tween the pivot to the midpoint of the two dice (x/z clamped to ±0.35 m from center) and the distance 2.5 → 2.1 m over **0.30 s** (TRANS_CUBIC EASE_OUT). Hold through RESOLVE. Return to home in **0.40 s** during RESET (TRANS_SINE EASE_IN_OUT). Seven-out also adds a 1.5° roll tilt that recovers over 0.6 s.
- **Shake:** apply to `Camera3D.h_offset/v_offset` (meters) plus a small rotation, driven by a trauma value (0–1, shake = trauma², noise 18 Hz, decay 1.6/s). Map from the 2D px values: **1 px (2D) ≈ 0.0015 m offset + 0.03° rotation.** So Natural 5 px → 0.0075 m, and Seven-out 10 px → 0.015 m + 0.3°. Cap the offset at 0.03 m. Never move the pivot for shake.
- **Hit-stop:** same as 2D (`Engine.time_scale` dip, with real-time timers).
- **Reduced motion:** no shake, no follow/zoom (a static camera with a 10% brighter dice highlight instead), no roll tilt, DOF off.

## 2. Floor 1 back-room table
### Dimensions (smaller than a real 12 ft craps table, so it reads as a back-room table and fits the camera)
| Part | Size |
|---|---|
| Overall footprint (outside of rails) | 2.40 m (X) × 1.40 m (Z), corner radius 0.28 m (the far corners can be squared at 0.10 m for a "bean" look) |
| Felt bed (inside the rails) | 2.04 × 1.04 m, at y = 0 |
| Padded rail | 0.18 m wide, top at y = +0.11 m, round cross-section (a capsule-ish profile) |
| Brass trim | a 0.012 m band where the rail meets the felt, plus 4 corner caps 0.16 × 0.16 m |
| Inner backboard (dealer side, dice bounce wall) | 0.06 m tall, wrapped in the same felt |
| Wood apron | from y = −0.02 down to −0.30 m (only the top 0.15 m is visible at this pitch), 0.04 m thick |
| Legs / base | hidden in darkness. A single dark box is enough. |

### Felt zone layout (top view, felt bed center = 0,0; meters)
- **Point boxes 4 5 6 8 9 10:** a row centered at z = −0.30, each box 0.24 × 0.18, gap 0.03, total width 1.59 (x −0.795 → +0.795). Number glyph height 0.11 m.
- **Pass Line:** an arc band near the player.
  - Ellipse centered at (0, −0.05), inner radii (0.86, 0.36), outer radii (0.98, 0.50), angles 200°–340°, clipped to the felt.
  - Label "PASS LINE" (cap height 0.07 m) along the band center.
  - Bet spot at (−0.35, +0.40).
- **Dice landing zone:** x ±0.45, z −0.12 → +0.12 (between the point row and the Pass Line).
- **Puck OFF rest:** (−0.96, −0.30), left of the point row.
- **Dealer payout origin:** (0, −0.48) at the far rail. **Rake entry:** (0.3, −0.55).
- Lines and text are **one decal texture** (2048×1024 albedo with alpha) projected flat, or baked into the felt albedo (simpler). Ink color BONE at 85% with a slight wobble/wear mask.

### Materials (see §8 for the toon shader; listed here are the inputs)
- **Felt:** base FELT #123A36.
  - Detail: a tiling fabric normal (CC0, §10) at a scale of 6×, strength 0.25.
  - Stains: a 1024² hand-made decal atlas of 4–6 stain blobs (FELT_STAIN #0F302C and #0B2724) plus 3 cigarette-burn decals (PIT_BLACK center, #4A2A1A ring). Use `Decal` nodes, 6–10 total.
  - **Fuzz:** a fresnel sheen band in the toon shader (rim color #2E6A62, power 3, strength 0.25). No real fur.
  - Roughness 0.95.
- **Padded rail:** oxblood leather, base #5A1620 (between Oxblood #3B0D14 and Burgundy #6E1A24).
  - Tufting: the mesh has buttoned pinches every 0.20 m (vertex-modeled dimples), plus a 512² brass "button" decal or a tiny brass sphere (MultiMesh) in each dimple.
  - Leather normal (CC0) at a scale of 4×, roughness 0.55. Wear: a lighter #8A3A40 on the top ridge (curvature or vertex-color mask).
- **Brass trim and caps:** base BRASS #B08D3C, highlight BRASS_HI #E2C06A as the toon spec band, metallic 0.8, roughness 0.35. Tarnish: a dark #4A3A18 in the crevices (AO or vertex-color mask). Caps get 2–3 screw heads (cheap geometry).
- **Wood apron:** #3A2416 with highlight #5A3A24, a CC0 wood albedo **desaturated 60%, then tinted**, roughness 0.7. Chips and dents come from a decal or vertex color at the corners.
- **Grime/wear:** recommend **vertex color** (R = dirt, G = edge wear) painted in Blender on the table mesh, read by the toon shader. It's cheap and works on [Mobile]. Add 4–6 decals on top for big stains. Don't use real-time curvature (too costly on mobile).

### Props (each ≤ 1.5k tris)
- **Ashtray:** a cheap tin or glass dish with 2 butts, on the right rail (+1.05, +0.11, −0.35). A thin smoke wisp from one butt (§7).
- **Glass:** a lowball glass with amber liquid (#8A4A12), alpha 0.35 glass with a toon rim, on the right rail near the player.
- **Scattered chips:** 6–10 chips on the rail and apron via MultiMesh (§4), some tilted.
- **Rat (optional, stretch goal):** low-poly, sits on the far-left rail corner, with an idle twitch animation and a flee when a seven-out happens. Skip for the PoC unless it's free.
- **Bulb lamp:** see §7.
### Room set dressing (cheap)
- **Walls:** 3 big quads (back, left, right) at 2.5–3.5 m from the table, with an unshaded gradient material from #1A0A0E at the bottom to PIT_BLACK at 1.6 m height. Add `fog` and they fade to black by themselves. Optional wallpaper texture at 20% opacity.
- **Bar silhouette:** one quad behind the dealer at z = −3.0 with an alpha-cut PNG silhouette (bar counter, 8–10 bottles, a shelf) in #0B0507. Light it with one tiny OmniLight (#E8622A, energy 0.3, range 1.5) so 2–3 bottle edges glint.
- **Smoke:** 1–2 large soft-particle sheets (GPUParticles3D, amount 6, lifetime 8 s, quad 1.5 m, alpha 0.06, slow drift +x 0.03 m/s, soft particles on), plus the lamp-cone haze (§7). Color #3A3032.
- **Floor:** a dark plane (#0E0B0C) with a CC0 concrete or wood plank texture at 30%. It's barely visible.

## 3. Bone dice
### Model
- **Size:** **0.08 m** cube (≈ 5× a real die, a deliberate diorama exaggeration for readability: at 667 px/m it renders ≈ 53 px at 1080p at rest and ≈ 64 px during the reveal zoom; on phones, keep the rendered size ≥ 48 px, and raise it to 0.09 m if needed).
- **Bevel radius:** **0.16 × the edge** (≈ 0.013 m), 3 segments, smooth normals. ≈ 800 tris.
- **Pips: drilled (concave hemispheres)**, diameter 0.18 × the edge, depth 0.06 × the edge, at the same fractional positions as `poc_feel.md` §2 (0.27 / 0.50 / 0.73).
  - Model them in the mesh (≈ +1.2k tris), or **[cheaper/Mobile]** use flat faces with pip albedo plus a normal map baked from the drilled version.
  - Standard layout: opposite faces sum to 7 (1–6, 2–5, 3–4).
  - Name the face normals in a script (`FACE_UP = {Vector3.UP: 1, ...}`) so the up-face can be read back.
### Material
- **Body:** BONE #E8DCC0, toon shader with **wrap lighting** (`wrap = 0.35`, a subsurface-lite feel so the shadow side stays warm: shadow ramp to BONE_SHADE #BFAF8E → #8E7A5C, not grey).
  - Roughness 0.45 with ±0.08 noise variation.
  - **Edge wear:** a baked curvature mask → slightly lighter #F4ECD8 on the edges plus 2–3 tiny grime specks (#6E5A40) in the corners.
- **Pip material:** PIT_BLACK #0E1414 albedo, roughness 0.8. A pip-cavity AO darkens the rim.
- Outline: inverted hull (§8), 0.0042 m.
### Physics: LIVE (PM decision) with an invisible guarantee
Cash wants **live physics**: the player's flick throws real `RigidBody3D` dice that bounce off the rails and backboard. The game's seeded RNG still decides the result. A hybrid makes the live die land on the seeded face without visible snapping, and baked throws are only a hidden safety net.

#### Flick input
- **Grab:** press or touch inside the "hand zone" (the dice rest in a small tray at the near-right rail, (0.85, 0.02, 0.40)), or anywhere in the bottom 35% of the screen. The dice lift 0.04 m and follow the pointer, projected onto a plane at y = 0.06 m, with a 0.05 s smoothing lag and a slight shake ("rattling in the hand", ±0.003 m at 20 Hz, with a soft rattle SFX loop).
- **Release → impulse:** measure the pointer velocity over the **last 80 ms** of the drag (screen px/s). Convert it to a world direction by unprojecting the start and end points onto the felt plane.
  - `dir` = normalize(world_delta) with y = 0. **Clamp the yaw to ±35°** around straight-at-the-backboard (−Z). A backward or sideways flick is rotated into that cone.
  - `speed` = clamp(px_per_s × k, **1.6, 3.4 m/s**), with k ≈ 0.0022 at 1080p (scale k by `1080 / viewport_height` so phones and PCs feel the same).
  - Apply `apply_central_impulse(mass × (dir × speed + Vector3.UP × 0.9))`, an upward kick so the dice arc.
  - **Torque:** `apply_torque_impulse(mass × edge² × (axis × spin))`, where axis = normalize(cross(UP, dir)) + a random vector × 0.35, and spin = remap(speed, 1.6, 3.4 → 18, 34 rad/s) × rand(0.85, 1.15). Each die gets its own random component so they never tumble in sync.
  - **Too-weak flick** (< 400 px/s): auto-boost to the minimum speed. Don't cancel the throw, since a flub feels bad. **Too long a hold** (> 3 s): dice stay in the hand, with no auto-throw.
- **Mobile swipe:** the same code, with velocity in dp (`px / DisplayServer.screen_get_scale()`). The min threshold is 250 dp/s. Swiping anywhere in the bottom 40% counts as a flick, so the player doesn't have to grab tiny dice.
- **ROLL button** (accessibility, and also the default on PC if the player prefers): performs a synthetic flick with a random speed of 2.2–3.0 m/s and a yaw of ±15°.
- Haptics on mobile: a light tick on grab and a medium tick on the first rail hit.

#### Physics setup
| Item | Setting |
|---|---|
| Engine | **Jolt** (`physics/3d/physics_engine = Jolt Physics`, built in from Godot 4.4) for more stable stacking and contacts. GodotPhysics works with the notes below. |
| Tick rate | `physics/common/physics_ticks_per_second = 120`, `max_physics_steps_per_frame = 8`. Turn on physics interpolation (`physics_interpolation`) so 120 Hz bodies render smoothly at any fps. |
| Solver | Jolt defaults are fine (velocity steps 10, position steps 2). GodotPhysics: `physics/3d/solver/solver_iterations = 16`. |
| Gravity | **gravity_scale 2.0 on dice** (≈ 19.6 m/s²). The dice are 5× real size, so normal gravity reads as floaty and slow. 2× gravity gives the snappy real-dice timing at diorama scale. |
| Die body | `RigidBody3D`, mass 0.05 kg, `continuous_cd = true`, `can_sleep = true`, `linear_damp` 0.15, `angular_damp` 0.8 (raised during the "last tumble", see below), `contact_monitor` on with `max_contacts_reported` 4 (for clack SFX and settle detection). |
| Die collision | `BoxShape3D` 0.078 m (slightly smaller than the mesh, so the rounded bevel looks right on contact). Alternative: a 26-point `ConvexPolygonShape3D` from the beveled mesh for more natural edge rolls (slightly costlier, and it can rock longer). Start with the box. |
| Die PhysicsMaterial | friction 0.5, bounce 0.25, `rough` false, `absorbent` false |
| Felt (StaticBody3D, a box at y = −0.01) | friction 0.85, bounce 0.08, `absorbent` true (the felt drinks bounces, giving short hops) |
| Padded rails + backboard | friction 0.35, bounce **0.55** (lively rail bounces are the fun part). The backboard is its own static body so its contact can trigger SFX and the Splitter (later). |
| Invisible containment | a `StaticBody3D` "lid" at y = 0.45 m and invisible walls 0.25 m above the rails (bounce 0.3), so a wild flick can't leave the table. |
| Layers | dice on layer 2, table on 1, chips on 3 (dice collide with 1 and 2, not with chips in the PoC: chips sit on the Pass Line, out of the landing path, and chip collisions are cosmetic later). |

#### Settle detection
- A die is **settled** when `linear_velocity.length() < 0.02 m/s` AND `angular_velocity.length() < 0.25 rad/s` for **0.12 s** in a row, or when Jolt or Godot puts it to sleep.
- **Read the up-face:** the face whose world normal has the greatest dot with UP. If the best dot is **< 0.95**, the die is **cocked** (leaning on a rail or the other die). Then apply a tiny nudge impulse (0.15 m/s, away from the contact) once. If it's still cocked after 0.3 s, use the fallback (below).
- Both dice settled → emit `dice_settled(results)`. **The REVEAL starts on this signal**, not on a fixed timer.

#### Landing on the seeded result — recommendation: **"late label remap" during the blur window**
The die's *shape* is symmetric, so which number sits on which face is only a matter of **labels** (pip decals or texture). We change the labels while the die is spinning too fast to read, never the transform.
1. **Before the throw:** the RNG gives the seeded faces (A, B).
2. **During flight:** each physics tick, *predict* the die's final up-face. Take the face most aligned with UP after advancing the current rotation by `angular_velocity × 0.08 s`. Do this only while the die is in the **blur window**, defined as `angular_velocity > 9 rad/s`. At ~50 px and that spin, pips aren't readable, and the toon shader can add a subtle pip-smear (blend pip opacity toward 60% above 12 rad/s) to hide changes.
3. **Remap:** whenever the predicted up-face changes inside the blur window, apply the cube symmetry (one of the 24 rotations of the pip *layout*, not the mesh) that puts the seeded value on the predicted up-face. The opposite-faces-sum-7 rule always holds. Implementation: the mesh has 6 face material slots or a pip atlas with a per-face index uniform. Remap = rewrite 6 integers. That's zero geometry change and zero snapping.
4. **Last tumble:** when the angular speed first drops below 9 rad/s, the labels are **locked**. Raise `angular_damp` 0.8 → 2.5 so the die finishes within ~1 more flip (this makes the prediction stick far more often).
5. **Mismatch handling** (the final up-face ≠ the seeded face because the die flipped one more time after locking; expect ~5–10% before tuning, < 3% after):
   - If the die is still moving (speed between 2 and 9 rad/s), apply a **guided tip**: a small torque impulse around the edge that rolls it toward the seeded face (one 90° tip). It looks like a natural last flop.
   - If it has already settled, play a **"tip-over" tween**: lift the near edge, rotate 90° over 0.18 s (TRANS_QUAD), a clack SFX, and a felt puff. It reads like the die rocking over. Use it at most once per die. If a 2-step correction is needed, use the fallback.
- **Rejected alternative:** rotating the mesh relative to the body *before* the throw so the seeded face ends on top. That requires predicting the whole live throw in advance (a faster-than-real-time simulation of the exact same flick). Godot 4 doesn't expose a simple way to step a separate 3D physics space ahead of time without custom engine or GDExtension work, and any mismatch would then need a visible fix anyway. Late remapping is simpler and works with any flick.

#### Fallback: baked throws (invisible safety net)
Keep the **bake tool** (an editor script: 256 throws in an isolated scene, recorded at 60 Hz, keeping only throws that settle flat inside the landing zone in 0.95–1.25 s) as a library of short **"recovery" clips** and full throws.
Trigger the fallback when:
- a live die **hasn't settled 2.0 s after release**, or
- a die **leaves the table** (y < −0.15, or outside the felt bounds by > 0.05 m; this should be rare with the containment), or
- a cocked or mismatched die needs more than one correction.

What happens:
- **Out of table:** the die "poofs" (a soot puff), reappears dropping from the dealer's side (0, 0.25, −0.40), and plays a **0.45 s baked short-drop clip** (with label remap) that lands on the seeded face. Optional dealer line or eye-roll.
- **Timeout or cocked:** freeze the body (`freeze = true`, kinematic) and crossfade over 0.1 s into the **baked recovery clip** whose start pose is closest (position + orientation distance) to the current pose. Most recovery clips are "one hop and settle" (0.35–0.5 s). Labels are remapped before the clip, since the die is moving.
- Fallback rate target: **< 2% of throws** after tuning. Log every fallback (reason, flick speed) to a debug overlay during testing.

#### Timing vs. the 1.1 s target
- Live throws vary with the flick strength. With the clamps above (1.6–3.4 m/s, 2× gravity, felt absorbent, raised damping after the lock), expect **0.85–1.5 s** from release to settle, with a **median ≈ 1.1 s**. Tune `speed` max and the last-tumble damping until ≥ 80% of throws settle in 0.9–1.3 s.
- The hard cap is 2.0 s (fallback). The reveal hold in `poc_feel.md` stays 0.25 s after settle, so the overall cycle varies by about ±0.3 s around the 2.5 s target. That's acceptable; it reads as "my throw."
- Fast-roll (tap to skip): only skips REVEAL/RESOLVE. A live throw itself can't be sped up (×2 time would change the physics). Option: during fast-roll, apply 1.5× the clamp speed and damping, for ≈ 0.8 s settles.
- **Reduced motion:** the flick still throws, but with `speed` capped at 2.0 m/s and spin at 12 rad/s, and the camera stays static.

#### Roll feel mapping to 2D
- No scripted wind-up. The "hand rattle" replaces it.
- Clack SFX come from real contacts (`body_entered` with relative speed > 0.3 m/s; volume and pitch scale with impact speed). There's a separate leather "thump" for the rails and a felt "puff" particle (§9) on felt hits above 0.5 m/s.
- The settle wobble is real physics now, so drop the scripted wobble.
- SFX palette unchanged from 2D.
- Dice shadows: a real shadow from the lamp plus a cheap blob-shadow decal under each die (0.10 m, PIT_BLACK at 40%). The blob keeps contact readable on [Mobile] with low shadow resolution.

## 4. Chips / Coin
- **Model:** a cylinder Ø 0.055 m × 0.006 m thick (scaled up like the dice), 24 sides, a 0.0006 m bevel, ≈ 120 tris.
- **Edge notch pattern:** via the UV-mapped side band plus a **shader** (8 notches: `step(fract(angle/TAU*8.0), 0.5)` in a band on the side and on a ring of the face, 0.82–1.0 r). The notch color comes from a uniform. The face center has an inset ring (0.72 r) and an optional "C" coin glyph decal.
- **Denominations (Coin):**
| Value | Base | Notch | Ring |
|---|---|---|---|
| 1 (change only) | BONE #E8DCC0 | #0E1414 | #BFAF8E |
| 5 | Crimson clay #A3242E | BONE | #6E1A24 |
| 25 | Felt green #2E7D5B | BONE | #123A36 |
| 100 | BRASS #B08D3C | #0E1414 | #E2C06A |
- Floor 1 "cheap clay": the toon spec band is off, roughness 0.85, with a 6% albedo noise.
- **Bets: tap-to-stack, 5–25 Coin.**
  - Each tap on the Pass Line (or on the 2D bet button) adds **5 Coin** (one red chip). At 25, collapse the stack to one green 25 chip with a quick "merge" (5 chips scale to 0 into the stack top, 0.12 s, then the green chip pops up at 1.15→1.0).
  - Max 25. Long-press or a "clear" button returns the chips (the reverse tween).
  - The minimum bet to enable ROLL is 5.
- **Stacking:** chip i is at y = i × 0.0062, with a random yaw (±25°) and a tiny ±0.0008 m xz jitter. Max 12 visible, then a `Label3D` "×N" floats above.
- **Instancing:** all chips (bankroll, bet, payout, scattered props) use **one `MultiMeshInstance3D` per denomination** with `use_custom_data` for the notch and ring colors. That's 3–4 draw calls total for every chip. Animated chips are moved out of the MultiMesh into 1–8 pooled `MeshInstance3D`s during their tween, then returned.
- **Bet motion:** a chip flies from the bankroll (off the near rail at (−0.9, 0.11, 0.62)) to the bet spot in 0.22 s on an arc 0.10 m high, with spin around Y 180–360°. It lands with a 0.04 s squash (y-scale 0.8) and a clack. Stagger 0.05 s. SFX pitch +3% per chip, as in 2D.
- **Payout:** chips spawn at the dealer payout origin (0, 0.02, −0.48), slide across the felt to beside the bet (0.30 s, TRANS_CUBIC EASE_OUT, a small hop at the end). Then the whole combined stack slides to the bankroll in 0.35 s (TRANS_BACK EASE_IN_OUT). The 2D bankroll counter counts up.
- **Loss sweep:** the dealer's **rake** (§6) enters from (0.3, 0.02, −0.55), drags the chips to (0, 0, −0.50) in 0.35 s (TRANS_QUAD EASE_IN), and they drop off the far edge (scale 0.8, fade). At the same time, **Soul drains** (see §9 Seven-out and Craps).

## 5. Point puck
- **Model:** a cylinder Ø 0.10 m × 0.014 m, 32 sides, edge bevel 0.002 m. Two face materials (top and bottom) plus a side band. ≈ 260 tris.
- **OFF face:** PIT_BLACK with a BONE ring (30%) and "OFF" text. **ON face:** BONE with a PIT_BLACK ring and "ON" text, plus the point number.
- **Text:** bake "OFF" and "ON" into the face textures (a 512² atlas, Alfa Slab One). The **point number** is a `Label3D` (Barlow Condensed Bold, `pixel_size` 0.0006, PIT_BLACK, `no_depth_test` off, `double_sided` off) parented to the ON face, offset 0.0005 m above it. It's one label whose number changes.
- **Flip and move:** on Point set, the puck lifts 0.06 m and moves to the box center over 0.35 s (TRANS_BACK EASE_OUT, overshoot 1.2). During the move it rotates 180° around X (the flip), with the midpoint at 0.17 s. It lands with a wood "tok" and a 0.03 s squash.
  - Returning to OFF is the reverse in 0.30 s (TRANS_QUAD).
  - On arrival the point box decal brightens: emission on the box outline to BRASS_HI, strength 0.6.
- **Glow while ON:** an OmniLight3D under the puck (BRASS_HI #E2C06A, energy 0.35, range 0.18, pulsing 0.25→0.45 at a 1.4 s sine) **plus** a toon-shader emission rim on the puck side (BRASS_HI, 0.3). The light gives the felt a warm halo. **[Mobile]:** drop the OmniLight and use an additive decal glow on the felt (a radial gradient, 0.2 m).

## 6. Dealer (PoC = cheap silhouette)
**Recommendation: a low-poly toon "bust" figure (≈ 2–3k tris) standing behind the far rail, mostly in shadow.** That's more alive than a flat card and stays cheap. It's a custom model; until it's ready, use a flat card fallback.
- **Silhouette spec (both versions):**
  - Head and shoulders plus arms only, from waist up, seen from the camera angle.
  - Head 0.28 m wide, with a **dealer visor** (a forward-jutting brim 0.12 m, the key shape cue).
  - Slumped broad shoulders 0.75 m wide, a thin neck, a hint of a vest V.
  - Top of head at y ≈ +0.75 m, centered at x = 0, z = −0.95 (behind the far rail).
  - Color: PIT_BLACK #0E1414 body, with an **oxblood rim light** from behind (#6E1A24) so the edge reads against the black walls. **No face detail beyond the eyes.**
- **Eyes:** two small emissive ovals (Ember #FF7A1F, core #FFD27A, emission 3.0, glow on), 0.035 m apart.
  - Idle: a slow blink every 4–7 s and a slight glance toward the dice when they land.
  - **Moment reactions:** Natural or Point hit → the eyes narrow (scale Y 0.5). Craps or Seven-out → the eyes flare (emission 5.0 for 0.3 s) and a grin slit appears (an emissive arc, a 0.15 s scale-in).
- **Hands/rake:** **just the rake for the PoC.**
  - The rake is a long stick (1.0 m) with a T-head 0.18 m, brass ferrule, PIT_BLACK wood. It's held by a simple low-poly hand (or none, with the stick vanishing into the dark).
  - Animated with a `Path3D` + `PathFollow3D` or tween keyframes: sweep (loss), push (payout: the rake pushes the payout chips toward the player instead of chips sliding on their own), idle (resting on the far rail, a slight bob).
  - Later: full hands with 2-bone IK.
- **Flat card fallback (day 1):** a quad 0.9 × 0.9 m with an alpha-cut PNG of the same silhouette, unshaded PIT_BLACK, a rim from a back light (or a baked oxblood edge in the texture), and the eyes as 2 separate emissive quads. The rake is a separate mesh.
- **Boss models later** (Madame Shuffle, Baron Vig, The Proprietor): custom models, L effort each, out of PoC scope.

## 7. Lighting
| Light | Settings |
|---|---|
| **Hanging lamp (key)** | `SpotLight3D` at (0, 1.35, −0.05) pointing down, color **#FFB070** (ember-tinted warm), energy 6–8, range 3.0, `spot_angle` 38°, `spot_angle_attenuation` 1.6 (soft edge), shadows on, `shadow_blur` 1.5, PCSS-like soft shadows: `light_size` 0.08 (Forward+). Shadow bias 0.02, normal bias 1.0. |
| Lamp mesh | an enamel cone shade (#2A2A26 outside, emissive #FFE2B0 inside) + a bulb sphere (emission 8.0, so it blooms), hung from a 1.0 m cord. |
| **Sway** | the lamp pivot (cord top) rotates ±1.2° (X) and ±0.8° (Z) on 2 sines at 0.21 Hz and 0.17 Hz. The light moves with it, so the shadows swim slightly. On Seven-out, add an extra 3° swing impulse that decays over 2 s. Off in reduced motion. |
| **Flicker** | energy × (1 + 0.04 sin(7.3t) + 0.03 sin(13.1t)), plus a random dip to ×0.6 for 60 ms every 6–10 s (same as 2D). The bulb emission is synced to it. |
| **Ambient** | `Environment` ambient: Color source, **#1A080C** (oxblood-tinted near-black), energy 0.25. Sky contribution 0. No HDRI lighting needed (a tiny dark HDRI for reflections only is optional). |
| **Rim/back light** | `DirectionalLight3D` from behind and above the dealer (pitch −20°, yaw 180°), color #6E1A24 (Burgundy), energy 0.6, **no shadows**. It outlines the dealer, the rail tops and the dice edges. |
| Fill (optional) | a weak OmniLight #E8622A at (1.6, 0.4, 0.8), energy 0.15, range 3, so the near rail isn't pure black. |

- **Volumetric fog (Forward+):** `volumetric_fog_enabled` true, density 0.012, albedo #3A3032, emission 0, `anisotropy` 0.6 (forward scatter makes the cone visible), length 12, detail spread 2. Set the lamp's `light_volumetric_fog_energy` to 2.5. Add one `FogVolume` box (1.4 × 1.2 × 1.4 m) around the lamp with density 0.04 and a noise texture, so smoke swirls in the cone.
- **[Mobile] fake cone:** volumetric fog isn't available on the Mobile renderer. Use a cone mesh (open bottom, 1.0 m tall, radius 0.55 at the base), additive unshaded, color #FFB070, with alpha from a vertical gradient (0.10 at the top → 0 at the bottom) × fresnel (more transparent at the silhouette center) × a scrolling noise (0.02 UV/s). Plus 4–6 smoke particles inside it (§2 smoke, smaller).
- **Distance fog** (both renderers): `fog_enabled`, light color #0E0B0C, density 0.12 (Exponential), height fog off. This fades the walls to black.
- **AO:** Forward+ uses **SSAO** with radius 0.25, intensity 1.6, power 1.5, detail 0.5, horizon 0.06. **[Mobile]:** SSAO isn't available. Use **baked AO** in the table and dice textures (Blender bake, a 2nd UV or vertex color) plus the blob shadows.
- **Glow/bloom:** `glow_enabled`, intensity 0.8, strength 1.0, bloom 0.05, blend mode Softlight (or Additive for more punch), HDR threshold 1.0, HDR scale 2.0. Levels 2, 3, 4 on (1 and 5 off). It works on [Mobile] (cheaper with fewer levels).
- **Tonemapping:** **AgX** (Godot 4.4+), exposure 1.1, white 6.0. AgX keeps the saturated ember and cyan from going to clean white. Fallback: Filmic, exposure 1.0, white 6.0.
- **Adjustments:** contrast 1.08, saturation 1.05. An optional color-correction LUT that pushes the shadows toward oxblood (#2A0A10) and the highlights toward warm bone.

## 8. Toon-noir shading
### Custom toon shader (`toon_noir.gdshader`, one shader for every opaque prop; params per material)
- **Stepped diffuse:** in `light()`: `NdotL = dot(NORMAL, LIGHT)`, with wrap (`(NdotL + wrap)/(1+wrap)`), × ATTENUATION.
  - **3 bands:** thresholds 0.15 / 0.55 (with `smoothstep` width 0.04 for an anti-aliased edge).
  - Band colors come from a **per-material 3-color ramp**: lit = albedo, mid = albedo × `mid_tint`, shadow = mix(albedo, `shadow_color`, 0.7). The shadow color defaults to **#2A0A10** (oxblood-black), so shadows go warm-red-black, not grey. Cool surfaces (felt) use **#05100F** (pit-teal-black).
  - Add `DIFFUSE_LIGHT += band_color * LIGHT_COLOR / PI` (energy-normalized by your light setup; tune so the lamp-lit band ≈ the albedo).
- **Spec highlight band:** a Blinn-Phong half-vector with a hard step at `spec_size` (0.92 for brass, 0.97 for bone, off for felt and leather), color `spec_color` (BRASS_HI for brass, #FFF6E0 for bone), strength 0.6.
- **Rim:** a fresnel rim `pow(1-dot(N,V), rim_power)` stepped at 0.5, added only on the lit side, in `rim_color`. Felt uses this for "fuzz."
- **Vertex-color inputs:** R = dirt (multiplies the albedo toward #2A1A12 × 0.6), G = edge wear (lerp toward a `wear_color`).
- **Emission** passthrough for eyes, bulb and puck glow.
- **[Mobile]:** the same shader works (it's per-light work in `light()`). Keep it to **≤ 2 lights affecting any mesh**: the lamp plus the rim.
### Ink outlines — recommendation: **inverted hull per mesh** (primary), **no screen-space edge-detect in the PoC**
- **Why:** the hull is predictable, colorable per object, cheap on mobile (one extra draw of simple geometry), and it gives the chunky hand-inked silhouette from the key art. A screen-space depth/normal edge pass gives nicer inner creases but costs a full-screen pass with depth and normal reads (expensive on mobile, and in Godot it needs a separate normal-roughness buffer read, which is Forward+ only). Consider it later as a PC-only quality option.
- **Implementation:** a `next_pass` material: `render_mode unshaded, cull_front;` with the vertex extruded along the normal by `outline_width`. Use smoothed normals stored in the vertex color or UV2 for hard-edged meshes, to avoid gaps on the cube dice.
  - Color PIT_BLACK #0E1414, or a darkened albedo for soft props (smoke has no outline).
- **Thickness target at 1080p: ≈ 2.5–3 px on hero objects** (dice, puck, chips, rail edges) and ≈ 2 px on props. With the camera at 2.5 m and FOV 36°, **1 px ≈ 0.0015 m** at the felt, so:
  - dice / puck: 0.0042 m;
  - chips: 0.0030 m;
  - rail and table: 0.0050 m;
  - dealer silhouette: 0.0065 m (it reads as a cut-out).
  - Optionally scale the width by view distance in the vertex shader, so it stays constant in px when the camera zooms on reveal.
- **Mobile cost:** about 2× the vertex work on outlined meshes (fine: the total scene is ≤ 60k tris) and +1 draw call per outlined material. Drop the outlines on scattered prop chips (MultiMesh) and on the room walls.
### Texture style
- **Flat color + decals, not hand-painted.** Materials are flat albedo colors from the palette plus 1 tiling CC0 detail normal at low strength. Character comes from the **toon ramps, ink outlines, vertex-color grime and decals** (stains, burns, felt print, worn leather). That's fast to iterate and consistent with the 2D concept, with no texture-painting pipeline needed.
- Albedo textures exist only where needed: the felt print decal, puck faces, chip faces (optional), the bar silhouette.
### Palette → material mapping
| Material | Albedo | Shadow color | Spec / rim | Notes |
|---|---|---|---|---|
| Felt | FELT #123A36 | #05100F | rim #2E6A62 (fuzz) | stain/burn decals, print decal BONE 85% |
| Rail leather | #5A1620 | #2A0A10 | spec off, rim #8A3A40 0.15 | tufting dimples, wear on G |
| Brass trim/caps | BRASS #B08D3C | #3A2A10 | spec BRASS_HI, size 0.92 | tarnish on R |
| Wood apron | #3A2416 | #140A06 | — | CC0 wood, desaturated |
| Dice body | BONE #E8DCC0 | #8E7A5C (warm) | spec #FFF6E0, size 0.97 | wrap 0.35 |
| Dice pips | PIT_BLACK #0E1414 | — | — | cavity AO |
| Puck ON / OFF | BONE / PIT_BLACK | warm / #000 | rim BRASS_HI when ON | Label3D number |
| Chips | per denomination | albedo × 0.35 | spec off (Floor 1) | MultiMesh custom data |
| Dealer | PIT_BLACK | #000 | rim #6E1A24 | eyes emissive #FF7A1F |
| Lamp bulb | emissive #FFE2B0 | — | — | emission 8, blooms |
| Walls | gradient #1A0A0E → black | — | — | unshaded |
| Soul (UI only) | SOUL #4FE6E0 | — | — | never on a 3D loss effect |
| Danger (loss VFX) | DANGER #FF2E3E | — | — | embers, cracks, vignette |

## 9. VFX in 3D (per moment; timings, banners, SFX and escalation as in `poc_feel.md` §6–7)
Shared pieces:
- **Felt puff:** on each die landing, GPUParticles3D, amount 6, lifetime 0.35 s, a tiny dust quad #2E5A54 at alpha 0.4, a radial spread of 0.05 m.
- **Light pulse helper:** a temporary OmniLight3D at the dice midpoint, y = 0.15, range 0.9, energy tweened 0→peak→0.
- **Screen-space items** (the vignette, banners, sum label, Soul meter) stay **2D on a CanvasLayer**, as in `poc_feel.md`. The sum label anchors to the dice midpoint via `Camera3D.unproject_position`.
- **3D→2D handoff for Soul:** spawn 3D particles at the dice and project their end point to the Soul meter. Simpler and better: at the moment of travel, **convert to 2D**. Unproject the dice position, then fly 2D particles to the meter (`poc_feel.md` §5). This avoids 3D particles flying into UI space.

| Moment | 3D particles | Light | Decals / mesh FX | Soul / chips |
|---|---|---|---|---|
| **Natural** | brass sparks: GPUParticles3D, amount 40, lifetime 0.6 s, velocity 1.2–2.5 m/s upward cone 50°, gravity −6, a stretched quad #E2C06A → #B08D3C, emission 2 | pulse BRASS_HI #E2C06A, energy 0→4→0 over 0.5 s; the lamp brightens ×1.15 for 0.3 s | a starburst ring: a flat additive decal (12-ray star, BRASS_HI, 0.6 m) rotating 30°/s, scaling 0→1.2, fade 0.4 s | payout (the rake pushes chips); **no Soul change** |
| **Craps** | red embers: amount 24, lifetime 0.8 s, velocity 0.3–0.8 m/s up, turbulence, DANGER #FF2E3E → SMOKE #2A0608; soot puffs: amount 8, lifetime 1.2 s | pulse DANGER, energy 0→2→0 over 0.4 s; the lamp dips ×0.8 for 0.2 s | — | the rake sweeps the chips; **Soul drain** (2D red embers into the meter, crack, red ghost bar); the dealer's eyes flare |
| **Point set** | bone dust motes: amount 12, lifetime 0.5 s, along the puck path | puck OmniLight fades in (§5) | the point box outline emission 0→0.6 | — |
| **Point hit** | brass sparks, amount 56; puck **shockwave**: a flat ring mesh (torus-flat, radius 0→0.6 m, width 0.04→0, 0.35 s, BRASS_HI additive) | pulse BRASS_HI 0→5→0 over 0.6 s; the puck light flashes to 1.2 then off when it returns | — | payout; **no Soul change, no cyan** |
| **Seven-out** | red embers, amount 60 + soot 20 + 8 **felt "chunks"** (tiny dark-teal shards that pop up 0.05 m and fall, lifetime 0.5 s) | pulse DANGER 0→4→0 over 0.5 s; **the lamp dips to ×0.3 for 0.4 s** and gets a sway impulse (§7); the rim light flares to 1.2 for 0.3 s (the dealer looms) | **felt cracks:** 4–6 `Decal`s (crack texture, PIT_BLACK with a DANGER emission edge 1.5) that scale from the dice outward over 0.3 s, then fade over 1.0 s. The puck flashes DANGER (emission). | the rake sweeps the chips **and Soul drains**: 2D red embers eat the meter (heavy version). **No cyan anywhere in the loss.** The dealer grins. |

- **Loss rule (all losses):** a Pass Line loss = chips swept + Soul drained. Soul-loss visuals are **red only** (DANGER embers, crack, red ghost bar). The meter's own cyan fill just shrinks.
- **Win rule:** brass and bone everywhere. **Wins never restore Soul** (PM decision), so no cyan VFX on any table moment.
- **Event restore (outside the table cycle):** Soul comes back only at events. Use cyan soul-wisps (3D wisps rise 0.2 m from the event source, then hand off to the 2D meter restore in `poc_feel.md` §5). This is the only place cyan particles appear.
- **Escalation and reduced motion:** as in `poc_feel.md` §6. In 3D, also scale the Seven-out lamp dip and the crack count with the escalation. Reduced motion uses no cracks and particles ×0.3.
- **[Mobile] particles:** use CPUParticles3D if you're on the Compatibility renderer. Keep counts ≤ 60% and ≤ 200 live total.

## 10. Asset sourcing
**Verified licenses (checked 2026-10-18):**
- **Poly Haven** (polyhaven.com/license): all HDRIs, textures and models are CC0, commercial use allowed, no attribution required. (Only their *live API* asks for credit; downloading files doesn't.)
- **ambientCG** (docs.ambientcg.com/license): all assets are CC0 1.0 Universal, commercial use allowed, attribution optional.
- **Kenney** (kenney.nl/support): all assets on the asset pages are CC0, commercial use allowed, attribution optional, **don't use the Kenney logo**. The **Furniture Kit** (kenney.nl/assets/furniture-kit) is verified CC0 (low-poly tables, chairs, shelves).
- I did not verify a Kenney "casino" kit, so treat chips, dice and the table as custom or procedural.
- Keep a `THIRD_PARTY.md` listing each downloaded file, its source URL and "CC0", even though attribution isn't required.

| Asset | Build method | Suggested source (kind of asset) | License | Effort |
|---|---|---|---|---|
| Table body (rails, felt bed, backboard, apron) | **Custom model** (Blender, ~6–8k tris; vertex-color grime) | — (CSG in Godot for the day-1 blockout) | own | **L** |
| Felt detail normal | CC0 texture | Poly Haven / ambientCG: a fabric or felt / wool cloth material | CC0 | S |
| Rail leather normal | CC0 texture | Poly Haven / ambientCG: leather material | CC0 | S |
| Wood apron | CC0 texture | Poly Haven / ambientCG: dark wood planks or wood veneer | CC0 | S |
| Brass trim and caps | procedural material + custom caps (part of the table model) | optional: ambientCG/Poly Haven metal (brass or scratched metal) for roughness detail | CC0 | S |
| Felt print (Pass Line, point boxes) | **procedural** (generate a 2048×1024 texture from Godot or a script using the OFL fonts) | fonts: Alfa Slab One, Barlow Condensed (OFL, Google Fonts) | OFL 1.1 | S |
| Stain / burn / crack decals | hand-made or procedural (noise → threshold) | optional: ambientCG decals / imperfection-type textures | CC0 / own | S |
| Bone dice | **custom model** (simple: a beveled cube + drilled pips; or procedural in Blender with geometry nodes) | — | own | S–M |
| Chips | **procedural** (CylinderMesh + notch shader) | — | own | S |
| Point puck | procedural CylinderMesh + face atlas + Label3D | — | own | S |
| Dealer silhouette bust + rake | **custom model** (low-poly) / flat card fallback | — | own | M (card: S) |
| Lamp + cord | simple custom or CSG (cone + sphere + cylinder) | optional: Poly Haven models (search for hanging lamps) | CC0 | S |
| Ashtray, glass | simple custom (lathe) or CC0 | Poly Haven models (search "ashtray", "glass"), Kenney kits | CC0 | S |
| Rat (optional) | custom low-poly or CC0 | check Kenney / Quaternius-style CC0 animal packs (license per pack) | CC0 (verify) | M |
| Bar silhouette | hand-made alpha PNG on a quad | — | own | S |
| Back wall / floor | CC0 texture at low opacity | ambientCG / Poly Haven: plaster, wallpaper, concrete, wood floor | CC0 | S |
| Room furniture (stools, shelves) | CC0 low-poly | Kenney Furniture Kit (verified CC0) | CC0 | S |
| Reflection HDRI (optional) | CC0 HDRI, darkened | Poly Haven: an indoor, dim/night interior HDRI | CC0 | S |
| Smoke / spark / ember sprites | procedural (Godot gradient + noise textures) | — | own | S |
| Boss models (later) | **custom models** | — | own | L each |
**Custom modeling needed for the PoC:** the table body (L), the dice (S–M), the dealer bust + rake (M), and small props if not sourced. Later: the 3 boss models (L each).

## 11. Performance budget
| Item | PC (Forward+, 1080p, target 60 fps on a mid GPU) | Mobile (Mobile renderer, target 60 fps mid-range / 30 fps low) |
|---|---|---|
| Total visible tris | ≤ 150k | ≤ 60k |
| Table | 8k (hero) | 5k LOD |
| Dice | 2 × 2k (drilled pips) | 2 × 800 (normal-mapped pips) |
| Chips (all, MultiMesh) | ≤ 120 instances × 120 tris | ≤ 60 instances |
| Dealer | 3k | 2k or the card |
| Props total | 6k | 3k |
| Draw calls | ≤ 120 (outlines included) | ≤ 60 |
| Textures | 2K max for the felt print and table; 1K for props; 512 for decals and puck; compress with VRAM (BPTC/S3TC on PC) | 1K max; ETC2/ASTC; ≤ 64 MB texture memory |
| Lights | 1 shadowed spot + 1 directional (no shadow) + ≤ 3 small omnis (temporary pulses) | 1 shadowed spot + 1 directional; no extra omnis (use emissive decals instead) |
| Shadows | spot shadow atlas 4096, soft (light_size 0.08), 1 shadow-casting light (give it a whole shadow-atlas quadrant: `positional_shadow_atlas_quad_0` subdivision 1) | atlas 1024–2048, hard or PCF 5-tap, blob decals for contact |
| Post | volumetric fog, SSAO (half-res), glow 3 levels, AgX, optional DOF | no volumetrics/SSAO (fake cone + baked AO), glow 2 levels, AgX |
| Particles live | ≤ 400 | ≤ 200 |
| MSAA / AA | MSAA 4× (keeps the outlines crisp) + optional FXAA | MSAA 2× or FXAA |

## 12. Build order for Godot Dev (keep the feel intact at each step)
1. **Port the 2D feel first, in greybox.** A Camera3D at the recommended settings; the table as CSG boxes with flat palette colors; 2 RigidBody3D cube dice. Hook up the **existing game state machine, sounds and 2D UI** (Soul meter, ROLL, banners, bankroll) unchanged. Use plain live physics (the ROLL synthetic flick, reading the natural result) so the full loop (bet → roll → reveal → resolve → reset) plays in 3D on day 1–2. **Check the cycle timings against `poc_feel.md` §7.**
2. **Live dice + guarantee:** the flick input, the physics materials and settings, settle detection, the late label remap with the last-tumble lock, the guided tip, then the bake tool and recovery-clip fallback with the debug overlay (fallback rate, settle-time histogram). Tune to a median settle of ≈ 1.1 s. (This is the biggest feel risk.)
3. **Lighting pass:** the single SpotLight lamp with sway and flicker, ambient, rim, fog (volumetric + fake-cone version), AgX, glow. Get the noir mood on greybox before any detail.
4. **Toon shader + outlines** on the greybox (dice, rail, felt). Verify outline thickness and dice readability at 1080p, and at 48 px on a phone build.
5. **Chips + puck:** procedural chips with MultiMesh, tap-to-stack 5–25 with the merge, the bet / payout / sweep tweens, the puck with flip / move / glow.
6. **Moments VFX:** port each 2D moment, then add the 3D layer (particles, light pulses, crack decals, the rake). Soul drain stays red-only.
7. **Camera reveal follow/zoom + shake + reduced-motion toggle.**
8. **Final table model** (Blender) with vertex-color grime, tufting and brass; the felt print decal; stains and burns. Swap it in for the CSG.
9. **Dealer:** the card first, then the low-poly bust; eyes; rake animations replacing the chip slides.
10. **Set dressing:** walls, bar silhouette, smoke, props (ashtray, glass, scattered chips), optional rat.
11. **Mobile pass:** switch to the Mobile renderer; enable the fallbacks (fake cone, baked AO, blob shadows, no omni pulses); profile against the budget; test portrait later.
12. **Polish:** LUT, tuning of escalation, and readability tests (grayscale screenshot: dice, puck and ROLL brightest).
