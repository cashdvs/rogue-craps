# Steam readiness

Dice of the Damned isn't shipping on Steam yet, but we build toward it. This is the checklist of
**technical** requirements, what the repo does today, and where each item lives. Store page, pricing,
ratings and the Steamworks partner setup are out of scope here.

Status key: **done** = in the repo and checked; **partial** = something exists but not enough for
Steam; **missing** = nothing yet. Each gap has an issue draft labelled `steam-ready`.

_Last checked against `main` at `fad5622` (Godot 4.7.2), 2026-10-19._

## Decisions (PM, 2026-10-19)

1. **Version:** `application/config/version` is set by hand (starting at `0.1.0`); CI appends the run number as the 4th part (`0.1.0.<run>`).
2. **Window size:** minimum 1280×720; 1280×800 (Steam Deck) must be supported ([#77](https://github.com/cashdvs/rogue-craps/issues/77), [#78](https://github.com/cashdvs/rogue-craps/issues/78)).
3. **Engine and templates:** pinned to Godot 4.7.2. Bump `GODOT_VERSION` in `ci.yml` and `export.yml` together.
4. **Packaging:** embedded PCK, one `.exe` (and one Linux binary).
5. **`user://` folder:** custom user dir `Tiny Anvil Games/Dice of the Damned`, set before any public build ([#75](https://github.com/cashdvs/rogue-craps/issues/75)).
6. **AI disclosure scope:** Cash's call (PM is taking it to him); the log rows stay as written until then ([#89](https://github.com/cashdvs/rogue-craps/issues/89)).


## Summary

| # | Item | Status | Where |
|---|---|---|---|
| 1 | Windows export preset | done | `export_presets.cfg` → `[preset.0]` "Windows Desktop" |
| 2 | Linux / Steam Deck export preset | done (Linux x86_64); Deck untested | `export_presets.cfg` → `[preset.1]` "Linux" |
| 3 | CI export job with a runnable artifact | done | `.github/workflows/export.yml` |
| 4 | Export templates in CI | done | `export.yml` (cached download of the 4.7.2 templates) |
| 5 | Version string | partial | `project.godot` `application/config/version`; stamped by CI; not shown in the UI |
| 6 | Save and settings location (`user://`) | partial | `scripts/settings/game_settings.gd` → `user://settings.cfg`; no run save; default Godot user dir |
| 7 | Resolution, window mode, fullscreen | partial | `project.godot [display]`; `GameSettings.fullscreen` / `vsync`; `scripts/ui/options_panel.gd` |
| 8 | Stretch settings and aspect ratios (16:9, 16:10 Deck, ultrawide) | partial | `project.godot [display] window/stretch/*` |
| 9 | Controller support (Steam Deck) | missing (menus partial) | no `[input]` section in `project.godot`; mouse/touch-only table and map |
| 10 | Pause on focus loss | missing | `scripts/ui/pause_menu.gd` has no `NOTIFICATION_APPLICATION_FOCUS_OUT` handling |
| 11 | Steam overlay | partial | Forward+ renders every frame; needs Steamworks init to appear |
| 12 | GodotSteam / Steamworks SDK hook | missing (designed) | planned `scripts/platform/steam_service.gd` autoload |
| 13 | Achievements, cloud saves | deferred | after 12 |
| 14 | Windows icon and version resources | partial | `export_presets.cfg` `application/*`; icon is on `main` since #71 (`assets/branding/studio/icon.png`) |
| 15 | Code signing | deferred (off) | `export_presets.cfg` `codesign/enable=false` |
| 16 | AI content disclosure (Steam content survey) | partial | [AI_CONTENT_LOG.md](AI_CONTENT_LOG.md); 5 rows still TBD |

## 1. Windows export preset: done

`export_presets.cfg` (project root), preset **"Windows Desktop"**:

- `export_path="build/windows/DiceOfTheDamned.exe"`; `build/` is in `.gitignore`.
- x86_64, `binary_format/embed_pck=true` (one `.exe`, no separate `.pck`), BPTC/S3TC textures.
- `application/company_name` and `product_name`: "Tiny Anvil Games" and "Dice of the Damned";
  `application/copyright="© 2026 Tiny Anvil Games"`. Windows has no separate publisher field in
  Godot; the company name is what Explorer shows.
- `application/file_version` and `product_version` are empty, so Godot uses
  `application/config/version` (checked: the exe reports `0.1.0.0`, or `0.1.0.<run>` from CI).
- `application/modify_resources=true` writes the icon and version resources natively (no rcedit needed in 4.7).
- `exclude_filter="tests/*, tools/*"`: tests and dev tools don't ship. Everything else is exported
  (the game loads from `art/`, `assets/`, `audio/` and `resources/` at runtime).
- `debug/export_console_wrapper=1`: a console wrapper only for debug exports.
- **No secrets**: `codesign/enable=false`. Godot 4 keeps the signing identity and password in
  `.godot/export_credentials.cfg` (git-ignored with `.godot/`), so they never appear in this file. No
  absolute paths. Check with `rg -i 'password|identity|keystore|/workspace|/home' export_presets.cfg`
  (no output).

Local check on the build box (2026-10-19): `godot --headless --export-release "Windows Desktop"`
produced a 108 MiB `DiceOfTheDamned.exe` with CompanyName, ProductName, FileVersion and LegalCopyright set.

## 2. Linux / Steam Deck preset: done (Deck untested)

Preset **"Linux"**, x86_64, `build/linux/DiceOfTheDamned.x86_64`, PCK embedded. The exported binary
runs the main scene headless for 900 frames with no script errors, and CI repeats that check.

Steam Deck: Steam runs the Windows build through Proton, or the native Linux build if we upload a
Linux depot. Neither has been tried on a Deck; see 8 and 9 for the gaps that matter there (1280×800,
controller-only input).

## 3. CI export job: done

`.github/workflows/export.yml` (separate from `ci.yml`, so the required `tests` check is unchanged).
Triggers: pushes to `main`, pull requests, `workflow_dispatch`.

Steps: install Godot exactly as `ci.yml` does (same cache key) → restore or download the export
templates → stamp the version → `--import` (fails on script errors) → `--export-release "Windows Desktop"`
→ `--export-release "Linux"` → smoke-run the exported Linux binary headless for 900 frames → upload
`DiceOfTheDamned-windows-<version>-<sha>` and `DiceOfTheDamned-linux-<version>-<sha>` with
`actions/upload-artifact@v4` (kept 14 days). Each artifact includes a `BUILD_INFO.txt` with the
version, commit and Godot version.

Not yet: an upload to Steam (SteamPipe `steamcmd` with a `ContentBuilder` depot script). That needs
the app id, depot ids and a builder account secret in GitHub. See issue "SteamPipe upload job".

## 4. Export templates in CI: done

Templates must match the engine build exactly (`4.7.2.stable`). CI downloads
`Godot_v4.7.2-stable_export_templates.tpz` (~1.3 GB) once, keeps only `version.txt` and the x86_64 Windows
and Linux templates (~360 MB) in `~/.local/share/godot/export_templates/4.7.2.stable/`, and caches that
folder under the key `godot-templates-4.7.2-stable-win64-linux64`. **Bumping Godot means bumping
`GODOT_VERSION` in both `ci.yml` and `export.yml` together.**

## 5. Version string: partial

- **Source of truth:** `project.godot` `application/config/version="0.1.0"` (added in this PR).
  Bump it by hand for releases (`x.y.z`).
- **CI stamp:** `export.yml` rewrites it in the runner's checkout to `x.y.z.<run number>` before
  exporting. Windows file and product versions must be numeric `a.b.c.d`, so the commit SHA goes into
  the artifact name and `BUILD_INFO.txt` instead. Nothing is committed.
- **Missing:** the version isn't shown anywhere in the game. It should be a small label on the title
  screen and in the pause menu (`ProjectSettings.get_setting("application/config/version")`), so bug
  reports carry it. The title screen belongs to Godot Dev.

## 6. Save and settings location: partial

- **Today:** `GameSettings` (autoload, `scripts/settings/game_settings.gd`) saves the options to
  `user://settings.cfg` (ConfigFile, section `options`): master, SFX and music volume, fullscreen,
  VSync, throw sensitivity, the Table 1 tutorial toggle and `tutorial_seen`.
  Missing or wrong-typed keys fall back to defaults.
- **Not saved:** run progress. A run lives in memory (`RunProgress` / the map scene); quitting
  mid-run loses it. Nothing else writes to disk (`FileAccess` is only used to read `res://` data).
- **Location:** `application/config/use_custom_user_dir` is off, so `user://` is Godot's default:
  `%APPDATA%\Godot\app_userdata\Dice of the Damned\` on Windows, and
  `~/.local/share/godot/app_userdata/Dice of the Damned/` on Linux and the Deck. For a shipped game
  it should be `%APPDATA%\Tiny Anvil Games\Dice of the Damned\` (custom user dir), decided **before**
  the first public build, because changing it later strands players' saves.
- **Cloud saves (deferred):** Steam Auto-Cloud can sync `user://` with no code if the save files
  sit in one folder with stable names. Keep settings and saves under the custom user dir and
  configure Auto-Cloud's root in Steamworks. That needs no GodotSteam call.

## 7. Resolution, window mode and fullscreen: partial

- `project.godot [display]`: the base viewport is 1920×1080, and the window opens at 1280×720
  (`window_width_override` / `window_height_override`).
- Options (`scripts/ui/options_panel.gd`, saved by `GameSettings`): **Fullscreen** on/off
  (`DisplayServer.WINDOW_MODE_FULLSCREEN`, hidden on mobile) and **VSync**.
- **Missing:** a windowed size or resolution choice, borderless versus exclusive fullscreen, a minimum
  window size (`DisplayServer.window_set_min_size`; nothing stops the window shrinking to nothing), a
  3D render scale (`rendering/scaling_3d/scale`) for the Deck and low-end GPUs, a frame cap
  (`Engine.max_fps`) and a UI scale. Alt+Enter isn't bound.

## 8. Stretch settings and aspect ratios: partial

`window/stretch/mode="canvas_items"`, `aspect="expand"`: the UI scales with the window, and other
aspect ratios get more room rather than black bars. That's the right setup for 16:10 (Steam Deck,
1280×800) and ultrawide. **Not verified:** that the HUD, map and shop fit at 1280×800 and 3440×1440,
and that the smallest text stays legible on the Deck's 7" screen.

## 9. Controller support (Steam Deck): missing, menus partial

- `project.godot` has **no `[input]` section**: there are no custom InputMap actions. Gameplay reads raw
  events: mouse and touch flick to throw (`table_3d.gd`, `bonfire_3d.gd`), `KEY_SPACE` / `KEY_ENTER`
  to throw again, `KEY_B` to bank, `KEY_ESCAPE` for the pause menu, and mouse clicks to pick dice and
  map nodes (`map_view.gd`).
- **Works today:** the title screen and pause menu call `grab_focus()` and use the built-in
  `ui_accept` / `ui_cancel` actions, which Godot maps to a gamepad's A/B buttons and D-pad, so they
  are navigable with a controller. The splash skips on a joypad button.
- **Missing:** InputMap actions for throw, bank, pick die, pause, confirm and back, bound to keyboard
  and gamepad; a controller throw (for example hold A and release, with stick aim and strength, or
  trigger pull strength); focus navigation in the run screen, map, shop, event and face picker (no
  `grab_focus` in `scripts/map/`); and controller button prompts. Until then the Deck needs a
  Steam Input "mouse + trackpad" layout, which caps the game at "Playable" rather than "Verified" in
  Steam's Deck compatibility review.

## 10. Pause on focus loss: missing

Nothing handles `NOTIFICATION_APPLICATION_FOCUS_OUT`. Alt-tabbing mid-throw keeps the physics and the
juice timers running. Plan: on focus out, open `PauseMenu` (bonfire table) and, if the option is on,
`get_tree().paused = true`; mute or duck the Master bus; add a `pause_on_focus_loss` option
(default on) to `GameSettings`. Steam overlay open (Shift+Tab) should do the same through GodotSteam's
`overlay_toggled` signal (12).

## 11. Steam overlay: partial

The overlay hooks the game's swap chain. Forward+ on Windows renders through Vulkan or D3D12
(`rendering/rendering_device/driver.windows`, not overridden in `project.godot`); the overlay supports both, and the game renders every
frame (`application/run/low_processor_mode` is off), which the overlay needs. The overlay only appears
when the game starts through Steam **and** the Steamworks API is initialised (12). Test it on a Steam
build before release, including on the Deck.

## 12. GodotSteam / Steamworks SDK hook: missing (designed here)

Plan, so nothing else in the game needs to know about Steam:

- Autoload **`SteamService`** (`scripts/platform/steam_service.gd`, Systems Dev). On `_ready` it
  checks `Engine.has_singleton("Steam")` (GodotSteam GDExtension present) **and** a configured app id.
  If either is missing, it sets `available = false` and every method no-ops (returns `false` or empty).
  The editor, CI, tests and non-Steam builds behave exactly as today.
- API sketch: `available`, `unlock_achievement(id: StringName)`, `set_stat(id, value)`,
  `store_stats()`, `is_overlay_open()`, `signal overlay_toggled(open: bool)`. `_process` calls
  `Steam.run_callbacks()` only when available.
- **App id is not committed.** Read it from the `SteamAppId` environment variable that Steam sets at
  launch, or from a git-ignored `steam_appid.txt` for local testing. Do not commit `steam_appid.txt`.
- GodotSteam ships as a GDExtension under `addons/godotsteam/` (pin a release built for Godot 4.7). It
  isn't added yet. Add it in its own PR when we have an app id, and check its licence (MIT) and the
  Steamworks SDK redistributable terms (`steam_api64.dll` / `libsteam_api.so` next to the exe).
- Export: add the redistributable libraries to each preset only once the addon lands.

## 13. Achievements and cloud saves: deferred

Achievements go through `SteamService.unlock_achievement` from game events (for example, clearing
Floor 3). Ids are defined in Steamworks, mirrored in a data Resource. Cloud saves: Steam Auto-Cloud on
the `user://` folder (6). Both wait for 12 and an app id.

## 14. Windows icon and version resources: partial

The preset leaves `application/icon` empty, so the exporter uses the project icon
(`application/config/icon`). That arrives with `chore/studio-branding` (`assets/branding/studio/icon.png`,
1024×1024). Until it merges, Windows builds show Godot's default icon. Version resources are done (1).

## 15. Code signing: deferred (off)

Steam doesn't require Authenticode, but unsigned builds trip SmartScreen when run outside Steam.
If we sign later, the certificate goes into GitHub secrets and `.godot/export_credentials.cfg` (or
`signtool` in CI), never into `export_presets.cfg`.

## 16. AI content disclosure: partial

Steam's content survey asks about AI-generated content that ships with the game. The record is
[AI_CONTENT_LOG.md](AI_CONTENT_LOG.md). Every PR that adds a shipped asset updates it. Five rows
(shaders, in-game text, and the concept renders, which don't ship) are still `TBD`, waiting on their owners.

## Index link

This file and `AI_CONTENT_LOG.md` are linked from [docs/README.md](README.md). The contributor docs PR
(#64) rewrites `README.md`, `CONTRIBUTING.md`, `docs/ARCHITECTURE.md` and `docs/DESIGN_INDEX.md`, so the
links from those files are added after #64 merges.
