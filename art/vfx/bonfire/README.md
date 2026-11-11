# Bonfire scoring juice: VFX (fire tiers, lit face, potted lift, Hot Hand, ash dice, banner palette)

Original work by Tiny Anvil Games (no third-party textures or meshes). Proprietary, same terms as
the rest of the repo (see `LICENSE`). Spec: `design/bonfire_map_events_juice.md` section 3 (Scoring
juice); palette: `art/concept/style_guide.md` and `scripts/table/palette.gd`. The props (wax stamp,
Soul flask, ember pile, Mult chip) live in `art/models/props/bonfire/` (own README).

**Art only.** These are plain scenes, materials and shaders: particles, meshes and an `AnimationPlayer`
per scene. There are no scripts, lights or physics nodes, and nothing is wired into game code. Godot Dev
plays the clips and sets instance parameters (see "Hooks").

Regenerate everything (materials and scenes are generated; the shaders are hand-written):

    godot --headless --path . --script res://art/vfx/bonfire/src/make_bonfire_vfx.gd -- --materials
    python3 art/models/props/bonfire/src/remap_imports.py && godot --headless --path . --import
    godot --headless --path . --script res://art/vfx/bonfire/src/make_bonfire_vfx.gd -- --scenes

`tests/test_bonfire_juice.gd` checks the clip lengths, budgets, track paths and materials.

## Style and cost
- **Toon fire** (`shaders/toon_fire.gdshader`): flat bands (outer, mid, hot core) with a thin Pit Black
  ink edge, like the ink outlines on the dice. Teardrop flames, 4-point sparks, round blobs/drops, a
  scrolling column (the pillar) and a flat shockwave ring. It is **alpha-cut** (`discard`) in the
  opaque pass, not blended, so stacked flames cost no blending overdraw (mobile-friendly).
  Particles die by eroding from the outside in (colour-ramp alpha drives that), not by fading.
- Sizes are for the 0.08 m die. Every scene's origin is the **die centre at rest** (top face y = +0.04,
  felt y = -0.04).
- **GPU + CPU:** each tier is `GPUParticles3D` in `scenes/fire/` and has a `CPUParticles3D` copy in
  `scenes/fire/cpu/*_cpu.tscn` with the same node names and clips. Use the CPU copies if
  GPU particles are a problem on a target (old GLES3 / Compatibility devices). Other scenes can be
  converted the same way (`CPUParticles3D.convert_from_particles`, as `make_bonfire_vfx.gd` does).
- No light nodes. Fire "light" is HDR colour that blooms with the table's glow (threshold 1.0); bloom only, confirmed in design section 6.

## Contents and budgets
Particle counts are per die (worst case is 5 dice), except tier 4: **one** pillar per potted group.

| Scene | What | Particles | Other | Clips (s) |
|---|---|---|---|---|
| `scenes/fire/fire_tier_1_embers.tscn` | score < 100: ember sparks rising off the die | 12 | | burst 0.8, ignite 0.12, snuff 0.2 |
| `scenes/fire/fire_tier_2_flames.tscn` | 100-299: flames licking off the top face | 18 | | burst 1.0, ignite, snuff |
| `scenes/fire/fire_tier_3_inferno.tscn` | 300-999: hellfire-red inferno wrapping the die | 40 | | burst 1.2, ignite, snuff |
| `scenes/fire/fire_tier_4_pillar.tscn` | 1000+: ONE central 0.85 m pillar of fire over the whole potted group (origin = group centre on the felt), a flame bed across the group, spark fountain and felt shockwave. The dice keep tier 3 per die | 56 per group (+ 5 x 40 inferno = 256 worst case) | 2 open cylinders (64 tris), 1 quad | burst 1.8, ignite, snuff |
| `scenes/fire/cpu/*_cpu.tscn` | CPU fallback of each tier | same | | same |
| `scenes/dice/potted_die_rig.tscn` | one potted die: lift, pop, glowing face and felt pool | 0 | 2 quads | lift_light 0.24, hold 0.6 (loop), drop 0.15 |
| `scenes/dice/potted_dice_demo.tscn` | 5 rigs (stand-in dice), staggered | 0 | | pot_sequence_normal 0.56, pot_sequence_big 0.80 |
| `scenes/dice/hot_hand_ignite.tscn` | Hot Hand ignite burst on one die | 22 | 1 quad | ignite 0.35 |
| `scenes/dice/fire_trail.tscn` | fire trail component (world-space particles) | 54 | | start, stop |
| `scenes/dice/hot_hand_demo.tscn` | 5 dice ignite and fly back to the hand trailing fire | 5 x 76 | | hot_hand 1.0 |
| `scenes/dice/ash_die_demo.tscn` | the ash dice material on a stand-in + smoke puff | 8 | | bust 0.5 (default: ash 0 -> 1 -> 0, back to bone), cracked_shatter 0.5 (Cracked die only) |

