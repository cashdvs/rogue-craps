# Readability pass art (Art Director, Oct 19 2026)
This is the Bonfire table's readability art (how_bonfire_plays.md §4). The Art Director made it with code-generated vector art: SVG drawn by the Python scripts in `src/`, rendered to PNG with cairosvg and Pillow. No AI-generated imagery or text.

The PNGs here were copied unchanged from the Art Director's handoff, `art/ui/readability/`. Only the files the game uses are included.

## Licence
- **Art:** a studio asset of Tiny Anvil Games, proprietary like the rest of the project (see `LICENSE`).
- **Fonts:** the text in the art is set in Barlow Condensed Bold and Alfa Slab One. Both are SIL OFL 1.1, and both are already in `fonts/` with their licences (`fonts/OFL-barlowcondensed.txt`, `fonts/OFL-alfaslabone.txt`). The PNGs embed rendered glyphs, which the OFL allows. "Alfa Slab" is a Reserved Font Name, so a modified copy of the font itself must be renamed. These are renders, not font files.

## Sources
- `src/` holds the generator scripts (`felt.py`, `assets.py`, `dice.py`, `mocks.py`) and the SVG sources under `src/svg/`.
  - The SVG text is live `<text>`, so the fonts must be installed to render it.
  - `src/.gdignore` keeps Godot from importing these sources.
- The scripts write to the Art Director's folder (`common.py`, `OUT`). Point `OUT` somewhere else to rebuild.

| Folder | Used by | What |
|---|---|---|
| `felt/` | `FeltComboTable` | Combo table print over the felt: landscape band / portrait block, 2048×1044 @ 1003.9 px/m. `felt_slots.json` gives the Label3D slot centres and max widths in metres. Imported lossless with mipmaps (no VRAM compression: it smears the hairlines) |
| `bounty/` | `BountyCard` | 9-slice card frame (44 px margins, @4x), mini dice and run arrow, the oxblood PENDING ghost (25%), the CLAIMED wax seal, and the stamp-in keys (`stamp_claimed_stampin_keys.json`; played as a tween) |
| `banner/` | `ClearedBanner` | TABLE CLEARED layers 01–06 @3x (the glow layer draws with Add blend). `_metrics.json` holds the text metrics |

The dice lit/cold look is in `shaders/3d/toon_noir.gdshader` (`die_lit` / `die_cold`). It follows the Art Director's `die_state_reference.gdshader` numbers. Our pips are real meshes, so the pip core is a small emissive disc instead of a pip-mask texture.

The value-tag art (`art/ui/readability/value_tags/`) is not copied yet. See `design/notes/value_tag_plan.md`, which is outside the repo.
