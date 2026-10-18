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
**Paths:** every script resolves paths relative to its own folder, so you can run it from any working directory (`python3 assets/branding/studio/src/build.py`).
- `build.py` writes into the studio folder above `src/`. That overwrites the committed layers, and also writes lockup, icon and SVG files that the repo doesn't track. Run it on a copy if you only want to compare.
- `splash_preview.py` reads `../splash_timings.json` and the layer PNGs.
- `previews.py` reads the repo's `fonts/BarlowCondensed-Bold.ttf` and writes contact sheets to `$PREVIEW_OUT` (default `<tmp>/tiny_anvil_previews/`).
