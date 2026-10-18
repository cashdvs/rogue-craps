# Studio logo build scripts (Art Director)

These are the Art Director's source scripts for every file in `assets/branding/studio/`. The art is hand-written SVG geometry, and the wordmark is Fredoka Bold converted to outlines, so the game never loads a font at runtime.

| Script | Generates |
|---|---|
| `shapes.py` | Shared geometry and palette (anvil, hammer, spark, icon shapes). Imported by the others. |
| `build.py` | All layer SVG/PNGs (`anvil`, `hammer`, `spark`, `spark_particle`, `wordmark_*`), lockups, icon, favicons, and `layers.json` (sizes and pivots). |
| `splash_preview.py <t> [t...]` | Still frames of the splash at the given times, rendered from `splash_timings.json` + the PNGs (written to `/tmp/splash_<t>.png`). |
| `previews.py` | Contact sheets (lockups on charcoal/cream, icon sizes, silhouette comparison) for review. |

**Requirements:** Python 3, Pillow, cairosvg, uharfbuzz, and fontTools.
**Font input (not committed):** `build.py` expects the variable `Fredoka.ttf` in this folder. Get it from Google Fonts or github.com/hafontia/Fredoka-One. Its license is `OFL.txt` here. On the first run the script instances it to `Fredoka-Bold-instance.ttf` (wght 700, wdth 100).
**Paths:** the scripts are committed unchanged from the Art Director's staging copy, so `OUT`/`D` still point at `/workspace/dice/art/branding/studio/` (and `previews.py` reads a Barlow font from `/workspace/dice/game/fonts/`). Edit those constants to build somewhere else, then copy the results here, keeping the same file names.
