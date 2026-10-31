# Architecture

How the code fits together, who owns what, and how to add content. Short on purpose: read the
`##` doc comment at the top of any script for the details. Paths are relative to the repo root.

## Glossary

- **Pot / bank:** after a throw you *pot* one combo from the lit dice; its points go into the hand's pot. *Bank* ends the hand and keeps the pot; banked points turn into Embers when the table ends. A bust loses the unbanked pot.
- **Bust:** a throw where nothing lights. You lose the hand's pot (and pending bounty ticks) and some Soul.
- **Hot Hand:** all 5 dice potted in one hand. You get every die back, and every later pot that hand gets +1 mult.
- **Kindling:** a face mod (Kindling Face). Potting a Kindling face means the next throw can't bust.
- **Seal:** a reward that levels a combo (each level adds base and mult to it). Rare Seals (Transference, Black, Ashen) are used on the spot.
- **Elite:** a harder Table node on the map that plays with one random **twist**.
- **Twist vs cheat:** both are table rules (`RunRuleData`). A *twist* is an Elite's rule (e.g. Cold Sixes, Short Table); a *cheat* is the boss's own rule, named after the boss (e.g. Madame Shuffle). On Floor 3 the boss also adds a twist.
- **Re-sit:** missing the boss doesn't end the run straight away; you get one re-sit (`RunData.boss_resits`) of the boss table.

## The big picture

```
studio_splash.tscn ──▶ title.tscn ──Play──▶ run.tscn (RunScreen)
                                              │  map ─▶ Event / Shop / Rest / Reward panels
                                              │  Table / Elite / Boss node:
                                              ▼
                                   bonfire.tscn (Bonfire3D, run mode)
                                     setup: TableSetup  ◀── MapRun.table_setup().to_table_setup()
                                     finished(TableOutcome) ──▶ MapRun.apply_outcome()
```

- **Rules are pure logic** (`RefCounted`, no nodes) in `scripts/core/`, so tests run headless.
  Scenes and views only show state and forward input.
- **Content is data:** Godot `Resource` classes in `scripts/data/`, saved as `.tres` in
  `resources/`. Designers tune `.tres` files without code.
- **Seeded randomness:** all game randomness goes through seeded RNGs (`DiceRoller`, or `MapRun`'s
  per-node seed `hash([run seed, floor, node, purpose])`), so a run replays exactly.
- `scenes/table.tscn`, `scenes/table_3d.tscn`, `scripts/table/` and the craps classes in
  `scripts/core/` (`craps_*`, `bet_*`, `bankroll`, `poc_*`) are the old craps proof of concept.
  `Bonfire3D` still extends `Table3D`; don't add new craps features.

## Module map

<a id="who-owns-what"></a>Labels are `module:<id>`; the claim process is in
[docs/MODULES.md](MODULES.md). This table lists today's files on `main`.

