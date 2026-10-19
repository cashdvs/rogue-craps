# AI content log

**Why this exists:** Steam's content survey (filled in on the Steamworks store page before release)
asks us to disclose AI-generated content that ships in the game, and to keep that disclosure true for
every update. This file is the record we answer it from.

**Rule:** every PR that adds or replaces a shipped asset (art, model, texture, shader, audio, font,
in-game text) adds or updates its row here, including when the answer is "not AI-generated". If you
don't know how an asset was made, write `TBD (ask <owner>)`; never guess a tool or a date.

**How to read the columns**
- **asset path**: a file or a glob in this repo (the export ships everything except `tests/` and `tools/`).
- **tool used**: what produced the shipped file, as stated in the cited source.
- **what it was used for**: what the tool did for that asset, then the source of the entry in brackets.
- **date**: when the asset landed on `main` (from `git log`): first commit, plus the last change if it differs.
- **owner**: who to ask. Art Director = 2D and branding, 3D Artist = models and textures,
  Sound Designer = audio, VFX Dev = FX textures and shaders, Game Designer = text.

> **Open question for PM / Cash (affects the survey answer, not this table):** "not AI-generated
> (procedural/script)" below means the shipped file was produced by a deterministic script or code,
> with no image, audio or text model involved. The scripts and code themselves were written by the
> team's AI agents (for example, the Bone d6 PR checklist in the Art Director's drafts says "AI agent
> wrote this"). Steamworks' Content Survey page says the AI section covers "content that ships with
> your game, and is consumed by players ... such as artwork, sound, narrative, localization", that
> "efficiency gains" from AI tools are "not the focus", and defines Pre-Generated as content "created
> with the help of AI tools during development". Steam's survey question also covers the store page,
> community assets and marketing materials. Whether AI-agent-written generator scripts and AI-written
> text count as "created with the help of AI tools" is Cash's call, not something this log can settle.
> Source: https://partner.steamgames.com/doc/gettingstarted/contentsurvey (checked 2026-10-19).

## Shipped content

