# Nerve bone token (world_props_v1 §4)

A bone tablet (oxblood up/down chevron inlay) standing in an iron cradle on a short brass rail.
Art only: no gameplay code. Gameplay drives it through `scripts/nerve_token.gd` (`class_name NerveToken`).

## Files
- `nerve_token.glb` (PC LOD), `nerve_token_mobile.glb`. Built by `src/build_nerve_token.py` (Blender 4.5 LTS),
  then `src/make_nerve_token.gd -- materials`, `src/write_imports.py`, `godot --headless --import`,
  `src/make_nerve_token.gd -- scenes`.
- `scenes/nerve_token.tscn`, `scenes/nerve_token_mobile.tscn`; `materials/nerve_*.tres` (copies of the Hearth
  dressing materials, toon_noir + ink next pass, rim_emit 0, so there's no glow).
- Renders: `src/render_nerve_token_game.gd` (real game camera + HUD clearance), `src/render_nerve_token.gd`
  (48 px strip, close-up sheet). Output: `art/renders/nerve_token/v1/` (outside the repo).

## Tris
| part | PC | mobile |
|---|---|---|
| tablet | 40 | 24 |
| chevron inlay | 32 | 32 |
| notch | 7 | 7 |
| cradle | 36 | 36 |
| track | 12 | 12 |
| **total** | **127** | **111** |

Hearth worst case with the candle row: PC 13,876 + 127 = **14,003 / 15,000**; mobile 6,500 + 111 = **6,611 / 8,000**.

## Nodes
`NerveToken > Rig (scale 1.8) > Track, Cradle, Slide > Bob > Lift > Pivot > Tablet, Chevron, Notch, TooltipAnchor`.
Marker3Ds: `Home`, `TrackStart`, `TrackEnd`, `TapCenter`.

## States (`set_state(s, animate := true)`)
| state | pose |
|---|---|
| AVAILABLE | upright in the cradle |
| CARRIED | upright, notch shown |
| PICKING | lifts 12 mm |
| NUDGED | tips 35° toward the felt |
| SPENT | lies flat face-up, grey (`*_spent` overrides) |
| CLOSED | keeps the lean, drops the lift |
| RESCUE | lifts 30 mm (clears the cheeks), slides along the rail (`rescue_at(world_pos)`, clamped), bobs 6 mm at 1 s |

`shake()` is a one-shot refusal (±10°, 5 drawings). All motion is stepped on twos (1/12 s).
`reduced_motion` snaps to the end pose with no bob and no shake. `from_ui_state(ui, carried)` maps NerveState.UiState.

## Placement (proposed; no Hearth anchor until #142 merges)
PC (0.48, 0.11, 0.578); phone landscape (0.30, 0.11, 0.61); portrait (0.85, 0.11, -0.16), yaw 90 (v2: inward on the felt edge, in the lamp pool).
The spec's spot between the Soul meter and the candle row has no room, so it sits right of the hint text and the Pot.
