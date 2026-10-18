# Dice Rarity Visual Language — DICE OF THE DAMNED (v0.1)

> **Tier names:** the base tier is **Bone** (canonical, per PM). "Common" is retired.
>
> **STATUS: PARKED. Cut from the proof of concept.** Rarities, drawback faces and the Sacrifice Altar are NOT part of the PoC (roll → reveal → win/loss → table cycle with 2 plain dice and Pass Line only). Keep this spec for a later milestone. For the PoC, see `poc_feel.md`.

Build this from the spec alone. The concept renders are reference only. Same style and palette as `style_guide.md`.
Sizes: dice render at **48 px** on the table (mobile minimum), **64–96 px** on PC and the shop, and **128 px** in tooltips and the Sacrifice screen.

## Tier names
| Tier | Default name (Cash's) | Alternates (same ladder) |
|---|---|---|
| T0 | **Bone** (canonical name, per PM; formerly "Common") | House, Ivory |
| T1 | **Mischievous** | Imp-touched, Impish, Tricksy |
| T2 | **Devilish** | Fiendish, Brimstone, Hellbound |
| T3 | **Satanic** | Infernal, Damned, Abyssal, Archfiend |
Recommendation: keep Cash's names in UI. If store or ratings review wants softer wording, swap in **Bone / Imp-touched / Fiendish / Infernal**, which keeps the same ladder and the same first-letter weight.

## Glow-color rule (why Satanic is violet, not cyan)
Soul Flame cyan **#4FE6E0** means "your soul / your health" and appears nowhere else. A cyan or violet-cyan Satanic glow would read as Soul pickups or healing at 48 px, especially next to the Sacrifice altar where real soul-wisps fly. So Satanic uses **Hellfire Violet #9B3DFF**. It is the only purple-family glow in the game, it is maximally distinct from cyan, ember and green, and it still feels like the deepest, "wrongest" fire. The four glow hues sit far apart on the color wheel: none / lime (~80°) / orange (~25°) / violet (~270°). Soul cyan (~178°) stays alone.
Mischievous lime #B6F23A is intentionally yellower than the Lucky Die green #5FD068, so a Lucky die of Mischievous tier still reads as two separate signals.

## Per-tier spec

### T0 — Bone
- **Base** #E8DCC0 (Bone), shadow side #BFAF8E. **Edge/rim** #0E1414 ink outline, 2 px at 48 px. Corners rounded (radius ≈ 12% of die size).
- **Pips:** round dots, #0E1414, diameter ≈ 18% of the face.
- **Glow:** none (intensity 0). No particles.
- **Shader:** plain unshaded sprite plus a baked soft highlight. No rim light.
- **48 px readability cue:** plain square with rounded corners and black dots. It is the "baseline" silhouette.
- **Animation/SFX:** roll uses 6–8 tumble frames with a dry bone clack. Land: 1 squash frame (scale 1.1×0.9 for 60 ms), wood/felt thud. Idle: static.

### T1 — Mischievous
- **Base** #F2E6C8 (lacquered ivory) with a glossy specular streak #FFFFFF at 60% opacity. **Edge/rim** #0E1414 2 px outline plus **2 prominent horn nubs** #3A332A (highlight #6B6152) on the top two corners. Each nub sticks out ≈ 14% of die size. **The horns are the main tier cue.**
- **Pips (simplified v2):** large solid lime round pips, #B6F23A, diameter ≈ 24% of the face (bigger than Bone's 18%). Each has **one thin vertical black slit** #0E1414 (≈ 12% of pip width, full pip height) and a 2 px #0E1414 outline. No eyelids, no almond shape, no extra detail. At 48 px each pip reads as a green dot with a dark line.
- **Glow:** Impish Lime **#B6F23A**, intensity **low (0.35)**. A soft outer glow 3 px wide at 48 px, plus a 1 px glow on each pip.
- **Shader:** unshaded rim light (fresnel-style edge add, #B6F23A, 0.3). Specular glint sweep: a UV-offset gradient band crosses the die every 3–4 s, duration 0.4 s.
- **Particles:** occasional "glint" star sprite (GPUParticles2D, amount 2, lifetime 0.6 s, one-shot every 2.5–4 s randomized, scale 0.3→0, color #E9FF9A).
- **48 px cue:** horn nubs breaking the top silhouette plus big lime dots. If space is tight, drop the slit at ≤32 px and keep the dot.
- **Animation/SFX:** roll at a slightly faster tumble (+10%) with a high giggle-chirp on the throw. Land: a little hop (bounce once, 40% height), a "ting" glint flash, and a "wink": the slits scale to 0 width and back over 120 ms. Idle: the slits blink every 4–6 s, and the die tilts ±3° once in a while.

### T2 — Devilish
- **Base** #4A0E18 (burgundy obsidian), glassy highlight #8A2A36, darkest #22060C. **Edge/rim** brass corner caps **#B08D3C** with highlight #E2C06A on all 8 corners. Each cap is a triangle ≈ 18% of the side, outlined #0E1414 2 px. The corners read as gold "points" at 48 px.
- **Pips:** small flame shapes (teardrop with a curled tip). Fill #FF8A2A, core #FFD27A, outline #3B0D14.
- **Glow:** Ember **#FF7A1F**, intensity **medium (0.6)**, outer glow 4 px at 48 px. The pips self-illuminate.
- **Shader:** flame pips get a small vertical sine wobble (UV distortion, amplitude 1 px, 3 Hz) and an emission flicker of 0.85–1.0 (noise, 6 Hz). Rim light #FF7A1F at 0.35 on the lower edges.
- **Particles:** ember trail (GPUParticles2D, amount 12, lifetime 0.8 s, gravity −20 px/s² upward, initial velocity 10–25 px/s, scale 0.25→0, color ramp #FFD27A → #FF7A1F → #3B0D14 alpha 0). The trail is emitting only while the die is moving. Idle: 2 embers per second.
- **48 px cue:** gold corner points plus orange flame pips on a dark body. It is the first tier with a dark body.
- **Animation/SFX:** roll has a heavier tumble, a fire "whoosh" on the throw, and a crackle loop while moving. Land: a 0.15 s ember-burst ring (16 particles), brass "clank", and a 4 px camera shake. Idle: pip flicker plus slow ember drift.

### T3 — Satanic
- **Base** #0B0A10 (pitch black, faint violet tint). **Molten crack network (official: orange cracks under a violet aura)** #FF5A1A (core #FFC36A) in thin lines across all faces. **Edge/rim:** curved horns **#1A1620** with highlight #4B3F5C on the top two corners. Each horn sticks out ≈ 22% of die size and curls outward, so the silhouette is the largest of the four. Outline #0E1414 2 px plus a violet outer glow.
- **Pips:** original "sigil-eye" pips: a ring with a slit-pupil eye inside, glowing #C48BFF with core #F2E2FF and a #9B3DFF ring. This is not a real occult symbol.
- **Glow:** Hellfire Violet **#9B3DFF**, intensity **high (0.85)**, outer aura 6 px at 48 px, plus licking flame tongues.
- **Shader:** cracks use a scrolling noise mask (2D noise texture panned 0.05 UV/s, multiplied with the crack mask, emission 1.0–1.6). Heat shimmer is a screen-space UV distortion on a quad behind or above the die (noise, amplitude 1.5 px, 2 Hz). The aura uses an additive flame sprite or shader around the silhouette, scaling 1.0–1.08 at 1.5 Hz.
- **Particles:** violet fire wisps (GPUParticles2D, amount 18, lifetime 1.0 s, upward drift 15–30 px/s, turbulence on, scale 0.4→0, color #C48BFF → #9B3DFF → #2A0F45 alpha 0). Add a second emitter for orange crack sparks (amount 4, lifetime 0.5 s) when it lands.
- **48 px cue:** big horns plus violet aura plus black body. It must be recognizable from the silhouette and aura alone.
- **Animation/SFX:** roll leaves a violet afterimage trail (2 ghost copies, 30% → 0% alpha), with a low choir/drone swell on the throw. Land: impact shockwave ring #9B3DFF (0.25 s), deep "thoom", 6 px shake, and an orange flash in the cracks. Idle: slow aura breathing, crack pulse, and the eye pips glance around in sync every 5–8 s.

## Summary
| Tier | Base | Edge/silhouette | Pips (color) | Glow (intensity) | Particles | 48 px cue |
|---|---|---|---|---|---|---|
| Bone | #E8DCC0 bone | plain rounded square, #0E1414 | black dots #0E1414 | none (0) | none | plain square |
| Mischievous | #F2E6C8 lacquer | 2 small horn nubs #4A3F2A | winking eyes #B6F23A | Lime #B6F23A (0.35) | glint ×2 / 0.6 s | top nubs + green |
| Devilish | #4A0E18 obsidian | brass corner caps #B08D3C | flames #FF8A2A | Ember #FF7A1F (0.6) | embers ×12 / 0.8 s | gold corners + orange |
| Satanic | #0B0A10 black + cracks #FF5A1A | big curved horns #1A1620 | sigil-eyes #C48BFF | Violet #9B3DFF (0.85) | wisps ×18 / 1.0 s | horns + violet aura |
Reserved: Soul cyan #4FE6E0 (Soul only). Lucky green #5FD068 (Lucky Die ability only).
**Layering rule (official):** die type owns the BODY material (Lucky = bone/clover, Gold = brass coin, Heavy = cracked iron, etc.). Rarity tier owns the **edges/silhouette, pip shape and color, and glow/particles**. Every die is drawn as type body + tier overlay. Bone adds nothing beyond outline and black dots. A tier never recolors the body. If a tier's body color in the table above conflicts, use the die type's body instead; the T0–T3 base colors only apply to the generic/no-type die.

**Satanic glow (official):** a violet #9B3DFF aura with orange #FF5A1A molten cracks. The two-color read is intentional: violet = tier, orange = heat.

## Sacrifice Altar effect sequence (total ≈ 2.4 s)
Setting: a tarnished-brass furnace shaped like a demon's mouth (#B08D3C, fire inside #E8622A) on a cracked obsidian slab (#0E1414 with #6E1A24 cracks).
1. **Place (0.00–0.30 s):** the die tweens from the slot to the mouth, scale 1.0→1.2, ease-out. The mouth glow ramps 0.4→1.0. SFX: low growl.
2. **Crack (0.30–0.80 s):** 3 crack decals appear one after another (every 0.15 s) in the die's tier glow color (Bone uses #FF7A1F). Shake 2 px. SFX: ceramic/stone creak + crack.
3. **Shatter (0.80–1.05 s):** hide the die and spawn 14–20 shard sprites (GPUParticles2D one-shot, lifetime 0.6 s, explosiveness 1.0, velocity 120–260 px/s, gravity 400) in the tier's base color, plus a flash ring in the tier glow color. Hit-stop 60 ms. The mouth "chomps" (2 frames). SFX: shatter + chomp.
4. **Soul-wisp (1.05–1.85 s):** 3–6 wisps (more for higher tiers: 3/4/5/6) in **#4FE6E0** with core #DFFFFD fly along Bezier curves toward the Soul meter, staggered 0.06 s, lifetime 0.8 s, with a trail via Line2D or ribbon particles. SFX: rising breathy whoosh.
5. **Meter fill (1.85–2.40 s):** each wisp landing pulses the meter (scale 1.08, white flash 80 ms), and the fill tweens to the new value (ease-out-back). A floating "+N SOUL" label in #4FE6E0 rises 24 px and fades. SFX: glassy chime per wisp, then a soft swell.
Reduced-motion option: skip shards and shake, crossfade the die out, and use one wisp.


## Drawback faces (risky faces)
A drawback face replaces a normal face on a die, for example a skull instead of the 1. It must read as DANGER at 48 px on any tier and any body. **Never use cyan (#4FE6E0) in any drawback visual.** Cyan means you gain Soul; red means you lose something.

### Colors
| Role | Hex | Notes |
|---|---|---|
| Danger Crimson (glow, border, vignette) | **#FF2E3E** | hot pink-leaning red, distinct from Ember #FF7A1F (orange) and Burgundy #6E1A24 (dark) |
| Danger face fill (inset) | #8E0F1C | charred mid-red |
| Char / soot mottling | #2A0608 | noise overlay, 35% opacity |
| Notched border outline | #0E1414 | 2 px |
| Glyph | #F2E8D0 (bone-white) | with a 2 px #0E1414 outline |
| Desaturated state (colorblind / disabled) | #5A5050 fill, #F2E8D0 glyph | see colorblind notes |

### Frame and border (shared by every drawback face, so the family reads at a glance)
- The face is **inset** by 10% of face size (drawn as a recessed plate: inner shadow 2 px #0E1414 at the top and left, 1 px highlight #FF6B76 at the bottom and right).
- **Jagged notched border:** a sawtooth edge of 8 teeth per side (6 at 48 px), tooth depth ≈ 6% of face size, filled #FF2E3E with an outline #0E1414. **Only the danger face gets teeth**; no normal face or tier ever uses a sawtooth edge, so the shape alone says "danger."
- Fill #8E0F1C with soot/crack noise (#2A0608). Glyph centered at ≈ 55% of face size, which is larger than pips.

### Glyph list (distinct silhouettes, same frame)
| Glyph | Effect | Silhouette rule |
|---|---|---|
| **Skull** | Burns Soul (lose N Soul) | round dome + two eye holes + jaw teeth; widest at the top |
| **Cracked Coin** | Lose gold/chips | a circle split by a zig-zag gap into two halves; the gap is ≥ 12% of the glyph width |
| **Hourglass** | Curse: next-roll penalty / timed debuff | two triangles tip-to-tip with flat caps; tall and narrow, widest at the top and bottom |
The three silhouettes are round, split-round and hourglass, so they stay distinct in grayscale.

### Glow / particles / shader
- **Up-face pulse (idle, when the danger face is showing):** an additive glow #FF2E3E, intensity 0.5→0.9→0.5, 1.2 s sine loop. Border teeth emission 1.0–1.3.
- **Warning flicker:** every 2–3 s, a 2-frame hard flicker (glow 0.9→0.2→0.9 over 100 ms).
- **Ember-smoke:** GPUParticles2D, amount 6, lifetime 1.2 s, upward 10–20 px/s, scale 0.3→0.8, color #2A0608 (alpha 0.6→0) with occasional #FF2E3E sparks (sub-emitter, amount 2, lifetime 0.4 s).
- **Shader:** char noise is a static texture. Add a subtle crack-glow scroll (noise 0.03 UV/s × crack mask, #FF2E3E emission 0.4) so the face looks hot but not molten-orange.
- When the face is NOT up (mid-tumble, side faces): no particles, glow 0.3, so it stays visible on the side of the die without spamming effects.

### Land sequence (danger face lands up) — total ≈ 1.6 s
1. **0.00 s — Impact:** the normal tier land plays, then a hit-stop of 80 ms (longer than normal). SFX: dull "thunk" + low dissonant sting.
2. **0.08–0.40 s — Danger flare:** glow spikes to 1.2, 1 red ring shockwave #FF2E3E (radius 0→2× die, 0.3 s), glyph scales 1.0→1.25→1.0.
3. **0.10–0.70 s — Screen-edge vignette:** a full-screen vignette #FF2E3E at 35% peak opacity (fade in 0.1 s, hold 0.2 s, fade out 0.3 s). Mobile: use 25% to avoid hiding the UI.
4. **0.40–1.20 s — Effect travel (per glyph):**
   - **Skull:** 4–8 red embers (#FF2E3E → #2A0608) arc from the die to the Soul meter. On arrival the meter shows a **crack decal** (#0E1414 with a #FF2E3E edge glow) and the fill **drains**: the lost portion turns #FF2E3E, then shrinks over 0.4 s, and red embers flake off the fill edge (amount 10, lifetime 0.5 s, downward). **No cyan particles leave the meter.** The meter's own cyan fill just gets shorter. A floating "−N SOUL" label in #FF2E3E.
   - **Cracked Coin:** 3–5 brass chips (#B08D3C) fly from the gold/chip counter *into* the die and crumble to soot. The counter shakes, and "−N" in #FF2E3E.
   - **Hourglass:** a #FF2E3E hourglass icon flies to the dice tray / next-roll slot and stays there as a status badge (with the same notched border) until it is used up. Sand trickle particles (amount 4, lifetime 0.8 s, #F2E8D0).
5. **1.20–1.60 s — Settle:** the vignette is gone, the die glow returns to the idle pulse, and the meter crack decal fades over 0.4 s (Skull only).
Reduced-motion: no shockwave or shake, the vignette is capped at 15%, and the meter just drains.

### Colorblind safety
- The danger meaning comes from **shape first**: sawtooth border + inset plate + large bone-white glyph. None of those are used for anything positive.
- Luminance contrast: the bone-white glyph (#F2E8D0, L≈92) on the dark-red fill (#8E0F1C, L≈30) keeps high contrast in protanopia/deuteranopia simulations (red reads as dark olive/brown, the glyph stays white).
- Provide a "colorblind mode" toggle that swaps the danger fill to the desaturated #5A5050 and adds a diagonal hazard-stripe overlay (#0E1414, 20% opacity). The glyph and teeth stay, so meaning is unchanged.
- The vignette is a second, non-color cue: pair it with the hit-stop and the sting SFX so danger is announced even without color.

### Layering on tiers and die-type bodies
- The drawback face **replaces that face's pips and face fill only**. The die keeps its type body on the other faces and its tier edges, horns and corner caps.
- **Bone:** no glow conflict, so the danger face is the only colored thing on the die. Use the full spec.
- **Mischievous:** the horn nubs stay. Turn off the lime glow on the danger face itself; lime stays on the other pips. Keep a 4 px gap between the lime rim light and the red border.
- **Devilish:** the brass corner caps overlap the face corners, so draw the teeth *inside* the caps (start 1 tooth in). The ember glow is orange and the danger glow is pink-red; keep danger intensity ≥ ember intensity + 0.2 so red wins on that face.
- **Satanic:** the violet aura stays around the die. The orange cracks must **stop at the danger plate edge** (mask), so the danger face is a clean red plate with no orange cracks running through it. Danger glow is drawn above the aura.
- **Body materials:** on light bodies (bone, Lucky ivory, Gold brass) the dark inset plate gives contrast. On dark bodies (Heavy iron, Devilish obsidian, Satanic black) rely on the #FF2E3E border teeth and a 1 px #F2E8D0 inner rim line around the plate.
- **Working default: a die has at most 2 drawback faces.** If it has 2, place them on adjacent (not opposite) faces in the art, so at least one is visible in three-quarter view.


## Creative dice (beyond the d6)
Concept sheets: `dice_sheet_bone`, `dice_sheet_mischievous`, `dice_sheet_devilish`, `dice_sheet_satanic` (see README_ASSETS.md).
All are built for the 3D table camera (pitch −55°, a die ≈ 50 px), so the **top-down silhouette and the result read come first.**

**Shared rules (all creative dice):**
- **Tier language:** each die keeps its tier language: Bone = plain bone, black marks, no glow; Mischievous = lacquered ivory, lime #B6F23A, horn nubs; Devilish = burgundy obsidian, brass, ember #FF7A1F; Satanic = pitch black, orange cracks, violet #9B3DFF aura, never cyan.
- **Seeded results:** use the same **late label remap** as the d6 (`poc_3d.md` §3). The result is seeded, and the numbers or pips are per-face labels that can be rewritten while the die is spinning too fast to read. **Geometry is never changed.** For asymmetric shapes (Knucklebone, Tooth, d13) this is a free relabeling of faces, so physical face probabilities don't matter to game odds.
- **Glyph readers** (Hourglass, Black Moon, Marble Eye, Severed Hand) don't need a remap at all. Their result is *displayed* after settle by an animation, so any resting pose works.
- **Reveal readability:** at 50 px, digits on small faces are marginal. Every non-d6 die also shows its result as a **floating result chip** (`Label3D` or a 2D label, Barlow Bold, tier-colored outline) for 1.2 s at reveal. The die's own face is the primary read; the chip is the backup.
- Collision shapes exclude decorative spikes (horns, wicks, fingers) unless noted, so dice don't balance on ornaments.

| Die | Tier | Result range | How it's read from the top |
|---|---|---|---|
| Knucklebone | Bone | 1, 3, 4, 6 (4 resting sides, the classic astragalus values) | pips on the up side |
| Tooth Die | Bone | 1–3 | pips on the up side (3 resting sides between the roots) |
| Two-Face Coin | Mischievous | 0 or 7 | the big numeral on the up face |
| Marble Eye | Mischievous | 1–6 | the pupil turns to look at a lime pip-count mark on the iris ring |
| Splitter | Mischievous | 2–12 (the sum of 2 mini d6) if it splits; 1–6 as a normal d6 if it never splits | pips on the up faces of the 2 minis |
| Horned d4 | Devilish | 1–4 | the number at the **top tip** (printed near each vertex on all 3 visible faces) |
| Candle Die | Devilish | 1–8 | the ember numeral on the up face |
| Hourglass | Devilish | 1–6 | ember sand settles into the numeral in the top window |
| d13 | Satanic | 1–13 | the violet numeral on the up face |
| Severed Hand | Satanic | 0–5 | the number of extended fingers |
| Black Moon | Satanic | 1–6 | violet dots (a crescent of N dots) glow on the top of the sphere |

### Per-die build notes
**Knucklebone (Bone)**
- Mesh: a custom lumpy astragalus, ~1.2k tris, 0.10 m long. 4 broad resting sides (two wide and two narrow), plus 2 rounded ends it can't rest on.
- Collision: a simplified `ConvexPolygonShape3D` (≈ 16 points) with slightly flattened sides, so it rests reliably.
- Result: of the 4 side normals, the one closest to UP. The ends are excluded (if an end points up, it's cocked: nudge).
- Physics quirk: low bounce (0.15). It tends to slide rather than tumble, so add a +20% spin on the flick.
- 50 px risk: the silhouette (a dog-bone shape) reads well. The pips must be big (≥ 20% of the side width). Keep the 1 and 3 sides visually distinct from 4 and 6 with pip spacing.

**Tooth Die (Bone)**
- Mesh: a molar crown with 3 stubby roots, ~1.5k tris.
- Collision: a convex hull of the crown plus the root tips, simplified so it rests on 3 "sides" (each side = crown + 2 roots touching). Crown-up or root-up poses must be unstable: make the crown top rounded and the root tips pointed.
- Result: the side normal closest to UP among the 3 defined sides.
- Quirk: it can stand on its roots. Treat that as cocked and nudge it (or a design option: "it bit": a special result. **Design question**).
- 50 px risk: the 3-root silhouette is distinctive. The pips (1–3) are fine.

**Two-Face Coin (Mischievous)**
- Mesh: a thick coin, Ø 0.10 m × 0.022 m, 2 horn nubs on the rim (decorative, no collision).
- Collision: a `CylinderShape3D` (Jolt handles cylinders well; on GodotPhysics use a 16-sided convex hull).
- Result: sign of dot(local +Y, UP). + = 7, − = 0.
- Quirk: it spins and rolls on its edge. Add `angular_damp` 1.5 once it's spinning flat. **Edge landings:** if |dot| < 0.8 at settle, apply a tip nudge.
- 50 px risk: low. The giant numeral reads well. Make the 0 face distinct beyond color (a crossed-out or hollow 0 versus a bold 7).

**Marble Eye (Mischievous)**
- Mesh: a sphere Ø 0.07 m, with a lime iris and a pupil drawn as a shader decal that can rotate in object space. Two tiny horn nubs on top of the "eyelid" ring.
- Collision: `SphereShape3D`.
- Result: seeded. After settle, the **pupil animates** (0.35 s, TRANS_BACK) toward one of 6 marks on the iris ring; each mark is a lime pip group 1–6. **Plus** a quick blink.
- Physics quirk: **it rolls far.** Spheres have no rest face. Use linear_damp 0.9 and angular_damp 2.0 (Godot has no rolling resistance), felt friction 0.85, and start damping harder after 0.6 s so it stops within the felt. The rails make it rattle around, which is fun but can exceed the timing; give it a 2.5 s settle cap.
- 50 px risk: **high.** The iris-ring marks are tiny. Rely on the pupil direction + the result chip, or simplify: the iris itself shows N lime slits.

**Splitter (Mischievous)**
- Mesh: a d6 with a visible seam and horn nubs. Two pre-made half-scale mini d6 (0.055 m) are hidden and pooled.
- Collision: `BoxShape3D`.
- **Split:** on the first rail or backboard contact with relative speed > 1.2 m/s, hide the body and spawn the 2 minis at its position, inheriting linear and angular velocity, plus ±0.5 m/s separation along the seam normal. Burst of lime sparks and a "crack-giggle" SFX.
- Result: the sum of both minis' up-faces (each seeded with the label remap). If it never hits a wall hard enough, it stays whole: d6 1–6. (**Design question:** is the split guaranteed, or only on a hard hit?)
- Quirk: it spawns 2 bodies, so settle detection must wait for all 3 dice (2 minis + the other die).
- 50 px risk: the minis are ~35 px. Pips must be bold. Show the sum chip.

**Horned d4 (Devilish)**
- Mesh: a tetrahedron, 0.09 m edge, with small brass horns on the 4 tips (decorative, outside the collision).
- Collision: a `ConvexPolygonShape3D` with the 4 vertices only.
- Result: the vertex with the highest world Y (the top tip). Numbers are printed near each vertex on all 3 faces meeting there (classic d4 layout), so the top tip's number appears 3× around it.
- Quirk: d4s barely roll. Increase the flick spin by +40% and lower the felt friction locally (or accept short tumbles).
- 50 px risk: medium. Three small numbers near the tip; make them big and ember-glowing, plus the result chip.

**Candle Die (Devilish)**
- Mesh: an octahedron (d8), 0.09 m, made of wax drips. A wick plus flame on one vertex (the flame is a child that always points world-up; fire rises).
- Collision: a `ConvexPolygonShape3D` (6 vertices).
- Result: the face normal closest to UP.
- Quirk: **wobble.** It's lower-friction wax (0.35) with a slightly off-center mass (`center_of_mass_mode` custom, offset 0.004 m toward the wick vertex), so it rocks before settling. Extend the settle time window to 0.2 s. The flame leans opposite the velocity (shader or skew) and gutters on hard impacts.
- 50 px risk: medium. The numerals on the d8's triangular faces are small. Put the ember numeral large and centered.

**Hourglass (Devilish)**
- Mesh: a brass-framed d6 with a glass window on every face. Inside is a sand particle volume or a shader plane.
- Collision: `BoxShape3D`.
- Result: seeded and displayed. After settle, the sand in the top window pours and forms the ember numeral (0.4 s), so it has a built-in reveal delay. While rolling, the sand sloshes (a shader driven by angular velocity).
- 50 px risk: low. The top window is the whole face. The numeral should fill 70% of the window.

**d13 (Satanic)**
- Mesh: a custom irregular 13-faced convex polyhedron (faces of different sizes), small horns, orange cracks. A fair 13-sided solid doesn't exist, which is the joke and also fine, since results are seeded.
- Collision: a `ConvexPolygonShape3D` of the same 13-face hull (horns excluded).
- Result: the face normal closest to UP. All 13 faces carry labels, and the label remap makes any landing face show the seeded value.
- Quirk: it rolls unevenly and sometimes rests on very small faces at an angle. Accept a lower threshold (dot ≥ 0.9). Small faces rarely land; the remap handles that.
- 50 px risk: medium. "13" is two digits on a small face. Use violet with a bone outline, plus the result chip.

**Severed Hand (Satanic)**
- Mesh: a rigged low-poly clawed hand (~3k tris, 5 fingers + palm, 2 bones per finger).
- Collision: one `ConvexPolygonShape3D` for the palm + a closed fist (fingers curled during flight, like a thrown fist). Not a ragdoll.
- Result: seeded and displayed. After settle, the fingers **animate open** to show N extended (0.5 s, staggered, with crackling-knuckle SFX). The hand lands palm-down or palm-up; both work, and the animation adapts.
- Quirk: it tumbles like a lumpy rock. Make it heavier (mass ×1.5) so it doesn't fly.
- 50 px risk: **high.** Fingers are thin at 50 px. Make the fingers thick and spread wide, with violet-glowing fingertips on the extended ones, so the count reads as dots. Show the result chip.

**Black Moon (Satanic)**
- Mesh: a smooth black sphere Ø 0.07 m with a violet rim/aura shader.
- Collision: `SphereShape3D`. The same rolling settings as Marble Eye (it rolls far).
- Result: seeded and displayed. The result appears **at the top of the sphere in world space** (a shader projecting from world UP, so it's always on top regardless of rotation): N violet dots in a crescent (1–6). They fade in over 0.3 s after settle.
- 50 px risk: medium. The dots are small. Use ≤ 6 dots large enough, and a violet halo pulse.

### Design questions for PM
- **Severed Hand:** is 0 a valid result (a fist)? How does a hand total combine with a d6 in Pass Line math (0–5 can't make 7 the same way)?
- **Black Moon / Hourglass / Marble Eye:** these are "displayed" results, so players may feel the result is decided after the roll. Is that OK, or should they show their value mid-roll (for example the Black Moon dots flicker through values and lock on settle)?
- **Two-Face Coin (0/7):** paired with a d6, does a 7 on the coin mean an automatic Natural on the come-out?
- **Splitter:** is the split guaranteed? Does it count as 2 dice for any effect?
- **Knucklebone (1/3/4/6) and Tooth (1–3):** confirm their values, since they skew the craps odds.
- **Tooth Die:** standing on its roots: a nudge or a special result?
