# DICE OF THE DAMNED — Proof-of-Concept Feel Spec (v0.1)
For: Godot Dev. Target: **Godot 4.x, 2D**. Built ONLY from Control/Node2D shapes, `StyleBoxFlat`, `Line2D`/`Polygon2D`, small `canvas_item` shaders, `GPUParticles2D` (or `CPUParticles2D` for mobile/Compatibility), `Tween`s and one or two OFL fonts. **No illustrated assets.**
Scope: roll → reveal → win/loss → table cycle. **2 plain bone dice. Pass Line only.** (Rarities, drawbacks and the altar are parked; see `dice_rarities.md`.)
Visual reference (not a source asset): `poc_table_reference` and `poc_vfx_moments` (see README_ASSETS.md).

## 0. Palette (from style_guide.md) + PoC additions
| Token | Hex | Use |
|---|---|---|
| OXBLOOD | #3B0D14 | screen background |
| BURGUNDY | #6E1A24 | panels, loss banner base |
| EMBER | #E8622A | ROLL button, bulb tint, heat sparks |
| FELT | #123A36 | table felt |
| PIT_BLACK | #0E1414 | outlines, pips, shadows, puck OFF |
| BRASS | #B08D3C | rim bevel, frames, win accents, chips (gold) |
| BONE | #E8DCC0 | dice, labels, puck ON |
| SOUL | #4FE6E0 | Soul meter ONLY (and soul-gain wisps) |
| DANGER | #FF2E3E | loss/drain only (from the drawback rules) |
| Derived | FELT_DARK #0B2724, FELT_STAIN #0F302C, RIM_WOOD #3A2416, RIM_WOOD_HI #5A3A24, BONE_SHADE #BFAF8E, BRASS_HI #E2C06A, SOUL_CORE #DFFFFD, SOUL_DEEP #1E8F8B, DANGER_DARK #8E0F1C, SMOKE #2A0608 |

**Fonts (both SIL OFL 1.1, free for commercial use):**
- **Alfa Slab One**: chunky display slab serif for labels and banners ("PASS LINE", "NATURAL!", "ROLL").
- **Barlow Condensed SemiBold/Bold**: numbers and small UI (Soul value, bankroll, point numbers). It stays legible when small.
- Fallbacks (also OFL): Rye (more western flavor, banners only) and Oswald (numbers).
- Labels: BONE fill with a PIT_BLACK outline (`outline_size` 6 at 1080p) and a 0,4 px shadow at 50%.

## 1. Floor 1 table (back-room)
### Layout — reference 1920×1080 (landscape PC)
Project settings: `display/window/size/viewport_width=1920`, `height=1080`, `stretch/mode=canvas_items`, `stretch/aspect=expand`. Anchor HUD elements to screen edges, and keep the table centered.

| Element | Node | Rect / position (px @1080p) |
|---|---|---|
| Background | ColorRect OXBLOOD | full screen |
| Table rim | Panel + StyleBoxFlat | center (960,540), size 1440×840, corner radius 140 |
| Felt | Panel + StyleBoxFlat + shader | inset 40 px inside the rim → 1360×760, radius 110 |
| Point row (number boxes 4 5 6 8 9 10) | 6× Panel | top of felt, y=170–280, box 150×110, gap 20, x from 460 → 1460 |
| Dice landing zone | Node2D marker | center (960,520), ±220×±120 random land area |
| Pass Line band | Polygon2D arc | bottom of felt: outer arc y≈900, inner arc y≈790, x 380–1540 |
| Chip bet spot | Marker2D | (640, 850) on the Pass Line |
| Soul meter | Control | x 60–160, y 250–830 (left HUD, outside the felt) |
| Bankroll / chip stack (player) | Control | bottom-left, (60–360, 900–1040) |
| ROLL button | TextureButton→Control with drawn circle | center (1790, 930), radius 105 (touch area 240×240) |
| Banner layer | CanvasLayer 10 | centered (960, 470) |