The stand-in dice in the demos are plain boxes; the real dice are `bone_d6.glb` (art/bone-d6-model).

**Timing** (section 3: a normal sequence takes <= 1.2 s, a big one <= 2.0 s): every one-shot clip is
<= 1.2 s, except the pillar burst (1.8 s), the Hot Hand demo (1.0 s plus the trail tail) and
pot_sequence_big (0.8 s). Lift stagger: **0.08 s** per die for normal pacing (5 dice lifted by 0.56 s,
leaving 0.64 s for the Mult slam, the "x" sweep and the banner) and **0.14 s** for big pacing (0.8 s).
For 2x speed set `AnimationPlayer.speed_scale = 2` (particles: `speed_scale = 2`). For instant, play
`RESET`, or the end state (`hold`).

## Hooks (what Godot Dev calls)
Instance parameters are per-node shader values (`GeometryInstance3D.set_instance_shader_parameter`,
or animate `instance_shader_parameters/<name>`). All Bonfire shaders include
`shaders/bonfire_instance.gdshaderinc`, which declares them in the same order (Godot shares one
instance block per node): `heat`, `glow`, `ash`, `dissolve`, `crack`, `fill`.

- **Tier 4 pillar (one per score, not per die):** instance `fire_tier_4_pillar.tscn` once, at the
  centre of the potted dice on the felt (y = 0): a `Marker3D` the dev owns, or the mean of the potted
  dice positions with y = 0. It is sized for 5 dice across ~0.66 m; for a tighter or wider group scale
  the root on X/Z (e.g. `scale = Vector3(spread / 0.66, 1, spread / 0.66)`). Play `burst` together with
  `fire_tier_3_inferno` `burst` on each potted die (tiers 2-3 are per die).
- **Fire tier on a die (tiers 1-3):** instance the tier scene as a sibling of the die (or a child with
  `top_level = true`) at the die's centre, kept upright. Then call `$AnimationPlayer.play("burst")` for
  the whole tier moment. To hold the fire for a custom time, call `play("ignite")` and later
  `play("snuff")`. `snuff` is also the bust "flames snuff out" (0.2 s). `local_coords` is on, so the
  fire follows the die while it lifts.
- **Lit face, scoring candidates** (tutorial: "Glowing dice score"): set
  `die_mesh.material_overlay = load("res://art/vfx/bonfire/materials/lit_face_glow.tres")` and drive
  `die_mesh.set_instance_shader_parameter("glow", 0..1)`; up to 2 makes it flare. It lights whichever
  face points world +Y (`face_dir`), so it works on `bone_d6` (1 = +Y) at any rolled value and yaw.
  `half_size` 0.04 = half the 0.08 edge. `body_glow` adds an ember rim on the rest of the die.
- **Potted lift + light-up, per die:** instance `potted_die_rig.tscn` at the die's rest centre, and
  yaw it to the die's yaw (so the `LitFace` quad lines up with the top face). Then either
  reparent the die under `Lift/DieSlot` (keeping its global transform), or set `Lift/Follow.remote_path`
  to the die (it moves and scales the die but keeps its rotation). Play `lift_light` on each die with
  `delay = i * stagger`, then `hold` while the count runs, then `drop` (or keep them up into the bank).
  Fire tiers can be added on top. The face value tick is the dev's (a label or the existing counter).
