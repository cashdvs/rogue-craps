# Soul Reliquary (world_props_v1 §2.2, AD pick health_3d #1)

The 3D Soul meter that replaces the flat HUD Soul bar: a glass vessel in a brass cage on a plinth, with a
Soul-cyan (#4FE6E0) liquid driven by the vessel shader's `fill`. The **numeral is the source of truth**:
`cur/max` in cream digits (Label3D) on a near-black plate inside a brass frame, always light-on-dark.

## Use (Godot Dev)
- Instance `scenes/soul_reliquary.tscn` (PC) or `soul_reliquary_mobile.tscn` at the Hearth markers
  `Anchors/SoulReliquary` (PC), `Anchors/SoulReliquaryPhone` (landscape phone), `Anchors/SoulReliquaryPortrait`
  (portrait phone, yaw 90 so it faces the portrait camera).
- `set_soul(cur, max, animate := true)`. `lethal = true` when the next bust kills. `reduced_motion` cuts to the end.
- Max Soul above 35 grows the cage one step (+10 mm, `GROW_H` 0.010; was 12 mm, cut for candle clearance at max 120, QA PR #150) per started 5, max 8 steps; growth plays FIRST, then the fill.
- States: full, mid, low (frost on the glass at soul <= `SOUL_FROST_AT` = 5), lethal (crack on the frame), grow.

## VFX hooks (owned by VFX, not driven here)
`set_ghost(fill_top, alpha)` (red lost chunk), `pulse` 0..1 (heartbeat), `Rig/Cage/Top/DeltaAnchor` ("-N"),
`Rig/Cage/LiquidTop` (follows the liquid surface), `Rig/TooltipAnchor`, `Rig/PlateCenter`.

## Rules the art keeps
- Crack is a separate mesh on the frame band only; frost is shader-only on the glass above the liquid. Neither
  overlaps the digit window (tested: every crack vertex is outside the digit cap box + 1 mm).
- Cyan only in `shaders/soul_vessel.gdshader`. Other materials are Hearth toon_noir copies with the ink pass.
- v2 (AD Oct 23): the brass emission self-lift is gone (energy 0). A local `BrassFill` OmniLight3D (#FFB070, energy 0.6,
  range 0.20 x rig scale, no shadow) lifts the cage; its cull mask skips the plate layer (1<<9), so the digit plate is
  never lit harder than the cyan liquid. Plate enlarged (digit cap 0.0320, width 0.124): every digit >= 24 px on phone landscape.
- v3 (AD Oct 23): portrait-only **stacked fraction** (`plate_layout = "stacked"`, read from the marker's
  `metadata/plate_layout`; PC/landscape keep `"row"`). `Rig/Stacked` is a slanted placard (42 deg) in front of the plinth:
  current on top (`DigitsCur`, cap 0.047), a short brass bar, max below (`DigitsMax`, cap 0.043; its pixel_size is
  never larger than the current's). Both auto-fit a 0.064 window, so 3 digits shrink a little instead of overflowing.
  Portrait capture (780x1688): 18/35 = 33/29 px, 105/120 = 27/26 px, 999 ~24 px. Values >= 1000 would drop below 24 px.
  The rules have no max-Soul cap (run_progress.gd `max_soul = maxi(1, max_soul + delta)`, `+= contract_max_soul`), so
  the display guarantee is documented as **<= 999**. Stacked crack is on the frame band only, clear of both digit boxes.

## Budget
324 unique tris (incl. the portrait-only stacked placard); **290 drawn** in row mode, **292 drawn** in stacked mode
(crack included) <= 300. Hearth worst case (test_hearth_board drawn-count convention) + reliquary:
PC 14,662 + 290 = **14,952 / 15,000**; mobile portrait 6,818 + 292 = **7,110 / 8,000**.

## Rebuild / test / render
    godot --headless --path . --script res://art/models/props/soul_reliquary/src/make_soul_reliquary.gd
    godot --headless --path . --script res://tests/test_soul_reliquary.gd
    # renders (Forward+ / Vulkan): src/render_soul_reliquary_game.gd (game cameras; phone=844x390 | 390x844,
    # state=full|mid|low|lethal|grow|big, before=1, mask=1) and src/render_soul_reliquary.gd (close-up)

## Placement note
The brief asked for "left of the candle row". On PC/landscape that spot is under the Throw/Bank buttons, and in
portrait the bottom rail is full (candle row, cauldron, Nerve) with its ends off-screen, so PC/phone use the left
rail (PC `SoulReliquary` -1.07, 0.105, 0.14; landscape phone `SoulReliquaryPhone` -1.07, 0.105, 0.195, moved from z 0.04 so the max-120 cage clears Candle1/Candle7, lit or unlit, by >= 12 px); the left-rail candles 3/5 beside it were cut (candles mean hands only). Portrait (v3) is
never on the felt: it sits on the screen-left (world near) rail lip at (-0.12, 0.104, 0.555), yaw 90, marker scale 0.65,
stacked plate. Plinth z 0.502..0.608 and the placard's near edge (z ~0.501) stay out of the throw zone (dice reach z 0.50).
x moved from the AD's -0.09 to -0.12 (screen-up) so the placard clears "Throw 5 dice" by 26 px; plate margins
in the portrait capture: left 21.7 px, top 215 px. Note: y 0.104 floats ~15 mm above the slope raycast (~0.089) at z 0.555.