**Mobile-safe scaling:**
- **Landscape phone:** the same layout. `aspect=expand` adds side space. Keep all HUD inside a safe margin of **max(5% of width, device safe-area insets)**, using `DisplayServer.get_display_safe_area()`.
- **Portrait (later):** switch to a 1080×1920 layout. The Soul meter becomes a horizontal bar at the top (y 80–150), the table is 1000×1100 rotated 90° (point row vertical on the right, or kept horizontal across the top of the felt), and the ROLL button becomes full-width, 900×180, at y≈1650. The chip stack sits left of ROLL.
- Minimum sizes at any scale: **dice ≥ 48 px on screen**, touch targets ≥ 44 dp (≈ 120 px at 1080p), labels ≥ 28 px.

### Felt
- StyleBoxFlat `bg_color` FELT, corner radius 110, `shadow_color` #000000AA, `shadow_size` 24 (inner darkening comes from the shader).
- **Stain/noise shader** (canvas_item on the felt panel):
  - Two `NoiseTexture2D` (FastNoiseLite Cellular, frequency 0.004, for big stains; Simplex, frequency 0.03, for fibers).
  - `color = mix(FELT, FELT_STAIN, smoothstep(0.55,0.75,n1)*0.6)`, then `color *= 0.92 + 0.08*n2`.
  - Add 3–5 "burn marks" as uniform vec3s (pos.xy, radius): `color = mix(color, PIT_BLACK, (1.0 - smoothstep(r*0.6, r, d))*0.7)` with a FELT_DARK rim.
  - Edge darkening: `color *= mix(0.7, 1.0, smoothstep(0.0, 0.12, edge_dist))`.
  - Static: no animation, which is cheap.
### Rim
- StyleBoxFlat `bg_color` RIM_WOOD, `border_width` 0, corner radius 140.
- Bevel: a second inner StyleBoxFlat 6 px inset with `border_width_top/left` 4 px RIM_WOOD_HI and `border_width_bottom/right` 4 px PIT_BLACK.
- **Brass inner trim:** a Line2D loop (or a StyleBoxFlat border) 4 px BRASS just inside the rim, with a 1 px BRASS_HI on top.
- "Chipped" look: 6–8 small Polygon2D notches in OXBLOOD along the rim's outer edge. These are random but seeded, so they look the same every run.
### Pass Line zone
- **Shape:** Polygon2D built in code as an arc band (≈ 40 segments) from angle 200° to 340° on an ellipse centered at (960, 420), outer radii (620, 480), inner radii (620, 370), clipped to the felt.
  - Fill FELT_DARK. Border: Line2D 4 px BONE at 70% on both edges.
- **Label:** "PASS LINE", Alfa Slab One 72 px, BONE, outline 6 PIT_BLACK, letter spacing +4. Use a Label (or curved text via per-character placement) centered at (960, 860).
- **Hover/active:** when the player can bet, the border pulses 70%→100% alpha over a 1.0 s sine. With a bet placed, the border turns BRASS.
- Point row boxes: StyleBoxFlat FELT_DARK, border 3 px BONE at 60%, radius 10. Numbers in Barlow Condensed Bold 64 px BONE.
### Vignette + overhead bulb
- **Bulb light:** a full-screen ColorRect on CanvasLayer 1 with an additive shader: `a = (1.0 - smoothstep(0.0, 0.55, distance(UV, vec2(0.5, 0.32))))`, color EMBER mixed 60% with BONE, max alpha 0.22.
  - **Flicker:** `intensity = 1.0 + 0.04*sin(TIME*7.3) + 0.03*sin(TIME*13.1)`. About every 6–10 s (random), do a quick dip to 0.6 for 60 ms, then back. Optional bulb SFX tick on the dip.
