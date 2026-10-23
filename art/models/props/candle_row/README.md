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
