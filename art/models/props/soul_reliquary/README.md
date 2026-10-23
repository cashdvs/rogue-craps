# Soul Reliquary (world_props_v1 §2.2, AD pick health_3d #1)

The 3D Soul meter that replaces the flat HUD Soul bar: a glass vessel in a brass cage on a plinth, with a
Soul-cyan (#4FE6E0) liquid driven by the vessel shader's `fill`. The **numeral is the source of truth**:
`cur/max` in cream digits (Label3D) on a near-black plate inside a brass frame, always light-on-dark.

## Use (Godot Dev)
- Instance `scenes/soul_reliquary.tscn` (PC) or `soul_reliquary_mobile.tscn` at the Hearth markers
  `Anchors/SoulReliquary` (PC), `Anchors/SoulReliquaryPhone` (landscape phone), `Anchors/SoulReliquaryPortrait`
  (portrait phone, yaw 90 so it faces the portrait camera).
- `set_soul(cur, max, animate := true)`. `lethal = true` when the next bust kills. `reduced_motion` cuts to the end.
- Max Soul above 35 grows the cage one step (+12 mm) per started 5, max 8 steps; growth plays FIRST, then the fill.
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

## Budget
258 unique tris, **290 drawn** (the ring is drawn twice) <= 300. Hearth worst case with the candle row + Nerve
token + reliquary: PC 14,003 + 290 = **14,293 / 15,000**; mobile 6,611 + 290 = **6,901 / 8,000**.

## Rebuild / test / render
    godot --headless --path . --script res://art/models/props/soul_reliquary/src/make_soul_reliquary.gd
    godot --headless --path . --script res://tests/test_soul_reliquary.gd
    # renders (Forward+ / Vulkan): src/render_soul_reliquary_game.gd (game cameras; phone=844x390 | 390x844,
    # state=full|mid|low|lethal|grow, before=1, mask=1) and src/render_soul_reliquary.gd (close-up)

## Placement note
The brief asked for "left of the candle row". On PC/landscape that spot is under the Throw/Bank buttons, and in
portrait the bottom rail is full (candle row, cauldron, Nerve) with its ends off-screen, so PC/phone use the left
rail (-1.07, 0.105, 0.04); the left-rail candles 3/5 beside it were cut (candles mean hands only). Portrait (v2) is
never on the felt: it sits on the screen-left (world near) rail lip at (-0.09, 0.095, 0.565), yaw 90, marker scale 0.5,
so it is fully framed and its plinth (z 0.525..0.605) stays out of the throw zone (dice reach z 0.50).