- **Vignette:** a full-screen ColorRect with `a = smoothstep(0.45, 0.95, distance(UV, vec2(0.5)))*0.65`, color PIT_BLACK. The loss variant tints to DANGER (see §6).
### Z-order (low → high)
| z | Layer |
|---|---|
| 0 | Background OXBLOOD |
| 1 | Rim, felt (+shader), point row, Pass Line |
| 2 | Chip stacks on the table |
| 3 | Dice shadows |
| 4 | Dice |
| 5 | Point puck |
| 6 | Table particles (sparks, embers) |
| 7 | Bulb light (additive), vignette |
| 8 | HUD: Soul meter, bankroll, ROLL button (CanvasLayer 5) |
| 9 | Sum label, banners (CanvasLayer 10) |
| 10 | Full-screen flashes (CanvasLayer 11) |

## 2. Plain bone dice
- **Size:** 120×120 px at 1080p (PC), never under 48 px on screen. **Corner radius:** 18% of size (≈ 22 px).
- **Body:** StyleBoxFlat BONE, radius 22, `border_width` 4 PIT_BLACK (the toon outline).
  - Edge shade: inner StyleBoxFlat or shader, with the bottom and right 10% of the face blended to BONE_SHADE, plus a 2 px top-left highlight #FFF6E0.
  - Optional faint grime: 4% noise.
- **Pips:** circles (draw_circle in `_draw()`), PIT_BLACK, **diameter = 0.18 × size**. Positions are fractions of the face (0–1), with columns at 0.27 / 0.50 / 0.73:
  - 1: (0.5,0.5)
  - 2: (0.27,0.27),(0.73,0.73)
  - 3: 2 + (0.5,0.5)
  - 4: (0.27,0.27),(0.73,0.27),(0.27,0.73),(0.73,0.73)
  - 5: 4 + (0.5,0.5)
  - 6: 4 + (0.27,0.5),(0.73,0.5)
  - Each pip gets a 1 px BONE_SHADE inner ring to suggest a recess.
- **Drop shadow:** a separate rounded rect, PIT_BLACK at 45% alpha, offset (6, 10), blur via StyleBoxFlat `shadow_size` 8. During the throw the shadow offset and size scale with the die's "height" (h 0→1: offset ×(1+2h), alpha ×(1-0.5h), size ×(1+0.3h)).
- Top-down only. The 3D tumble is faked with scale squash and face swaps, not a 3D cube.

### Roll animation (both dice, slightly desynced)
| Phase | Time | What | Easing |
|---|---|---|---|
| Wind-up | 0.00–0.12 s | dice scale 1.0→0.9, hop back 20 px toward the ROLL side | EASE_OUT, TRANS_QUAD |
| Throw arc | 0.12–0.62 s | position from the throw origin (1700, 760) to a random land point in the zone; fake height h: 0→1→0.15 (a parabola); scale = 1 + 0.35h; rotation +540–900° (random sign) | position TRANS_SINE EASE_OUT; h with a custom curve |
| Tumble flicks | during the throw | swap the shown face every 45–70 ms (random non-repeating), squash the scale X by 0.85 for 1 frame on each swap | — |
| Bounce 1 | 0.62–0.80 s | land (h=0), squash 1.15×0.85 for 50 ms, hop h 0→0.25→0, slide 30–60 px forward | TRANS_BACK EASE_OUT |
| Bounce 2 | 0.80–0.92 s | small hop h 0.08, slide 10–20 px | TRANS_QUAD |
| Settle | 0.92–1.10 s | rotation snaps to the nearest 0°/90° ±6° jitter; flicks stop with the FINAL face; tiny wobble ±3° damped | TRANS_ELASTIC EASE_OUT (amplitude low) |
- Die B starts 0.06 s after Die A and lands 30–50 px apart. If the dice overlap, push B away along the line between them.
- SFX: a cloth "fwip" on the throw, 2–3 dry bone clacks on the bounces (pitch ±8%), a soft felt thud on settle.