- **Hot Hand:** on each die play `hot_hand_ignite.tscn` `ignite`. Add a `fire_trail.tscn` as a child of
  each flying die, play `start` when it launches and `stop` when it lands. Its particles are world-space,
  so they trail along whatever motion path the dev uses (the demo uses a 0.5 s arc). The demo
  shows the pacing.
- **Ash dice (bust, 0.5 s). Default path: the dice go to ash and back to bone** (they stay in the
  bag). On each die mesh, `set_surface_override_material(0, ash_body.tres)` and
  `(1, ash_pip.tres)` (bone_d6 slots: body, pips). Then tween instance `ash` 0 -> 1 over ~0.12 s, hold,
  then tween `ash` back to 0 (clip `bust`: ash 0 -> 1 -> 0 inside 0.5 s).
  **Cracked die shatters** (not a bust; only when a Cracked die breaks): same swap, tween `ash` to 1, then
  `dissolve` 0 -> 1 (clip `cracked_shatter`); the die is gone afterwards.
  Clear the overrides afterwards. At `ash` = 0 the material matches the bone die, so the swap is invisible. The ember front on the spreading ash is part of the shader.
- **Combo banners:** colours below. The banner itself is the dev's UI.

## Combo banner palette (`palette/`)
`combo_banner_tiers.tres` (`ColorPalette`, rarity order) and `combo_banner_detail.tres` (4 colours per
tier: face, shade, ink/trim, glow). The swatches are drawn in `palette/combo_banner_swatches.png`.

| Tier (combos) | Face | Shade | Ink / trim | Glow | Source |
|---|---|---|---|---|---|
| Bone white (Pair, Run of 3) | `#E8DCC0` | `#BFAF8E` | `#0E1414` | `#FFE2B0` | Bone, Bone shade, Pit Black, lamp bulb |
| Ember orange (Two Pair, Trips, Run of 4) | `#E8622A` | `#A8401A` | `#0E1414` | `#F6A845` | Ember (style guide); shade/glow derived |
| Hellfire red (Full House, Run of 5, Quads) | `#C8281E` | `#6E1A24` | `#0E1414` | `#E8622A` | **new**, confirmed in design section 6 (DANGER `#FF2E3E` stays loss-only); Burgundy shade |
| Black-gold (Five of a kind) | `#0E1414` | `#B08D3C` | `#E2C06A` | `#E2C06A` | Pit Black + Tarnished Brass / Brass hi (confirmed, section 6) |

Text: Pit Black on bone and ember; Bone on hellfire; Brass hi on black-gold. Use Alfa Slab One with
an ink outline (style guide).

## Colours used by the VFX
Ember `#E8622A`, flame mid `#F6A845`, hot core `#FFE7A8`, hellfire `#C8281E`, ink `#0E1414`.
Ash `#5A5E62` / `#141618` (cool grey, so it reads grey under the warm lamp). Lit face: lamp
`#FFB070` + Ember. Soul cyan (`#4FE6E0`, `#1E8F8B`, `#DFFFFD`) is used ONLY on the Soul flask and its
drips (the test checks this).

## Files
- `shaders/`: `toon_fire`, `lit_face_glow`, `ash_die`, `ash_outline`, `soul_glass`, `soul_liquid`,
  `ember_glow` (.gdshader) and `bonfire_instance.gdshaderinc`.
- `materials/` (generated): `fire_flame`, `fire_flame_hell`, `fire_spark`, `fire_blob`, `fire_column`,
  `fire_column_core`, `fire_ring`, `fire_ring_billboard`, `ash_smoke`, `soul_drip`, `wax_crumb`,
  `lit_face_glow`, `felt_glow_pool`, `ash_body`, `ash_pip`, `ash_outline`.
- `scenes/` (generated): see the table. `src/make_bonfire_vfx.gd` is the generator.