| asset path | tool used | what it was used for | date | owner |
|---|---|---|---|---|
| `assets/branding/studio/anvil.png`, `hammer.png`, `spark.png`, `spark_particle.png` | Python: `assets/branding/studio/src/shapes.py` + `build.py` (hand-written SVG geometry, rendered with cairosvg/Pillow) | Studio splash layers. **Not AI-generated (procedural/script).** [assets/branding/studio/README.md, src/README.md] | 2026-10-18 | Art Director |
| `assets/branding/studio/wordmark_*.png` (6 files) | Python: `src/build.py`; Fredoka Bold (SIL OFL 1.1) shaped with HarfBuzz and outlined with fontTools | "TINY ANVIL" / "GAMES" wordmark layers. **Not AI-generated (procedural/script, real font).** The earlier AI concept renders of the logo are superseded and never ship (see the development-only table). [assets/branding/studio/README.md; art/concept/studio_logo.md] | 2026-10-18 | Art Director |
| `assets/branding/studio/icon.png` (arrives with `chore/studio-branding`, not on `main` yet) | Python: `src/build.py` | App icon (orange anvil and spark on a charcoal square). **Not AI-generated (procedural/script).** [assets/branding/studio/README.md "Logo files", src/README.md] | 2026-10-19 (branch) | Art Director |
| `fonts/AlfaSlabOne-Regular.ttf`, `fonts/BarlowCondensed-Bold.ttf`, `fonts/BarlowCondensed-SemiBold.ttf` | Third-party fonts (The Alfa Slab One Project Authors; The Barlow Project Authors), SIL OFL 1.1 | UI and HUD type. **Not AI-generated (third-party, licensed).** [fonts/OFL-alfaslabone.txt, fonts/OFL-barlowcondensed.txt] | 2026-10-18 | Art Director |
| `art/models/dice/bone_d6.glb` + its materials (`materials/bone_*.tres`, `die_ink_*.tres`) | Blender 4.5 LTS Python script `art/models/dice/src/build_dice.py` | The standard die model. **Not AI-generated (procedural/script)**; "no third-party assets, textures or fonts". [art/models/dice/README.md] | 2026-10-18 | 3D Artist |
| `art/models/dice/{mirror,twin_flame,wanderer,cracked,gilded,hellfire,bellows,blood_pact,coven,last_breath}_d6.glb` + `materials/*.tres` | Blender 4.5 LTS Python script `src/build_special_dice.py`; batch-2 materials and import mapping from `src/write_batch2.py` | Special dice models. **Not AI-generated (procedural/script).** [art/models/dice/SPECIAL_DICE.md, README.md] | 2026-10-18, last change 2026-10-19 | 3D Artist |
| `art/models/boards/infernal_pit/**` (`*.glb`, `materials/`, `scenes/`) | Blender 4.5 LTS Python script `src/build_board_a.py` | Board A table kit. **Not AI-generated (procedural/script)**; "no third-party meshes or textures". [art/models/boards/infernal_pit/README.md] | 2026-10-18 | 3D Artist |
| `art/models/boards/hearth/*.glb`, `materials/`, `scenes/` | Blender 4.5 LTS `src/build_hearth.py` + Godot script `src/make_hearth.gd` (wrapped by `src/rebuild_hearth.sh`) | Hearth board kit (brazier, candles, cauldron, demon faces). **Not AI-generated (procedural/script).** [art/models/boards/hearth/README.md] | 2026-10-18 | 3D Artist |
| `art/models/boards/hearth/textures/felt_ember_corners.png` | Python + Pillow: `src/make_felt_motif.py` | Felt corner ember motif overlay. **Not AI-generated (procedural/script).** [hearth/README.md; header of make_felt_motif.py] | 2026-10-18 | 3D Artist |
| `art/models/characters/smiles/**` (`smiles*.glb` incl. animation clips, `materials/`, `scenes/`) | Blender 4.5 LTS `src/build_smiles.py` + `src/make_smiles.gd`, `src/write_imports.py` | The dealer character, rig and clips. **Not AI-generated (procedural/script)**; "no third-party meshes, textures or fonts". [art/models/characters/smiles/README.md] | 2026-10-18, last change 2026-10-19 | 3D Artist |
| `art/models/boards/hearth/textures/flame_tongue_4x4.png`, `flame_tongue_4x4_mobile.png`, `smoke_curl.png` | Python + numpy + Pillow: `art/models/boards/hearth/src/make_flame_atlas.py` (deterministic) | Toon flame flipbook and smoke curl for the board fire. **Not AI-generated (procedural/script)**; the script calls itself a 'Procedural "hand-drawn" flame flipbook'. [header of make_flame_atlas.py; hearth/README.md] | 2026-10-18, last change 2026-10-19 | VFX Dev |
| `shaders/*.gdshader`, `shaders/3d/*.gdshader` (backdrop, bulb_light, felt, grade, fx_particle, fx_unshaded, outline, toon_noir) | TBD (ask VFX Dev) | Toon shading, ink outline, felt, post grade and FX particle shaders (from the file headers). How they were authored is TBD (ask VFX Dev). | 2026-10-18 | VFX Dev |
| `art/models/boards/hearth/shaders/*.gdshader`, `hearth_instance.gdshaderinc` | TBD (ask VFX Dev) | Hearth demon eyes, ember seam, coals, flame card, candle glow and sparks (from the file headers). How they were authored is TBD (ask VFX Dev). | 2026-10-18 | VFX Dev |
| `art/models/dice/shaders/toon_mirror.gdshader` | TBD (ask VFX Dev) | Mirror Die toon reflection (from the file header). How it was authored is TBD (ask VFX Dev). | 2026-10-18 | VFX Dev |
| `audio/sfx/*.wav` (all 59) | Godot synth classes in `scripts/audio/` (`SfxSynth`, `BonfireSynth`, `ThrowSynth`, ...) baked by `tools/bake_sfx.gd` (fixed seeds) | Every sound effect, crowd loop and stinger. **Not AI-generated (procedural/script)**: "No recordings, samples or third-party sounds are used". [audio/sfx/SOURCES.md; scripts/audio/README.md] | 2026-10-18, last change 2026-10-19 | Sound Designer |
| `resources/dealer/dealer_lines.json` and in-game UI/flavour text (`resources/**/*.tres` names and descriptions, strings in `scripts/`) | TBD (ask Game Designer) | Dealer taunts and player-facing text. No source in the repo says how it was written. | 2026-10-18, last change 2026-10-19 | Game Designer |

## Development-only AI use (does not ship)

Listed so the survey answer is complete. None of these files are in the repo or the build.

| asset path | tool used | what it was used for | date | owner |
|---|---|---|---|---|
| Concept renders listed in `/workspace/dice/art/concept/README_ASSETS.md` (team folder, outside the repo: key art, table mockups, dice sheets, boss dealers, studio logo concepts) | AI image generation ("the image tool", per README_ASSETS.md); the exact tool is TBD (ask Art Director) | Visual direction only. "All AI images are direction only"; the logo concepts are "superseded: never ship". [art/concept/style_guide.md, studio_logo.md, README_ASSETS.md] | TBD (ask Art Director) | Art Director |

## Not covered yet

- Assets that arrive in open PRs (for example the new GAMES wordmarks and timings in `chore/studio-branding`)
  add their rows in those PRs.
- Generated captures, previews and contact sheets outside the repo (for example `/workspace/dice/captures/`)
  don't ship and aren't listed.