### Reveal
| Time (after settle) | Beat |
|---|---|
| 0.00–0.25 s | **Hold**: nothing moves (time to read the faces). The bulb flicker is muted to 0. |
| 0.25–0.40 s | **Scale punch**: both dice 1.0→1.18→1.0 (TRANS_BACK, 0.15 s); a 1 px BONE outline flash. |
| 0.30–0.60 s | **Sum label pop**: a Label with "7" (Barlow Condensed Bold 120 px, BONE, outline 8 PIT_BLACK) spawns between the dice 60 px above, scale 0→1.25→1.0 (TRANS_BACK EASE_OUT, 0.25 s), then floats up 20 px. Color it by result: BRASS = win, DANGER = loss, BONE = point set / neutral. |
| 0.60 s → | hand off to the resolve VFX (§6) |

## 3. Chips
- **Shape:** a circle Ø 64 px (1080p) drawn in `_draw()`: base circle, an inner ring at 0.72 r (2 px PIT_BLACK at 40%), and **8 edge notches** (rectangles 10×14 px at 45° intervals around the edge, in BONE).
  - Alternative: a `canvas_item` shader on a quad with `step(fract(atan(uv)/TAU*8.0), 0.5)` in a ring band 0.82–1.0 r.
  - Outline 3 px PIT_BLACK.
- **Side/stack view:** each chip in a stack is the same circle offset **(0, −6 px)** with the bottom chip darkened 15%. Max 10 visible, then show a "×N" label (Barlow 28 px).
| Denomination | Base | Notch | Ring |
|---|---|---|---|
| 1 | BONE #E8DCC0 | #0E1414 | #BFAF8E |
| 5 | Crimson clay #A3242E | BONE | #6E1A24 |
| 25 | Felt green #2E7D5B | BONE | #123A36 |
| 100 | BRASS #B08D3C | #0E1414 | #E2C06A |
| (500, later) | Pit Black #1B1B22 | BRASS | #3B0D14 |
- Floor 1 "cheap clay": add a faint 6% noise and a 2 px chip-off notch in the outline on random chips.
- **Bet placement tween:** a chip leaves the bankroll stack, moves to the Pass Line spot in 0.22 s on an arc 40 px high (TRANS_QUAD EASE_OUT), lands at scale 1.1→1.0 with a clack, and the stack increments with a −6 px offset. Successive chips are staggered 0.05 s. SFX: a clay "clack" with pitch rising +3% per chip.
- **Payout slide:** payout chips spawn at the felt's top edge (dealer side, (960, 200)), slide to beside the bet stack in 0.30 s (TRANS_CUBIC EASE_OUT), stagger 0.04 s. Then the whole combined stack slides to the bankroll in 0.35 s (TRANS_BACK EASE_IN_OUT). The bankroll number counts up over 0.4 s.
- **Lose sweep:** a "rake" Line2D (BRASS, 10 px, with a 60×10 head rect) enters from the top, sweeps through the bet spot, and drags the chips up to (960, 160) in 0.35 s (TRANS_QUAD EASE_IN). The chips fade to 0 and scale to 0.8 at the end. SFX: a felt drag "shhk" plus a dull clack.

## 4. Point puck
- Circle Ø 96 px, outline 4 px PIT_BLACK, drop shadow like the dice (smaller).
- **OFF:** fill PIT_BLACK, an inner ring 2 px BONE at 30%, text "OFF" Alfa Slab One 30 px BONE. It rests at the left of the point row (380, 225).
- **ON:** fill BONE, inner ring 2 px PIT_BLACK, "ON" 24 px PIT_BLACK on top, and the point number Barlow Bold 40 px below it.
- **Flip:** scale X 1→0→1 over 0.18 s (swap the content at 0), TRANS_SINE.
- **Move tween:** from OFF to the number box in 0.35 s, an arc 30 px high (TRANS_BACK EASE_OUT, overshoot 1.2), and the flip happens mid-move. On arrival the box border goes to BRASS at 100%.
- **Glow while ON:** an additive circle behind the puck, radius 1.4×, color BRASS_HI, alpha 0.25→0.45 at a 1.4 s sine.
- **Return to OFF** (point hit or seven-out): flip back, move back in 0.3 s TRANS_QUAD, glow off.

