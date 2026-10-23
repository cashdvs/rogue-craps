# Candle row (hands left) - prototype v1

Original asset. Code-built (Blender -> .glb, Godot script -> .tres/.tscn). Source: PR #133 `world_props_v1.md` §2.1 + AD rulings
(cap 8; Ashmouth/Vig: empty socket + cold stub; Bodkin: +1 candle with a brass ring).

## Files
| path | what |
|---|---|
| `candle_row_{candle,holder,socket,ring}.glb` | 21 / 20 / 4 / 12 tris, toon_noir + ink outline, clean UVs |
| `materials/candle_row_*.tres` | wax (tallow #DCC79F), wax_lit, wax_cold (ash #7A7166), flame(_mobile), drip |
| `shaders/candle_row_flame.gdshader`, `candle_row_drip.gdshader` | flame card (instance `heat/level/pulse`), on-twos drip |
| `scenes/candle_row(_mobile).tscn` | `CandleRow`: Holder, `Sockets/Socket1..8` (Marker3D, pitch 0.058), GiftRing1/2, `LightAnchor` (Marker3D) |
| `scenes/candle_row_candle(_mobile).tscn` | `Candle`: Plate, Model, Flame, Wisp, Drip, AnimationPlayer |
| `scripts/candle_row.gd`, `candle_row_candle.gd` | API below |

## API (CandleRow)
```
row.table_start(goal_hands, delta)  # delta -1 Ashmouth/Vig (stub), +1 Bodkin (gift + ring); rise_in on gift
row.spend(bust := false)            # snuff the rightmost lit candle (bust: gutter + drip first)
row.table_end()                     # all cold
row.hands_left = n                  # snap, no anim
row.reduced_motion = true           # no rise/drip/wisp travel, instant states
row.lit_count(), row.light_level()  # for a light hookup at LightAnchor
```
Candle states: EMPTY, LIT, COLD, STUB; clips RESET, snuff (0.6 s), snuff_bust (1.0 s), rise_in (0.5 s), keyed on twos.
Last hand: gutter 0.5 on the last lit candle. Signal `snuffed`.

## Rebuild
```
blender -b --factory-startup --python-exit-code 1 --python src/build_candle_row.py
python3 src/write_imports.py
godot --headless --path . --import
godot --headless --path . --script res://art/models/props/candle_row/src/make_candle_row.gd -- materials
godot --headless --path . --script res://art/models/props/candle_row/src/make_candle_row.gd -- scenes
xvfb-run -a godot --path . --rendering-driver vulkan --script res://art/models/props/candle_row/src/render_candle_row.gd
```

## Tris
Row all meshes 292 (same both LODs). Drawn: 4 lit 128, 3/4 126, Ashmouth 126, Bodkin 167, 8 lit 236, table end 120.
Hearth with floor trim: PC 14,694 + 292 = 14,986 / 15k; mobile 6,830 + 292 = 7,122 / 8k.

## Metrics (renders `art/renders/candle_row/v1/`)
Row p97 luma 0.510 vs dice 0.959 PC (53 %), 0.520 vs 0.949 phone (55 %). Socket pitch 46.7 px PC / 19.8 px phone.

## Not done
Not placed in the board scene; no glow decal; tri test doesn't include the row; ring and drip weak at 48 px.

## v2 (art rulings, Oct 2026)
- Brass ring at BRASS_HI #E2C06A, 1.3x thicker (64 tris, `candle_row_ring.tres`).
- Bust: drip slower (~0.4 s) and bigger, leaving a wax bead on the holder (`candle_row_bead.glb`, 12 tris). Clip `snuff_bust` is 1.25 s.
- hands_left > 8: all 8 lit and the brass ring on candle 8 is the "more than shown" cue. At 8 or fewer, sockets map 1:1. Hooks: `add_hands(n)`, `over_cap()`.
- hands_left == 1: the flame gutters (`gutter` clip, about 0.5 level, uneven flicker plus wisp). It goes back to normal when a hand is added. Note: reduced motion stops the clip but not the shader flicker.
- Phone: ROW_SCALE 1.4 (about 20 px candle, 27 px pitch on an 844x390 synthetic cam).
- Tris (all meshes): holder 20 + 8 × (candle 27 + socket 4 + wick/flame/bead) + rings 128 = 540. Drawn: 4 lit 152, 8 lit 284, >8 cue 348.

### Placement
- `Hearth Anchors/CandleRow` Marker3D at (-0.36, 0.11, 0.61): on the near rail, left of the pot, shared by PC and landscape phone. Candles 1-5 clear Bank on landscape phone. Candles 6-8 sit under the "Pot"/hint labels, and on PC candle 1 touches the Bank button edge.
- The portrait camera crops the near rail entirely. PROPOSAL: `Anchors/CandleRowPortrait` (1.11, 0.11, -0.05), yaw 90°, on the screen-bottom rail left of the cauldron. It is on screen and uncropped. It still needs AD sign-off and an orientation switch in HUD code (not done).
- Real-camera check: `src/render_candle_row_game.gd -- phone=WxH anchor=... out=...`.

## v3 (AD Oct 22): placement
- Spacing is tightened: `PITCH_SCALE` is PC 0.94 and phone 0.87, and the holder bar is shortened to match. Candle size is unchanged.
- There are three markers, one per screen layout:

| Marker | Used for | Position |
|---|---|---|
| `Anchors/CandleRow` | PC | (-0.333, 0.11, 0.61) |
| `Anchors/CandleRowPhone` | landscape phone | (-0.384, 0.11, 0.61) |
| `Anchors/CandleRowPortrait` | portrait (AD-approved) | (1.11, 0.11, -0.05), yaw 90° |

- Measured with 8 lit in the real game camera (`src/render_candle_row_game.gd`, label glyph extents, viewport px):
  - **PC (1920x1080):** pitch 44.1 px, candle 35.3 px. Clearance to Bank 14.1 px and to the "Pot" label 14.8 px. The orange hint line under Pot starts at x 667, and candles 4-8 stand over its top edge (about 7 px vertical overlap). The 12 px rule is NOT met against the hint.
  - **Landscape phone (844x390, measured at 2337x1080):** pitch 67.1 px (24.2 px at 844x390, at the floor), candle 64.2 px. Clearance to Throw/Bank 14.2 px. Candles 6-8 run 185 px under "Pot 0" and the x/= labels. The gap is 351 px, and 8 candles at the 24 px floor need at least 465 px + one candle, so this can't be solved by shrinking the candles.
  - **Portrait:** fully on screen, pitch 143.5 px at 1920x4155. With 8 lit, the row spans the cauldron (candles 4-5 sit behind it). With 4 or fewer it is left of the cauldron.
- Tris are unchanged at 540 for the row. Worst case board + row (>8 cue): PC 13,792, mobile 6,416.

## v4 (AD sign-off Oct 22): two-tier row
- PC and landscape phone use two tiers of 4: hands 1-4 on the front bar, 5-8 on a back bar (`HolderBack`) 0.040 m behind, offset half a pitch so every flame shows. `PITCH_SCALE` is back to PC 1.0, phone 0.87 (24.2 px at 844x390). `HolderBack` is hidden while 4 or fewer sockets are used, so 4 lit is one clean front row.
- Spends snuff from the back tier's right end (socket 8) first. Bodkin's ringed extra candle takes the next free socket. The >8 cue ring stays on candle 8.
- Portrait keeps the single-file layout, moved so all 8 lit clear the cauldron.

| Marker | Used for | Position |
|---|---|---|
| `Anchors/CandleRow` | PC | (-0.40, 0.11, 0.578) |
| `Anchors/CandleRowPhone` | landscape phone | (-0.51, 0.11, 0.61) |
| `Anchors/CandleRowPortrait` | portrait | (1.11, 0.11, 0.275), yaw 90° |

- Clearances, real game camera, label glyph extents, viewport px (renders `art/renders/candle_row/v4/`, rule >= 12 px):
  - **PC 8 lit:** pitch 46.4 px, candle 35.2 px. Hint 16.0 px below, Throw/Bank 49.7 px left, Pot not within 60 px. At z 0.578 the back tier sits on the felt edge.
  - **Landscape phone 8 lit:** pitch 67.1 px at 2337x1080 (24.2 px at 844x390), candle 63.9 px. Pot 28.2 px right, hint 26.7 px below, Throw/Bank 29.7 px left, x/= labels clear. 4 lit: hint 26.7, Bank 29.7.
  - **Portrait 8 lit:** on screen, pitch 143.5 px at 1920x4155, 27.7 px clear of the cauldron. The upper candles overlap where sandbox dice come to rest.
- API additions: `over_cap()` (hands_left > 8), `lit_count()`; `const TIER := 4`. Godot Dev must instance the row and pick the marker by orientation (not done here).
- Tris: all meshes 2 x 20 holders + 8 x candle set + rings 128 = 560. Drawn: 4 lit 152 (back bar hidden), 8 lit 304, >8 cue 368. Worst case board + row: PC 13,444 + 368 = 13,812 / 15k; mobile 6,068 + 368 = 6,436 / 8k.
- Test: `tests/test_candle_row.gd` (tiers, snuff order, rings, back bar toggle, gutter), 28 checks, PC + mobile.