| Area | Owner | Main files |
|---|---|---|
| **Table and scoring** | Godot Dev | `scenes/bonfire.tscn`, `scripts/bonfire/` (`bonfire_3d.gd`, HUD, count-up, tutorial, juice adapter), `scripts/core/bonfire_run.gd`, `bonfire_scoring.gd`, `nonstd_dice.gd` (non-d6 rules: faces to 20, value <= 0 never scores, free rethrow, Wild cap, Caltrop / Knucklebone), `running_total.gd`, `table_goal_state.gd` (`TableGoalState`), `table_goal_strings.gd` (`TableGoalStrings`), `scripts/core/rules/` (twist, cheat and special-die handlers), `scripts/data/bonfire_*.gd`, `table_die.gd`, `table_setup.gd`, `table_outcome.gd`, `resources/tuning/bonfire_tuning.tres`, `resources/bonfire/`. A table passes when its banked points reach `TableGoal.target` (table_goals_v1; targets in `FloorData`, a miss costs `miss_soul`; target 0 = the old bounty rule, used by the standalone table). Points pay Embers only through `BonfireRun.points_to_embers(tuning, points)` (1 per `points_per_ember`, capped at `BonfireTuning.points_embers_cap` per table); the payout and the HUD preview both use it. |
| **Dice physics and throw** | Godot Dev | `scenes/table_3d.tscn`, `scripts/table3d/` (`table_3d.gd`, `dice_sim.gd` with its base `dice_sim_bodies.gd` (bodies, colliders, coin and hull-die felt rules), `throw_recording.gd`, `die_visual.gd` with its base `die_face_art.gd` (meshes, pips, blank faces, numerals), `camera_rig.gd`, ...), `scripts/core/dice_roller.gd`, `throw_gesture.gd` |
| **Non-d6 dice** (coin, d4-d20, talus, Powder Keg barrel) | Godot Dev | `scripts/table3d/coin_physics.gd` (Ferryman's Coin: 72-point procedural hull, edge rule, face read), `poly_die.gd` (`PolyDie`: hull colliders, face / vertex read, seeded remap for d4, d8, d10, d12, d20, talus, keg), `die_hull_data.gd` (generated hull points and face directions; don't edit by hand), `tools/gen_die_hulls.gd` (regenerates it from `art/models/dice/*_mobile.glb` and `batch3_faces.json`), `tools/capture_coin_flip.gd` (10-flip video and stills); tests `test_coin_flip.gd`, `test_odd_dice_settle.gd`, `test_die_hull_extent.gd`, `test_table_die_shape.gd` |
| **Title, splash, settings, pause** | Godot Dev | `scenes/title.tscn`, `scripts/title/`, `scenes/studio_splash.tscn`, `scripts/splash/`, `scripts/settings/`, `scripts/ui/` |
| **Run** (Soul, Embers, dice bag, Seals) | Systems Dev | `scripts/core/run/` (`run_progress.gd`, `run_die.gd`), `scripts/data/run_data.gd`, `resources/map/bonfire_run.tres` |
| **Map, shop, events, rewards, rest** | Systems Dev | `scripts/core/map/` (`map_run.gd` with its bases `map_run_state.gd` and `map_run_shop.gd`, `map_generator.gd`, `run_map.gd`, `event_applier.gd`, `event_picker.gd` (which event a node shows: floors, skip, Rest fallback), `run_table_setup.gd`), `scripts/map/` (`run_screen.gd`, `shop/` (the shop counter UI: `ShopScreen`, `ShopItem`, `ShopOffer`, `PriceTag`, `EmberPrice`, `ShopCard` (the item info card; a rare `DieShape` with `risky` also shows the red `RARE_V2_RISK_TAG` "Risk" line), `ShopSideCard` (sell and reroll cards), `BagSlot` (one die in the YOUR DICE row; Sell / Swap lifts the row into sell mode), `RareMarks` (RARE chip and rare-die plinth, from `offer.rare`)), `map_view.gd`, `event_view.gd`, `face_picker.gd`), `scripts/data/economy_strings.gd` (`EconomyStrings`: economy UI strings from strings_v1), `scripts/data/shop_card_strings.gd` (`ShopCardStrings`: the 23 "Shop card" strings from strings_v1 (shop_card_* plus shop_hint_pick_sell), spec design/shop_cards_v1.md), `scenes/run.tscn`, `scripts/data/{floor,map_gen,event*,bounty,table_goal,run_rule}_data.gd`, `resources/map/`, `resources/events/`. Event effect kinds now include `MAX_SOUL`, `GIVE_DIE`, `SELL_DIE`, `FREE_SHOP_REROLL` and `NEXT_TABLE_TWIST`; `EventData.floors` limits an event to the floors it lists (empty = any). Economy v1 fields on `RunData` (`resources/map/bonfire_run.tres`): `max_dice` (6), `shop_soul_amount` / `shop_soul_price` / `shop_soul_step` (Soul Draught), `shop_premium_rare_price` (the rare Seal slot, drawn last; 0 = off), `shop_floor_price_percent` (per-floor shop markup), `shop_seal_step`, `reroll_step`. |
| **Dice, face mods, boss/Elite rule data** | Systems Dev | `scripts/data/dice_ids.gd` (canonical die and shape ids; table in [DICE_IDS.md](DICE_IDS.md)), `scripts/data/special_die_data.gd`, `face_mod_data.gd`, `resources/dice/`, `resources/mods/`, `resources/map/rules/` (the *data*; the table enforces it) |
| **FX** (listeners on `table.events`) | VFX Dev | `scripts/fx/` (in flight), `scripts/table3d/fx_3d.gd`, `shaders/3d/fx_*` |
| **Audio** | Sound Designer | `scripts/audio/`, `audio/sfx/`, `tools/bake_sfx.gd` |
| **Art pipeline** | Art Director (look, sign-off), 3D Artist (meshes) | `art/models/`, `*.import` for art, `fonts/`, `assets/branding/` |
| **Soul Reliquary** (3D Soul meter on the Hearth rail) | 3D Artist (meshes, look), Art Director (sign-off) | `art/models/props/soul_reliquary/` (`scripts/soul_reliquary.gd`: `SoulReliquary.set_soul(cur, max)` clamps to 0..max, liquid, frost, lethal crack, cage growth, `plate_layout` row/stacked; generator `src/make_soul_reliquary.gd` + `reliquary_stacked.gd`, `reliquary_mb.gd`), anchors `SoulReliquary` / `SoulReliquaryPhone` in `art/models/boards/hearth/`, candle progress in `art/models/boards/hearth/scripts/hearth_fx.gd` (`candles_lit_for`); `tests/test_soul_reliquary.gd` |
| **Build version** | PM (Tools / CI) | `version.cfg` (the one source: `major_minor`, `patch`, `sha`), `scripts/core/version.gd` (`Version`: `display()`, `tag()`, `file_stem()`, `bug_subject()`, `code()`, corner `make_label()` on the title and pause screens), `tools/stamp_version.sh` (export-time stamp); `tests/test_version.gd`. See [Build version](#build-version). |
| **Review and QA tests** | QA Tester | `tests/qa_/`, PR review and merges |
| **CI, contributor docs** | PM | `.github/`, `run_tests.sh`, `project.godot`, `*.md` at the root, `docs/` |
| **Tools** | shared (Godot Dev / Systems Dev; per-tool owners in the sections below, e.g. `tools/bake_sfx.gd` is Sound Designer's) | `tools/` |
| **Design and numbers** | Game Designer | design docs ([DESIGN_INDEX.md](DESIGN_INDEX.md)); every tuning number in `.tres` |

Tests for an area live next to it in `tests/test_<area>*.gd` (e.g. `test_map_run.gd`,
`test_events.gd`, `test_special_dice.gd`, `test_bonfire_scoring.gd`).

## Key signals and hand-offs

| Signal / call | Where | What it means |
|---|---|---|
| `Bonfire3D.setup` (a `TableSetup`) | set by `RunScreen._play_table()` before `add_child` | everything the table needs: dice as `TableDie`, `TableGoal`, Soul, leveled `BonfireTuning`, seed, rules |
| `Bonfire3D.finished(outcome: TableOutcome)` | `scripts/bonfire/bonfire_3d.gd` | fires once when the table ends; the only way a table reports back (cleared, Soul, Embers, bounties, banked combos, shattered dice) |
| `Bonfire3D.throw_resolved(faces, lit)`, `hand_result(result)` | same | per-throw and per-hand results, for HUD and tests |
| `BonfireRun.table_event(event, data)` | `scripts/core/bonfire_run.gd` | today's hook for juice and audio: `hand_start`, `throw_landed`, `pot`, `bank`, `bust`, `die_shattered`, `kindling_saved`, `table_cleared` (the clearing bank; the table stays open until Leave), `table_end`. Being replaced by `table.events` (`scripts/bonfire/table_events.gd`, readability PR) |
| `BonfireRun.can_join(i)` | `scripts/core/bonfire_run.gd` | read-only: true when die `i` of the current throw is not potted and would still make a legal pot with the potted dice (`BonfireScoring.can_extend(potted + [i])`, the same check `toggle()` uses). With nothing potted this means "die `i` lights". False outside PICK or out of range. It changes no run state. |
| `NerveState` (`can_nudge`, `can_nudge_dir`, `nudge`, `undo`, `commit`, `mark_potted`, `uses_left`, `grant_use` / `clear_granted` (a Barrel Boom's +1 use this hand), `ui_state`, `rescue_options` / `any_nudge_lights`) | `scripts/core/nerve_state.gd` (Systems Dev; pure logic, `tests/test_nerve.gd`) | Nerve (`design/nerve_v1.md`): once per table, turn one unpotted die from this throw to the adjacent value on its face list (no wrap; Coin and Mirror excluded; repeated values auto-pick via `score_fn`). The table builds it from `TableSetup.nerve_uses`, calls `begin_throw` when a throw settles and `reset_table` for each table or boss re-sit, and re-runs copies and the lit check after a nudge. Never costs Soul or Embers |
| `table.events.nerve_spent(die_id, from_face, to_face)` | `scripts/bonfire/table_events.gd`, emitted only by `NerveTable._commit()` (`scripts/bonfire/nerve_table.gd`; `tests/test_nerve_spent.gd`) | a pending Nerve nudge was kept for good: `NerveState.commit()` spent it on a pot (`on_potted`, also a rescue-save) or a rethrow / bank (`close_throw`). Faces are 1-based face slots, like `die_nudged`. Once per spent nudge; never on undo, a refused nudge or a commit with nothing pending |
| `RareDiceRules` (`on_land`, `attach_nerve`, `pot_factor`, `soft_soul_loss`; Fuse Boom/Misfire, Hex Soul, Jackpot Ember, Usurer bust Soul) | `scripts/core/rules/rare_dice_rules.gd` (Systems Dev; `tests/test_rare_dice_v2_effects.gd`) | the rare dice's table rules (`design/rare_dice_v2.md`), installed from `DieShape.table_special` via `TableRules.DIE_SCRIPTS`. `BonfireRun.land_throw` calls `on_land` once on the landed faces (never on Nerve nudges); the table (`Bonfire3D`, right after `set_rules`) passes its `NerveState` with `attach_nerve`. `LIGHTS_ALONE` / `lights_alone(mod_id)`: a lone die with that mod (Fuse) scores as a Single in `BonfireScoring.score_selection` (`_single`; so it never busts; off under no_mods, and Cold Sixes still keeps it dark) |
| `TableGoalState.watch(source, other = null)` | `scripts/core/table_goal_state.gd` | read-only view of a table's goal for the Target HUD plate (table_goals_v1). Each argument is a `BonfireRun` or a `MapRun`, either order: `watch(run)`, `watch(map_run)` or both. Fields `target`, `banked`, `hands_left`, `is_boss`, `seals`, `bounties` ([] until PR2), `debuff` (null until PR3); signals `target_changed`, `banked_changed`, `hands_left_changed`, `seals_changed`, `debuff_changed`, then `changed`. Follows `hand_finished`, `table_event`, `screen_changed`. Tests only: `set_for_test(target, banked, hands_left, debuff, seals, is_boss)` |
| `TableGoalStrings` | `scripts/core/table_goal_strings.gd` | the strings_v1 target, progress and table-preview lines (`target()`, `progress()`, `line(run)`, `preview()`, `num()`); the HUD plates and `RunScreen` preview use it |
| `MapRun.screen_changed(screen)` | `scripts/core/map/map_run.gd` | `MAP`, `TABLE`, `EVENT`, `SHOP`, `REST`, `REWARD`, `RUN_WON`, `RUN_OVER`; `RunScreen.refresh()` redraws |
| `RunProgress.changed`, `run_ended` | `scripts/core/run/run_progress.gd` | Soul, Embers, dice or Seals changed; Soul hit 0 |
| `MapView.node_pressed(id)`, `EventView.choice_made(i, picks)` | `scripts/map/` | UI → `MapRun.choose_node()` / `choose_event()` |
| `TableSetup.run_embers` | `scripts/data/table_setup.gd`, set from `RunTableSetup.run_embers` (`MapRun.table_setup()`: `progress.embers`) | run mode: the run's Embers before this table. The HUD shows it plus the table's payout ("EMBERS n"); `TableOutcome.embers` stays the payout only |
| `RunSeals` (`seal_level`, `add_seal_levels`, `seal_bonus`, `record_bank(s)`, `most_banked`, `transference`; `changed`) | `scripts/core/run/run_seals.gd` (base of `RunProgress`) | Seal levels per combo, the rare Seals' moves (Transference, Black, Ashen) and the combos banked this run |
| `RunSummary.title(run)`, `reason_line(run)`, `lines(run)` | `scripts/core/map/run_summary.gd` | run end screens: the real reason the run ended (`MapRun.end_reason`) and a short summary (floor reached, tables cleared, Embers earned, final bag, seed) |
| `RunProfile.map_key_seen()`, `mark_map_key_seen()`, `file_path()` | `scripts/core/run/run_profile.gd` | per-profile flags that outlive a run (for now: the map key has opened by itself once), saved to `user://profile.cfg`; tests set `path` to a scratch file (`tests/support/profile_guard.gd`), and `--script` runs without a `path` write no file |
| `DieCardInfo.from_run(progress, i)`, `mod_name()` | `scripts/ui/die_card_info.gd` | plain data for one die card: name, ability line, shape, every face (value, mod id, mod name) and, in pick mode, the next mod's price. The table can fill one from a `TableDie` |
| `DieCard.create(info, read_only)`, `set_die(...)`; `face_picked(face_index)` | `scripts/ui/die_card.gd` | one die's card built in code: "name - ability", the next mod's price, one button per face with "Face n: mod" tooltips. Read-only cards disable every face; otherwise `allowed` decides which faces can be picked |
| `DicePanel.build(progress, opts)`, `seal_lines()`; `picked(Vector2i(die, face))` | `scripts/map/dice_panel.gd` | the "Your dice" view: a `DieCard` per die plus the "Your Seals" strip. Read-only from the map; in pick mode (shop, Rest carve, events) it replaces the old face picker |
| `TablePreview.boss_rules(run)`, `dice_row(progress, on_open)`, `add_boss_sign(...)` | `scripts/map/table_preview.gd` | pieces of `RunScreen`'s table preview, split out to keep `run_screen.gd` small: the boss rule line, the mini dice row and the boss intro sign |
| `BossSign.make_sign(r, ...)`, `update_hand_pill(sign, r)`; `RunRuleData.hand_pill_text()`, `sign_tooltip()`, `sign_alt()` | `scripts/map/boss_sign.gd`, `scripts/data/run_rule_data.gd` | boss sign art is text-baked except hand changes: with `sign_hand_pill` (Baron Vig) the "%+d HAND" brass pill is a Label over the pill-free art, hidden at `hands_delta` 0; tooltip and alt text append the hands part from `hands_delta` (#136) |
| `MapKey.all_lines()` | `scripts/map/map_key.gd` | the map key: one line per node type plus the path and re-sit rules, docked on the map's right edge. Opens by itself on a profile's first map (`RunProfile`), collapsed from Floor 2 on; the Key button or K toggles it |
| `MiniDiceRow.build(progress)`, `tile_text()`; `opened` | `scripts/map/mini_dice_row.gd` | the table preview's mini dice row: one tile per die in table order under "Your dice · n/max"; any tile opens the read-only `DicePanel` |

## The run, map and shop (Systems Dev)

- **`MapRun`** drives a run: `choose_node(id)` moves on the map and opens that node's screen;
  `table_setup()` builds a `RunTableSetup` for Table/Elite/Boss; `apply_outcome(TableOutcome)`
  books Soul and Embers, removes shattered dice, then goes to the Seal **Reward** (cleared), back
  to the **Map** (missed), a boss **re-sit** (`RunData.boss_resits`) or **Run over**. Beating a
  boss pays `boss_embers` and a contract piece; the last boss wins the run.
- **`RunProgress`** holds run state: Soul and max Soul, Embers, the dice bag (`RunDie`: optional
  special id + one face-mod id per face), Seal levels and banked-combo counts.
  `table_dice()` turns the bag into `TableDie`s (special faces and weights, mods, Heavy weights).
- **`MapGenerator`** builds each floor from `MapGenData` (rows, lanes, node weights);
  `RunMap` tracks where you are. Elites draw a twist from `FloorData.elite_twists`; each floor
  draws its boss from `boss_cheats` on entry.
- **Shop** (`MapRun._roll_shop`, `buy_die`, `buy_mod`, `buy_seal`, `shop_reroll`, `sell_die`):
  offers come from `RunData.special_dice`, `face_mods` and the Seal combos; counts and prices
  are in `RunData` ("Shop" group). Face mods cost `mod_price_step_percent` more per mod already
  on that die (pre-carved preset faces don't count). **Rare dice** (design/rare_dice_v1.md):
  `DieShape`s with `rarity = &"rare"` (`pyre`, `gilt`, `lodestone`, `ossuary`) never enter the
  common or Elite pools; each shop rolls `RunData.shop_rare_die_chance[floor]` (`_rare_offer`,
  own seed) and on a hit the second dice slot becomes an unowned rare. Their pre-carved faces are
  locked (`RunProgress.face_locked`; `set_face` refuses; event remove-mod uses `removable_faces`/`has_removable_mod`, which skip them). **Rest**: heal, carve a free mod, or level a Seal. **Events**: `EventApplier`
  checks and applies each choice's effects.
- **Shop counter UI** (`scripts/map/shop/`, shop redesign PR A, HANDOFF_SPEC in
  `art/concept/shop_redesign/`). It is display only, and buying still goes through `MapRun`:
  - `ShopOffer`: plain data for one counter item (die, mod, Seal, rare Seal or Soul Draught),
    read from `MapRun`. It holds the price (or the `lo-hi` range for mods), the art key
    (`DiceIds.body_key` for dice) and `rare`. `affordable(embers)` checks the price, and
    `buy(screen)` calls the matching `MapRun` buy, or the face picker for mods and Seals. It
    does nothing when the item is unaffordable.
  - `ShopItem`: the icon above a `PriceTag`. A click emits `buy`, and hovering emits
    `focus_item` for the shop card.
  - `PriceTag`: a brass-bordered plate. Its numerals turn red #FF2E3E when the player can't
    afford the item, and the `-` tag is grey #8A8478.
  - `EmberPrice`: the reusable ember coin plus number (a #C8783C coin about 0.8x cap height,
    centred on the digits, with a 4 spec px gap). It is used by tags and the Embers total.
  - `ShopScreen`: the header, the Embers total, the wood counter with felt shelves, and
    Reroll / Sell / Leave. `LAYOUTS` picks PC, landscape or portrait from the window shape,
    and sizes are spec px times `k`.
  (for selling, until the bag row lands) in place of the counter. Back clears it, and
  `refresh()` clears it whenever the screen is not the shop, so the next shop opens on the
  counter. The top bar (`_bar`) is hidden on the shop screen.
- **`RunScreen`** (`scenes/run.tscn`) only displays `MapRun` and forwards clicks. Its
  "Stub: clear / miss" buttons show only with `debug_table_stubs` on in a debug build.

## Data files

| File | Class | Holds |
|---|---|---|
| `resources/map/bonfire_run.tres` | `RunData` | the run: floors, Soul, handful size, pools (`events`, `special_dice`, `face_mods`), Seal steps, rewards, shop and rest numbers, `nerve_uses` (Nerve per table; `MapRun.table_setup()` -> `RunTableSetup` -> `TableSetup.nerve_uses`) |
| `resources/map/floor_1..3.tres` | `FloorData` | per floor: map rules, bounty pools and counts, hands, clear Embers, Elite twists, boss pool and boss bounties/hands |
| `resources/map/floor_1_map.tres` | `MapGenData` | map shape and node weights |
| `resources/map/rules/*.tres` | `RunRuleData` | Elite twists (`kind` TWIST) and boss cheats (`kind` CHEAT): name, text, `hands_delta`, `bust_soul_loss`, `params` |
| `resources/dice/special/*.tres` | `SpecialDieData` | special dice: id, name, text, price, faces, weights |
| `resources/mods/*.tres` | `FaceModData` | face mods: effect, numbers, Soul cost, price, curse flag |
| `resources/events/*.tres` | `EventData` | events: title, body, art note, 2-3 choices (`EventChoiceData` → `EventEffectData`) |
| `resources/tuning/bonfire_tuning.tres` | `BonfireTuning` | table numbers: combos, Soul, bust cost, juice timings (Godot Dev / Game Designer) |

Numbers in these files come from the Game Designer. Changing an existing one is a balance change
(PM decides, [CONTRIBUTING.md §5](../CONTRIBUTING.md)). Add new files in the Godot editor
(right-click the folder → New Resource → pick the class) so `.tres` and `.uid` stay valid.

**Shipping and Steam:** builds come from `export_presets.cfg` and `.github/workflows/export.yml`;
status and open items are in [STEAM_READINESS.md](STEAM_READINESS.md).

<a id="build-version"></a>**Build version:** `version.cfg` holds the version (`0.1.<patch>`) and is
the only place to bump it. `Version` (`scripts/core/version.gd`) reads it: `display()` gives
`v0.1.2 (abc1234)` (`(dev)` when not stamped), `tag()` gives `beta-0.1.2`, `file_stem()` gives
`DiceOfTheDamned-0.1.2` and `bug_subject()` gives `Bug report - v0.1.2 (abc1234)`. The Android
versionCode is `major*10000 + minor*100 + patch` (0.1.2 = 102), so it always grows.
`tools/stamp_version.sh` wraps an export. It writes the short sha into `version.cfg` (`--no-sha`
keeps `dev`), copies the version into the Android/Windows presets and `project.godot`, and prints
the export names (`DiceOfTheDamned-0.1.2-Windows.zip`, `-Android.apk`). Run exports through it: `tools/stamp_version.sh [--no-sha] -- <export command...>` stamps the 3 tracked files (`version.cfg`, `export_presets.cfg`, `project.godot`), runs the export, and restores the 3 files from a backup via `trap ... EXIT`, so the tree is clean again whether the export succeeds or fails (the script exits with the export's status). `--stamp-only` leaves the files stamped and is meant only for a throwaway copy or CI checkout. Anything players see or hear
that you add gets a row in [AI_CONTENT_LOG.md](AI_CONTENT_LOG.md).

## Recipes

### Add a special die
1. Create `resources/dice/special/<id>.tres` (`SpecialDieData`): `id`, `display_name`,
   `description`, `price`, `faces` (default 1-6) and optional `weights`.
2. Add it to `special_dice` in `resources/map/bonfire_run.tres`. Shops and Elite rewards now
   offer it, and `RunProgress.table_dice()` hands it to the table as a `TableDie` with
   `special = <id>`.
3. Its **ability** is table code (Godot Dev): a `TableRule` handler registered in
   `TableRules.DIE_SCRIPTS` + `DIE_INFO` (`scripts/core/rules/table_rules.gd`), or a case in
   `BonfireScoring`. Without one it plays as a plain die, so agree the split first.
4. Model: see the art pipeline below. Test: extend `tests/test_special_dice.gd`.

### Add a face mod
1. Create `resources/mods/<id>.tres` (`FaceModData`): pick an existing `effect`
   (`MULT_FACTOR`, `WILD`, `TWIN`, `BLANK`, `MULT_ADD`, `EMBER`, `HEAVY`, `STEP`, `STAIR`,
   `KINDLING`), set its numbers (`mult_factor`, `amount`, `soul_cost`) and `price`.
2. Add it to `face_mods` in `bonfire_run.tres` (Shop and Rest offer it).
3. A **new kind of effect** needs a new `FaceModData.Effect` value plus scoring in
   `BonfireScoring` (Godot Dev). `HEAVY` is the one run-side effect (a roll weight set in
   `RunProgress.table_dice()`).
4. Test: `tests/test_bonfire_face_mods.gd` (scoring) and `tests/test_map_run.gd` (shop).

### Add an event
1. Create `resources/events/<id>.tres` (`EventData`): `title`, `body`, `art_note` (shown on a
   placeholder panel until `art` is set) and 2-3 `EventChoiceData` sub-resources.
2. Each choice has a `label`, `result_text`, optional `requires_face_mod`, and a list of
   `EventEffectData`: `SOUL` / `EMBERS` (`amount`, negative = cost), `ADD_FACE_MOD` (`mod`,
   `target` PICKED / RANDOM_OTHER_SAME_DIE / RANDOM), `REMOVE_FACE_MOD`, `SEAL_LEVEL`
   (`seal`, `amount`). Choices you can't afford are greyed out (`EventApplier.why_not`).
3. Add it to `events` in `bonfire_run.tres`. A new effect kind needs `EventEffectData.Kind` and
   `EventApplier` changes. Test: `tests/test_events.gd`.

### Add a boss (or an Elite twist)
1. Create `resources/map/rules/<id>.tres` (`RunRuleData`): `id`, `display_name`, `description`,
   `kind` = CHEAT (boss) or TWIST (Elite), `params` (e.g. `{"face": 6}`), and optionally
   `hands_delta` / `bust_soul_loss`, which the run applies itself.
2. Add it to `boss_cheats` (or `elite_twists`) in the floor's `floor_N.tres`. Boss table size is
   `boss_bounties`, `boss_min_bounties` / `boss_max_bounties` and `boss_hands` there.
3. The table finds the handler by `id` in `TableRules.SCRIPTS` (+ `INFO`). To reuse an existing
   handler, use its `id` with your own `display_name` / `description`. A new behavior is a new
   `TableRule` subclass in `scripts/core/rules/` (Godot Dev). Unknown ids show as labels only.
4. Test: `tests/test_map_run.gd` (the run picks it) and `tests/test_bonfire_rules.gd` (the rule).
5. Dealer art (optional): add `art/models/characters/bosses/<folder>/scenes/<folder>.tscn` (+ `_mobile.tscn`)
   and map the cheat `id` to `<folder>` in `BonfireDealerArt.BOSS_ART`. Without it the table keeps Smiles.


<!-- SECTION: Godot Dev — table & scoring (owner text; replace freely) -->
## The table and scoring (owner: Godot Dev)

- **Scenes:** `scenes/bonfire.tscn` is the playable table (CI smoke-tests it). `scenes/table_3d.tscn` is the bare 3D table it builds on.
- **Bonfire3D** (`scripts/bonfire/bonfire_3d.gd`, extends `Table3D`) runs a table. The run fills in `setup` (a TableSetup with the hand of dice as `TableDie`, goal, Soul, tuning, seed and rules) before `add_child`. Without a setup it opens as the sandbox.
  - Main calls: `throw(velocity, release_pos)`, `pick_die(i)`, `bank()`, `throw_again()`, `leave()` / `can_leave_now()`, `forfeit()`, `outcome()`. For tests: `new_run(seed)`, `rig_faces()`, `rig_slots()`.
  - Signals: `throw_resolved(faces, lit)`, `hand_result(result)`, `throw_measured(...)` (debug), `refused(index)`, and `finished(outcome: TableOutcome)`. `finished` fires exactly once, and it's the only way a table talks back to the run.
  - Effects and sound listen to `table.events` (`scripts/bonfire/table_events.gd`, coming in the readability PR) and never call into table logic. VFX Dev owns those listeners in `scripts/fx/`.
- **File layers (#128):** `Bonfire3D`, `BonfireHud` and `BonfireRun` are each a chain of short files. Each file `extends` the one before it, and only the last class is ever created. A lower layer calls functions written higher up through `@abstract func` declarations. Variables, constants and signals sit in the bottom layer.

  | File | Class | Holds |
  |---|---|---|
  | `scripts/bonfire/bonfire_table_state.gd` | `BonfireTableState` (extends `Table3D`) | the table's signals, constants, variables and read-only questions |
  | `scripts/bonfire/bonfire_table_look.gd` | `BonfireTableLook` | **art seam**: `table_die()`, `apply_die_look()` (the `set_look` call), face-mod decals, lit / cold looks |
  | `scripts/bonfire/bonfire_table_layout.gd` | `BonfireTableLayout` | camera, phone / landscape fit, pot and hand positions, screen picking |
  | `scripts/bonfire/bonfire_throw_flow.gd` | `BonfireThrowFlow` | one throw: launch, settle, rule triggers, face changes, bust |
  | `scripts/bonfire/bonfire_pot_bank.gd` | `BonfirePotBank` (`Bonfire3D` extends it) | pot, throw again, bank and count-up, Hot Hand, Nerve glue |
  | `scripts/bonfire/help_corner.gd` | `HelpCorner` (child of `Bonfire3D`, made in `_ready`) | first-table controls text: fades 30 s after the first pot or on the first Bank, stays off on later tables; F1 / ? card with the Replay-tutorial link (`settings` can be swapped for a stub in tests) |
  | `scripts/bonfire/bonfire_hud_build.gd` | `BonfireHudBuild` (extends `Control`) | HUD variables; builds the labels, buttons and panels |
  | `scripts/bonfire/bonfire_hud_goal.gd` | `BonfireHudGoal` (`BonfireHud` extends it) | goal / bounty readout, meters, stamps, UI scale |
  | `scripts/bonfire/target_plate.gd` | `TargetPlate` (extends `PanelContainer`) | Target HUD v2.1 plate: target, banked bar, hands/passed line, bounty chips; redraws on `TableGoalState.changed` |
  | `scripts/bonfire/target_place.gd` | `TargetPlace` (static) | where the plate and SEALS chip sit on PC, phone landscape and portrait; `goal_rect(hud)` for blockers |
  | `scripts/bonfire/goal_icon.gd` | `GoalIcon` (extends `Control`) | drawn diamond / list / skull icons for the plate's chips |
  | `scripts/bonfire/table_goal_state.gd` | `TableGoalState` (stub) | temporary goal-state stub until Systems Dev's `scripts/core` version lands, then deleted |
  | `scripts/bonfire/bonfire_juice_sound.gd` | `BonfireJuiceSound` (`BonfireJuice` extends it) | the juice adapter's constants, variables, hook log and every sound (SfxManager events with fallbacks, crowd layers) |
  | `scripts/core/bonfire_run_state.gd` | `BonfireRunState` (`BonfireRun` extends it) | a table's rule state, rule hooks and read-only questions; `BonfireRun` keeps the actions |

  Timers: `Table3D._timer()` and `BonfireJuice` (through `ExitTimers`, `scripts/bonfire/exit_timers.gd`) unhook their pending timers in `_exit_tree()`, so nothing wakes up on a table that has been removed. A hit-stop or slow-mo that is cut short is undone.
- **Rules:**
  - `scripts/core/bonfire_run.gd` holds one table's state: hands, the pot, banked points, Soul and Hot Hand.
  - `scripts/core/bonfire_scoring.gd` (`BonfireScoring`) is pure static functions. `match_combo()` finds the combo and `score_selection()` returns (base + faces) × mult.
  - Twists, boss cheats and special dice are `TableRule` handlers in `scripts/core/rules/`.
  - All numbers live in `resources/tuning/bonfire_tuning.tres` (`BonfireTuning`). Don't hard-code them.
- **Throw and physics:**
  - The flick speed (px/s, timed in real time) is mapped through a launch curve to a speed, lift and spin (`launch_for()`).
  - `scripts/table3d/dice_sim.gd` runs real Jolt rigid bodies. The outcome is seeded: the faces are rolled first and the dice are rotated before the throw so they land on them. A settle assist nudges stragglers after 1.2 s.
  - `die_visual.gd` reads which face is up and draws the lit and cold looks.
- **Ask Godot Dev before touching:** `bonfire_3d.gd`, `table_3d.gd`, `dice_sim.gd`, `die_visual.gd`, `bonfire_run.gd`, `bonfire_scoring.gd`, `scripts/core/rules/`, and `bonfire_tuning.tres`. The Game Designer sets those numbers.
- **Testing table changes:**
  - Run `./run_tests.sh` (headless Godot 4.7, all `tests/test_*.gd` plus QA's `tests/qa_/`). `tests/qa_/` is QA's: you may add checks, but never loosen, skip or delete an existing one.
  - Table tests are `tests/test_bonfire_*.gd`, `test_table_3d.gd` and `test_leave_table.gd`. Use `new_run(seed)` and `rig_faces()` for deterministic results.
  - For anything that changes how the table looks, attach a capture from `tools/capture_bonfire.gd` or `tools/capture_readability.gd`.
  - For throw feel, use `tools/measure_throw_momentum.gd`.

- **Readability and onboarding (#63):**
  - The `throw_measured` and `refused` signals on `Bonfire3D` (`leave()` / `can_leave_now()` came with #60).
  - `scripts/bonfire/table_events.gd` (`table.events`): the plain signals FX and audio listen to (see the FX section).
  - `scripts/core/bust_risk.gd` (`BustRisk`): the exact chance the next rethrow lights nothing, for the rethrow prompt. Static and display-only: it never touches the run's RNG or state.
  - `scripts/bonfire/bonfire_onboarding.gd` (`BonfireOnboarding`, `table.onboarding`): when the Table 1 tutorial runs, which hint to ask for at each table moment, and the seeded tutorial throws. The hint panel itself is `bonfire_tutorial.gd`.
  - `scripts/bonfire/soul_reliquary_hookup.gd` (`SoulReliquaryHookup`, `table.reliquary`): the 3D Soul Reliquary prop (#150) on the Bonfire table, replacing the hidden 2D `soul_meter` (#149/#167). `BonfireTableLayout._place_reliquary()` picks PC / phone / portrait (`reliquary_kind()`; windows under 720 real px tall use the phone prop: it reads `get_window().size`, since the canvas is always scaled to 1080 tall) and places it at the Hearth board marker. In portrait, `clear_of()` slides the stacked plate along the rail until it is clear of the Throw / Bank column; `_refresh_hud` calls `sync(run)` (fill, cur/max plate, lethal crack, -N / +N, loss ghost, shudder). `reliquary_rect()` is the plate on screen, used by the bust crack overlay, the landscape felt margin and the onboarding "soul" arrow.
  - `GameSettings`: `hints_seen` (saved: how often each hint has shown) and `throw_debug` (this session only). `-- --throw-debug` on the command line, or F3 in debug builds, shows the throw overlay. Display apply: `apply(display)` always sets volumes. It only touches the window (mode, VSync) at boot (`_ready` → `apply()`) or when `set_option` changes Fullscreen or VSync (`needs_display_apply`). `window_mode_to_set` leaves a minimized window alone and skips a mode that is already set. Saving hints or tutorial flags never touches the window. Tests record the calls through `display_stub` (`tests/test_window_mode.gd`).
  - Captures: `tools/capture_readability.gd` and `tools/capture_onboarding.gd`.

- **Dealer art (#171):** `scripts/bonfire/bonfire_dealer_art.gd` (`BonfireDealerArt`, `table.dealer_art`) puts ONE dealer scene at Smiles' spot `(-0.42, -0.47, -0.86)`:
  - The dealer stands `GREYBOX_RAIL_LIFT` (0.12 m) above `DEALER_SPOT` so faces clear the greybox far rail; set it to 0 when the Hearth board ships.
  - Normal and Elite tables show Smiles. A boss table swaps in that boss's scene (`BOSS_ART`: cheat id → `art/models/characters/bosses/<folder>/`) instead of Smiles, never beside him. The Compatibility / mobile renderer loads `*_mobile.tscn`.
  - Boss is read from the cheat id in `TableSetup.rules`. Madame Shuffle: `madame_shuffle_stopgap` (PR #172) maps to the `shuffle` dealer; there is no faces fallback, so `pit_boss` is always the Pit Boss.
  - Floor-3 bosses with no dealer scene yet (Baron Vig, Mister Wick, Odds Bodkin) keep Smiles. A missing scene file brings back the greybox `Dealer3D` bust.
  - The greybox bust is hidden while art stands there; its rake and head anchor (speech bubble) stay. `Table3D.taunted` plays `taunt`, then `idle`.
  - A swapped-out dealer is freed at once, except Ashmouth mid-taunt: hidden and kept until ~1.75 s so his soot puff finishes. His `AshmouthPuffFx.reduced_motion` follows `Bonfire3D.reduced_motion` live.
  - Test: `tests/test_boss_dealer_swap.gd`.

- **d4 readability (#198):** the table lamp's shadow leaves a d4's steep faces near black, so `PolyBody` gives every d4 (e.g. the Gallows die) two extras. Neither is a glow: a d4 has emission 0 at rest and only the normal scoring glow (<= 0.3).
  - `scripts/table3d/d4_flat_pass.gd` (`D4FlatPass`): an unshaded `next_pass` on the d4 body (before its ink outline) that draws the die's OWN body colour and marks at `MIX` (0.6) over the lit toon draw, the #201 rare-trim idea. It follows the lit / cold state (`DieVisual._apply_glow` sets `die_lit` / `die_cold` on the body's next pass too); `COLD_LIFT` brightens only a cold d4 to the cold d6's ~0.45.
  - `scripts/table3d/d4_value_tag.gd` (`D4ValueTag`, child `D4ValueTag` of the die): an unlit, camera-facing, fixed-size Label3D with the die's `shown_value()`, at least `MIN_VIEW_SHARE` (9%) of the view tall (~35 px on an 844x390 phone). Each frame `place()` tries below, right, left, then above the die and takes the first spot on screen that covers no HUD text; with none it hides.
  - `scripts/bonfire/hud_text_rects.gd` (`HudTextRects.collect`): screen rects of all text a player reads: visible, non-empty 2D labels / buttons / rich text, and the felt's 3D labels (combo strip, seal row "Lv1 120x12"). Faded-out labels don't count.
  - Tests: `tests/test_d4_readable.gd` (brightness part needs a renderer: `xvfb-run -a godot --path . --rendering-method gl_compatibility --script ...`).
- **Nerve panel dodge (#198):** `NerveUi._place_panels` puts the "Nerve ready" pip and the rescue prompt at their home spot, then through `RulesPlaqueDodge.place(rect, blockers, view)` (left, below, above, right; else least overlap). The blockers (`NerveUi._blockers`) are the landed dice (`RulesPlaqueDodge.die_rect`) plus `HudTextRects.collect`, minus the Nerve UI's own labels and the bounty cards it hangs under. Target HUD v2.1: the goal plate (grown 24 px) is a blocker too, Nerve re-places in the same frame the plate or SEALS chip moves (`item_rect_changed`), and when all 4 spots overlap the dodge sweeps for the first clear spot. Test: `tests/test_target_hud.gd`. Test: `tests/test_nerve_die_clear.gd` (PC 16:9 and phone 844x390, d4 parked under the pip).

<!-- SECTION: VFX Dev — FX (owner text; replace freely) -->
## FX and juice (owner: VFX Dev)
- FX is listen-only. Godot Dev's `scripts/bonfire/table_events.gd` (`table.events`) emits gameplay signals: `dice_thrown`, `die_impact`, `dice_settled`, `die_lit_changed`, `combo_potted`, `hot_hand`, `no_score`, `bust`, `banked`, `bounty_claimed`, `table_cleared`, `boss_cheat`, `mod_triggered`, `selection_changed`. FX nodes connect to those signals and never call into scoring or the table flow.
- `selection_changed(potted_ids: Array, joinable_ids: Array)` gives die event ids: the potted dice, and the dice that could still join the pot (`BonfireRun.can_join`). It is the source for the selection glow (#162). It fires (via `BonfireThrowFlow.emit_selection()`) when a throw resolves, after each pot or unpot in `pick_die` (a refused tap sends nothing), after a Nerve nudge or undo, and on bank. Whenever the run is not in PICK, both arrays are empty: on a bust or any other non-PICK resolve, and after a bank. That empty send is the cue to clear all selection glows.
- Everything FX lives in `scripts/fx/`: the audio cue listener, the shared trigger grammar (special die and face-mod triggers, per `art/concept/special_dice/trigger_fx_spec.md` in the team shared folder, not in the repo), glow states, Hot Hand ember trails, bust snuff, and the brazier eruption.
- To add an effect: write a node in `scripts/fx/` that connects to the relevant `table.events` signal, keep its timing inside the spec's pot-time budget, and add a test under `tests/` that emits the signal and checks the result.
- Art direction rules: dice glow only (lit ember versus cold matte grey) and never show fire. Flat toon flipbook fire is allowed only on board props such as the brazier and candles.
- Ask first: new signals or payload changes go to Godot Dev. Don't edit `table_3d.gd`, scoring, or `dice_sim` to make an effect work. Ask VFX Dev before changing the trigger grammar or cue timing.
- Test headless: `./run_tests.sh` from the project root, using Godot 4.7.2 (any install; set $GODOT if needed). `tests/qa_/` is QA's: you may add checks, but never loosen, skip or delete an existing one.

<!-- Note from VFX Dev: the first FX PRs aren't merged yet, so folder and file names may change slightly; a correction will follow. -->

> FX PRs in flight: `scripts/fx/` and `scripts/bonfire/table_events.gd` aren't on `main` yet (as of fad5622). Today's table effects live in `scripts/bonfire/bonfire_juice.gd` (Godot Dev's adapter) and `scripts/table3d/fx_3d.gd`.

<!-- SECTION: Sound Designer — audio (owner text; replace freely) -->
## Audio
- **Module:** `scripts/audio/`, `audio/sfx/`, `tools/bake_sfx.gd` (owner: Sound Designer; ask there or in the PR). `audio/music/` is planned.
- **Playback:** `SfxManager` (a plain Node; each table creates its own) plays named events through a pool of round-robin `AudioStreamPlayer`s on the `SFX` bus: `sfx.play(event, pitch, vol_db, jitter)`. Physics and feel hooks: `play_throw(flick_speed_px_s)`, `play_impact(kind, speed_mps, material, die_id)` and (coming) `play_mod_trigger(row_id, tier, intensity, hit_ms)`. `CrowdLayers` is now a no-op (its `start`, `stop`, `set_pot_fraction` and `nudge` do nothing) kept so existing callers keep working; there are no crowd loops (the ambience bed was removed in #177). Each event's parameters and timing are listed in `scripts/audio/README.md`.
- **Lookup order:** `audio/sfx/<event>_NN.wav` takes (rotated randomly, never the same take twice in a row), then `audio/sfx/<event>.wav`, then procedural synthesis from the `*Synth` scripts. A missing file therefore never makes the game silent.
- **Sources:** every shipped sound so far is generated by code (`SfxSynth`, `BonfireSynth`, `ThrowSynth`, etc.). Each synth has a static `bake_all()`, and `godot --headless --path . --script res://tools/bake_sfx.gd` re-bakes all of them, byte for byte. `audio/sfx/SOURCES.md` logs where every file came from and its licence. Only add self-made or verified CC0 or commercially free sounds, and log each one there.
- **Format:** WAV, 16-bit PCM, mono, 22,050 Hz (44.1 kHz only when it genuinely needs it), peak 0.85, ideally under 60 KB per one-shot. Import uses `compress/mode=2`, and nothing loops: every `.import` keeps `edit/loop_mode=0` (`tests/test_sfx_no_loops.gd`). Commit the `.wav`, `.import` and `.uid` files, never `.godot/`.
- **Adding a sound:** write a recipe in the relevant synth and add it to `bake_all()` (or drop in a logged CC0 file). Bake it, add the event to the README, and cover it in that synth's `tests/test_*_sfx.gd`. Call it from game code by event name only. Keep game numbers in `BonfireTuning` (`resources/tuning/bonfire_tuning.tres`) or `RunData`, and audio curves in the audio module.
- **Rules:** sound randomness is cosmetic and may use the unseeded RNG; game randomness must go through `DiceRoller`. No fire or crackle textures on dice sounds. Audio PRs need a capture attached and follow AGENTS.md (`audio/...` branches, 400 lines or fewer, one module).

> Audio PRs in flight: only `SfxManager.play_mod_trigger()` isn't on `main` yet (as of fad5622). `SfxManager` (`play`, `play_throw()`, `play_impact()`), `CrowdLayers` (now a silent no-op, #177), `SfxSynth`, `BonfireSynth`, `ThrowSynth` and the `<event>_NN.wav` takes are.

<!-- SECTION: Art Director — art direction (owner text; replace freely) -->
## Art direction
- **Style:** toon-noir infernal casino (the Underhouse). Chunky shapes and strong silhouettes; everything must read at 48 px on a phone. Fully original IP, so never copy or reference another game's art, names or characters.
- **Reserved colours:** Soul cyan `#4FE6E0` is only for Soul and the player. Danger red `#FF2E3E` is only for losses and costs. Violet glow is only for Satanic dice. The table felt is green. Stored colours are tuned for the warm orange table lamp.
- **No fire on dice:** dice show state with glow only. Fire is limited to the board (brazier, candles, ember seam) per `art/concept/fire/fire_style.md`.
- **No occult symbols** (pentagrams and the like). Devils, imps, bones, brass, wax and contracts are fine.
- **Board safe zones:** the felt is 2.04 by 1.04 m with its top at y=0. Decoration stays at |x| at least 1.11 and |z| at least 0.61, and under 0.25 m tall. See `art/concept/burnline_boards/board_kit.md`.
- **Where things live:** concepts and briefs are in `art/concept/` (bonfire_table/, special_dice/, fire/, burnline_boards/), the UI art kit is in `art/ui/readability/` (fonts are in `art/ui/fonts/`, Barlow Condensed and Alfa Slab One, both OFL; the shipped copies are in the repo's `fonts/`), renders are in `art/renders/`, and in-engine captures are in `captures/`. All of these are in the team shared folder, not in the repo; only `art/models/` is in the repo. Effect and trigger timing is in `art/concept/special_dice/trigger_fx_spec.md`.
- **Who owns what:** Art Director owns look, briefs and sign-off. 3D Artist builds meshes, materials and animation. VFX Dev builds in-game effects and juice. Game Designer owns rules in `design/*.md` (team shared folder, not in the repo), so art never edits those. Godot Dev owns the main checkout and git.
- **Getting art approved:** (1) start from or request a brief from Art Director; (2) deliver renders or in-engine captures, including a 48 px strip and a phone-landscape shot; (3) Art Director reviews and sends notes or signs off; (4) Art Director sends the signed-off paths to PM, whose answer counts as Cash's approval (Cash has delegated approvals to PM); (5) open a PR, which QA merges. Locked decisions are recorded in each folder's README under LOCKED DIRECTION.

<!-- SECTION: 3D Artist — art pipeline (owner text; replace freely) -->
### Art pipeline (3D)
- **Source and export:** every mesh is built by a Blender 4.5 LTS Python script run headless (`blender -b -P <script>.py`), never hand-edited. The script lives next to its asset in `src/` and exports binary glTF (`.glb`). To change an asset, edit the script and re-export.
- **Folders:** `art/models/dice/`, `art/models/boards/<board>/` (with `materials/`, `scenes/`, `scripts/`, `shaders/`, `src/` and `textures/`) and `art/models/characters/<name>/`. Toon materials are `.tres` files in `materials/`, assigned per glTF material slot. Each asset folder has a README listing its hooks (params, clips, node names) and an origin/license line.
- **Conventions:** Godot axes (+Y up, −Z forward), metres, scale 1, and pivots at the geometric centre. Names are snake_case (`<name>_d6.glb`, `<name>_d6_mobile.glb`, `<die>_<slot>.tres`).
- **Godot import settings:** commit each `.glb.import` exactly as Godot writes it; if a writer script generates it, the output must be byte-identical, or every import dirties the tree. Textures import lossless with mipmaps on.
- **Budgets:** about 15k tris per board on PC and 8k on mobile; dice around 2k tris or less. Ship a `_mobile` LOD, and everything must read at 48 px on a phone.
- **Size limits:** Any file over ~20 MB goes to PM per REVIEWING.md §5; smaller art/audio binaries are fine.
- **Adding a die:**
  1. Add it to the dice build script (`art/models/dice/src/`; not in the repo yet, ask 3D Artist).
  2. Keep the d6 face map (1 = +Y, 6 = −Y, 2 = +X, 5 = −X, 3 = +Z, 4 = −Z; read by `value_up()` in `scripts/table3d/die_visual.gd`). Size it to `TuningData.die_size` (0.08 m).
  3. Put face art (pips, numerals) in the mesh or in one face texture.
- **Colliders:** gameplay colliders are code-built by the Godot devs (a 0.08 m BoxShape3D for d6s), so meshes ship without collision. Any visual overhang past the box needs Godot Dev's sign-off and must be recorded in SPECIAL_DICE.md.
- **Tests:** add or extend `tests/test_*` for face orientation, tri budget and extents, then run `./run_tests.sh`.
- **Branches:** `art/<topic>`, PR label `module:art-import`. Update a pushed branch by merging `main` in (CONTRIBUTING.md §6).