## 5. Soul meter
- **Frame:** a vertical StyleBoxFlat 100×580, bg PIT_BLACK, border 6 px BRASS (with a 2 px BRASS_HI top-left), radius 18. A label "SOUL" (Alfa Slab One 30 px, SOUL color, outline PIT_BLACK) sits below it, and the value "12/20" (Barlow 32 px BONE) sits above it.
- **Fill:** an inner rect (inset 10 px) with a shader:
  - vertical gradient from SOUL_DEEP (bottom) to SOUL (top), plus a bright SOUL_CORE strip 6 px down the center at 60%;
  - the **flame top edge** is a scrolling noise displacement of the fill edge (amplitude 8 px, speed 0.6);
  - `fill_ratio` is a uniform.
  - The bar style is the default. The flame top is what makes it feel like Soul.
- **Idle flicker:** brightness 0.95–1.05 noise at 4 Hz, plus 2–3 small SOUL wisps (GPUParticles2D, amount 3, lifetime 0.9 s, upward 20 px/s, scale 0.3→0) from the top edge.
- **Drain (loss):**
  1. 0.00 s: the frame shakes ±4 px (0.2 s). A crack decal (Line2D zig-zag, 3 px PIT_BLACK with a DANGER 1 px glow) appears across the fill at the new level.
  2. 0.05–0.25 s: **red embers** (GPUParticles2D at the loss band, amount 14, lifetime 0.6 s, velocity 40–90 px/s outward and down, gravity 120, color DANGER → SMOKE alpha 0) "eat" the top of the bar.
  3. 0.10–0.60 s: the lost portion turns DANGER (a ghost bar), then shrinks to the new level (TRANS_QUAD EASE_IN). The real cyan fill drops instantly at 0.10 s.
  4. "−N" label, Barlow 40 px DANGER, floats 30 px left/up and fades over 0.6 s.
  5. The crack fades over 0.5 s.
  - **No cyan particles on loss. Ever.**
- **Restore (gain): event-only.** Soul is restored ONLY by events (per the locked design), never by a Natural or a Point hit. In the PoC this animation is built and testable (debug key) but is not triggered by table results. SOUL wisps (amount 6, lifetime 0.5 s) converge on the top edge from 80 px away. A white-cyan flash (SOUL_CORE, 80 ms). The fill tweens up over 0.45 s (TRANS_BACK EASE_OUT). The frame scale-pulses 1.0→1.06→1.0. "+N" in SOUL. SFX: a glassy chime, then a breathy swell.
- At **≤ 25%**, the idle flicker speeds to 7 Hz, the frame border lerps toward DANGER at 40%, and a soft heartbeat SFX plays every 1.2 s.

## 6. VFX moments
General rules: shake = offset noise on Camera2D (`offset`), decays over the duration. Hit-stop = `Engine.time_scale = 0.05` for N ms of real time (use a `SceneTreeTimer` with `ignore_time_scale`). Banners are Alfa Slab One on a Polygon2D ribbon (a rectangle with notched ends, 900×150 at 1080p), outline 6 PIT_BLACK. They enter scale 0.6→1.1→1.0 (0.25 s TRANS_BACK), hold, and exit scale 1.0→0.9 with fade (0.2 s).

### General WIN (base for Natural and Point hit)
- Colors BRASS / BRASS_HI / BONE.
- Particles: brass sparks (amount 24, lifetime 0.6 s, burst, velocity 150–350, gravity 300, scale 0.4→0) from between the dice.
- Shake 4 px / 0.15 s. Hit-stop 40 ms. Felt flash: an additive BRASS radial at alpha 0.25 for 0.12 s.
- Payout slide (§3). **No Soul change and no cyan on any win.** SFX: a bright chip "chink" + a rising two-note sting.
### General LOSS (base for Craps and Seven-out)
- Colors DANGER / DANGER_DARK / SMOKE.
- Particles: a red ember puff (amount 16, lifetime 0.7 s, velocity 60–140, upward drift) plus soot (amount 8, lifetime 1.0 s, SMOKE).
- Shake 6 px / 0.2 s. Hit-stop 60 ms. Vignette tint DANGER at 20% peak (in 0.1, hold 0.15, out 0.35).
- Lose sweep (§3). SFX: a low descending "bwomp" + a felt drag.

| Moment | Trigger | Banner | Colors | Particles | Shake / hit-stop | Duration | Extras / SFX |
|---|---|---|---|---|---|---|---|
| **Natural** | come-out 7 or 11 | "NATURAL!" BRASS ribbon, PIT_BLACK text | BRASS, BRASS_HI | win sparks ×32 + a starburst: a Polygon2D 12-ray star behind the dice, BRASS_HI at 40%, rotating 30°/s, scale 0→1.2 in 0.2 s, fade 0.4 s | 5 px 0.18 s / 50 ms | 1.0 s | payout slide; a "ding-ding" bell + crowd-murmur sting |
| **Craps** | come-out 2, 3, 12 | "CRAPS" BURGUNDY ribbon, BONE text (on 2: "SNAKE EYES" as subtext, 32 px) | DANGER, BURGUNDY | loss embers ×16 | 6 px 0.2 s / 60 ms | 1.0 s | lose sweep + Soul drain (§5; every Pass Line loss costs Soul); a short dull "thunk" + low brass "wah" |
| **Point set** | come-out 4,5,6,8,9,10 | "POINT 6" BONE ribbon, PIT_BLACK text (smaller: 700×110) | BONE, BRASS_HI | 10 bone dust motes along the puck path (lifetime 0.4 s) | 2 px 0.1 s / 0 ms | 0.8 s | puck OFF→ON move (§4); the point box pulses twice; a single wood "tok" + rising tension pad that loops quietly while the point is ON |
| **Point hit** | rolled the point | "POINT HIT!" BRASS ribbon | BRASS, BONE (no Soul) | win sparks ×40, the puck emits a BRASS_HI ring shockwave (Line2D circle radius 0→240, width 8→0, 0.35 s) | 6 px 0.2 s / 70 ms | 1.3 s | payout slide, puck returns OFF (**no Soul restore**: wins pay chips only); the tension pad resolves to a major chord + chip cascade |
| **Seven-out** | rolled 7 while the point is ON | "SEVEN OUT" DANGER_DARK ribbon with a DANGER outline, BONE text, ribbon shakes | DANGER, DANGER_DARK, SMOKE, PIT_BLACK | loss embers ×36 + soot ×16, **felt cracks** (4–6 Line2D zig-zags PIT_BLACK 4 px with a DANGER 2 px glow, growing from the dice outward over 0.3 s), the puck "cracks" (flash DANGER) | 10 px 0.35 s / 120 ms | 1.8 s | lose sweep, Soul drain (§5), vignette DANGER 35% (25% mobile), the bulb dips to 0.3 for 0.4 s; the tension pad cuts dead → a 0.15 s silence → a deep "thoom" + glass crack + low choir hit |

### Escalation rule (making a seven-out heavy)
- Seven-out always gets **the strongest loss values** (above) and a **silence beat** (all SFX and music ducked −24 dB for 0.15 s right before the impact).
- **Scale with stakes:** for every roll spent on the current point after the first, add +1 px shake (cap +6), +10 ms hit-stop (cap +60 ms) and +4 embers (cap +24). Long point chases end harder.
- **Scale with Soul danger:** if the loss would put Soul at ≤ 25%, add the low-Soul heartbeat and hold the DANGER vignette at 15% until the next win.
- **Never stack:** the seven-out replaces the general loss VFX; it doesn't add to it.
### Reduced-motion variant (Settings toggle; also honor the OS setting where available)
- Shake 0. Hit-stop 0. No felt cracks or starburst rotation. Particle counts ×0.3.
- Banners fade in/out (0.2 s) with no scale pop.
- Dice throw: a straight 0.4 s slide plus 2 face flicks (no arc or bounces).
- Vignette capped at 15%, and the bulb flicker is off.
- Timing totals shrink by about 30% (see §7).

## 7. Table cycle — state → visual timing
| State | Visuals | Duration (target) |
|---|---|---|
| **BET** (come-out only; the bet stays during the point phase) | Pass Line border pulses; the bankroll stack is tappable; tap = +1 chip (bet placement tween); ROLL is enabled once the bet is ≥ 5 Coin (max 25) (ROLL idle: a slow 1.5 s EMBER glow pulse, scale 1.0–1.03) | player-paced (first bet ≈ 1.0 s of animation) |
| **ROLL** (pressed) | ROLL press: scale 0.92 (60 ms) → 1.0 then disabled, grayed 50%; wind-up, throw, bounces, settle (§2) | 1.10 s |
| **REVEAL** | hold, scale punch, sum label pop (§2) | 0.60 s |
| **RESOLVE** | one moment from §6: Natural 1.0 / Craps 1.0 / Point set 0.8 / Point hit 1.3 / Seven-out 1.8 / no-decision (any other number during the point phase): a sum label in BONE + a soft "tok", 0.35 s | 0.35–1.8 s |
| **RESET** | dice slide back toward the throw origin and fade to 60% (0.3 s), the sum label fades, banner exit, ROLL re-enables (scale pop 1.0→1.08→1.0) | 0.40 s |
**Target cycle:** a typical roll (press → ROLL ready again) is **≈ 2.5 s**. The full come-out-to-decision cycle with a Natural is ≈ 3.1 s, and a Seven-out ≈ 3.9 s. **Fast-roll:** a tap during REVEAL/RESOLVE skips to the result state and plays at 2× speed (minimum 0.8 s per roll). Reduced-motion: about 1.8 s typical.
Input is locked during ROLL→RESOLVE, except for the skip tap.

## 8. Readability rules (small mobile screens)
1. Dice ≥ 48 px on screen (target 64+ on phones). Pips ≥ 0.18 × the die, always PIT_BLACK on BONE.
2. Nothing important is conveyed only by color: win = BRASS + rising SFX + "!" banner; loss = DANGER + cracks/vignette + a descending SFX; point ON = a white puck *and* the word "ON".
3. All text ≥ 28 px at 1080p (≈ 14 pt on a 6" phone). Labels always have a 6 px PIT_BLACK outline. Banners use at most 2 words.
4. Touch targets ≥ 120×120 px at 1080p. ROLL lives in the bottom-right (landscape) or bottom-center (portrait) thumb zone. Nothing interactive within 5% of the screen edges or the device safe-area insets.
5. Keep felt noise subtle (≤ 8% luminance variation), so dice and chips always win on contrast. Test with a grayscale screenshot: dice, puck and ROLL must stay the brightest elements.
6. Particles never cover the dice faces during REVEAL (spawn behind the dice, at z 3, or after 0.25 s).
7. The vignette maximum on mobile is 25%, and the HUD (Soul meter, bankroll) sits above the vignette layer.
8. Cyan only for Soul, and DANGER red only for loss. Never reuse them for decoration.
9. Performance: aim for ≤ 150 live particles total on mobile, and use CPUParticles2D on the Compatibility renderer. All shaders are single-pass, with no screen-texture reads except the optional heat/vignette.

## Decisions (confirmed by PM, Oct 18, 2026)
- A Pass Line loss costs **Soul as well as chips**. Every loss plays the Soul drain (red embers, crack, ghost bar) alongside the lose-sweep. Set `soul_on_loss = true`.
- **Soul is never restored by wins** (Natural or Point hit). It only comes back at events, per the locked design. Cyan restore wisps are reserved for event restores.
- Betting is **tap-to-stack, 5–25 Coin, placed before each come-out**. Each tap adds one chip (bet placement tween). ROLL stays disabled below 5 Coin, and further taps are refused at 25 with a short shake on the stack and a dull clack.
