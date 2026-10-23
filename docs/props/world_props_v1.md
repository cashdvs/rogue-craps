# World props v1: table props that carry gameplay meaning

Status: **approved for asset work** (PM on Cash's behalf, Oct 22, 2026). Owner: Game Designer. Asset owners: Art Director (look, decals, sign-off) and 3D Artist (meshes, materials, animations).

Specs: **#1** boss props, **#2** table resource props, **#3** die materials, **#4** Nerve token. Later items are listed at the end.

## Art rules (apply to every prop)

- **Glow appears only on dice** (lit/cold). Dice never show fire. Fire is allowed only on props (candles, braziers).
- **No UI side panel.** Props sit on the table, rail or felt edge, inside the 3D scene.
- **Clarity first.** Each prop answers one question, and the answer must be readable at mobile size (phone portrait, about 360 px wide). Use big shapes, high value contrast and Arabic numerals at least 1/12 of the felt width. Never rely on colour alone.
- **A prop must never contradict its rule text.** Every state below quotes the strings_v1 line it has to agree with. If the rule text changes, the prop changes in the same PR.
- **Reduced motion** (R): every animation has a cut-to-end-state version.
- **The HUD stays the source of truth** for numbers. Props mirror it and never show a different number.

Strings come from `design/strings_v1.md` (Tiny Anvil design repo, built by `sim/build_strings_v1.py`, checked by `sim/check_strings.py`, now 367/0). Lines are quoted verbatim with their id. Event names are `TableEvents` signals (`scripts/bonfire/table_events.gd`) or `BonfireRun.table_event` ids (`scripts/core/bonfire_run.gd`).

---

## #1 Boss props that show the cheat

**Purpose:** The player reads the cheat from the table before the first throw. There is one hero prop per boss, placed at the boss's end of the table (top centre of the felt, behind the pot) and sized to read at mobile scale. Each prop has three base states: **idle** on table start (`table_started`), **pulse** when the cheat bites (`boss_cheat(cheat_id, die_ids)` or the specific hook below), and **resolved** on `table_end` (it dims and stays). The boss list comes from `resources/map/floor_{1,2,3}.tres` `boss_cheats` and the handlers in `scripts/core/rules/table_rules.gd`.

| Floor | Boss | Rule data | Handler |
|---|---|---|---|
| 1 | The Pit Boss | `rules/pit_boss.tres` (faces 2–6) | `rule_pit_boss.gd` |
| 1 | Madame Shuffle | `rules/madame_shuffle.tres` (**stopgap**: id `pit_boss`, faces 2/4) | `rule_pit_boss.gd` (until `rule_madame_shuffle.gd` is wired) |
| 1 | Ashmouth | `rules/ashmouth.tres` (hands_delta −1) | `rule_no_hot_hand.gd` |
| 2 | The Straight Man | `rules/straight_man.tres` (min_run 4) | `rule_straight_man.gd` |
| 2 | The Collector | `rules/collector.tres` (throws 1) | `rule_collector.gd` |
| 2 | The Bloodletter | `rules/bloodletter.tres` (soul_cost_mult 2) | `rule_bloodletter.gd` |
| 3 | Mister Wick | `rules/mister_wick.tres` (face 6, bust 2 Soul) | `rule_cold_sixes.gd` |
| 3 | Baron Vig | `rules/baron_vig.tres` (min_pot 3, hands_delta −1) | `rule_greedy_pot.gd` |
| 3 | Odds Bodkin | `rules/odds_bodkin.tres` (throws 1, hands_delta +1) | `rule_first_throw.gd` |

The hands_delta of Ashmouth, Baron Vig and Odds Bodkin is shown by the **hand candle row** (#2). Their boss props don't repeat it.

### 1.1 The Pit Boss: number plaque
- **Line** `pit_boss`: "Each hand, one number from 2 to 6 never lights."
- **Look:** a brass flip-plaque on a short stand, like a hotel room number, with one large black numeral (2–6) on cream and a red bar through it.
- **States:**
  - **blank** (table start)
  - **flip to n** on `hand_start` (`rule_pit_boss.gd` draws `locked` and returns felt text `LOCKED  n` via `bonfire_3d.gd` felt text). The numeral must equal `locked`.
  - **pulse** when a die lands on n (`boss_cheat`)
  - **dim** on `table_end`
- **Assets:** new mesh (plaque, stand); material (aged brass, enamel); decal set for numerals 2–6 plus the bar; flip animation (0.3 s).

### 1.2 Madame Shuffle: fanned card hand
- **Line now (stopgap)** `madame_shuffle`: "Each hand, a 2 or a 4 never lights." Live data uses this text.
- **Look:** a gloved hand prop holding three fanned cards. The front card shows the locked 2 or 4 as pips, with a red bar.
- **States:**
  - **face-down** (table start)
  - **reveal 2/4** on `hand_start` (same `locked` hook as Pit Boss, pool [2, 4])
  - **pulse** on `boss_cheat`
  - **dim** on `table_end`
- **After the rework** (line "After each throw, she rerolls one random lit die.", `rule_madame_shuffle.gd`): the prop changes to a **swap** state. A card flicks toward the rerolled die on `boss_cheat(die_ids)` after `throw_landed`. Build the card-flick animation now, but **don't ship the reroll state until the handler is live**, or the prop will contradict the stopgap text.
- **Assets:** new mesh (gloved hand, 3 cards); material (lace glove, card stock); decals for pips 2 and 4, the bar, and the card back; reveal and flick animations.

### 1.3 Ashmouth: cold brazier
- **Line** `ashmouth`: "No Hot Hand, and you get one fewer hand."
- **Look:** an iron brazier full of grey ash, beside the pot. Its fire is permanently out (props may hold fire; this one shows none on purpose). The −1 hand shows as an empty socket in the candle row (#2).
- **States:**
  - **cold** (ash, faint smoke)
  - **puff** when the player pots every die and Hot Hand is denied (`BonfireRun.hot_hand_allowed()` false; `rule_no_hot_hand.gd`). An ash puff, and the dice do *not* fly back.
  - **dim** on `table_end`
- **Assets:** new mesh (brazier); material (soot iron, ash); ash-puff particle (prop-only); smoke loop.

### 1.4 The Straight Man: measuring rod
- **Line** `straight_man`: "Runs of 3 don't count; runs of 4 or 5 still do."
- **Look:** a long tailor's rod laid along the felt edge with notches 1–5. The 3-length section is taped off in red, and marks 4 and 5 are bright.
- **States:**
  - **idle**
  - **pulse on the red section** when a run of 3 is excluded (`rule_straight_man.gd excluded_combos` removes it from the pot preview, on `throw_landed` or a pot attempt)
  - **brighten the 4/5 mark** on `combo_potted` with run4/run5
  - **dim**
- **Assets:** new mesh (rod); material (wood, brass caps); decals (numbers, red tape); pulse animation.

### 1.5 The Collector: glass cloche over the felt
- **Line** `collector`: "Face mods do nothing on each hand's first throw."
- **Look:** a large glass display cloche hanging above the throw zone.
- **States:**
  - **lowered** over the dice on `hand_start`, for the first throw (`rule_collector.gd mods_active()` false). Face-mod decals on the dice desaturate (marks only; body and glow unchanged).
  - **lifted** after the first throw's resolve (next `throw_landed` with throws ≥ 1)
  - **lowered again** on the next `hand_start`
  - **dim**
- **Assets:** new mesh (cloche, chain); glass material; lower/lift animation; a mod-decal desaturate parameter on the die shader (decal only).

### 1.6 The Bloodletter: lancet and double bowl
- **Line** `bloodletter`: "Every Soul cost is doubled: a bust costs 2 Soul."
- **Look:** a silver lancet resting across a bowl with two spouts, linked visually to the Soul vessel (#2).
- **States:**
  - **idle**
  - **double drip:** whenever Soul is lost at this table (`bust`, Blood face pot `soul_cost`, timeout), two drops fall from the twin spouts and the vessel drains by the doubled amount (`rule_bloodletter.gd soul_cost`)
  - **dim**
- **Note:** Nerve costs no Soul (nerve_v1), so Nerve never triggers the drip.
- **Assets:** new mesh (bowl, lancet); material (tarnished silver, dark-red liquid); drip animation.

### 1.7 Mister Wick: six-wick candle
- **Line** `mister_wick`: "6s never light, and a bust costs 2 Soul."
- **Look:** a squat candelabrum with six wicks numbered 1–6. Wicks 1–5 burn (fire on the prop is allowed). Wick 6 is snuffed under a small brass snuffer cap and trails smoke.
- **States:**
  - **idle**
  - **snuffer tap** when any die lands or is nudged to 6 (`rule_cold_sixes.gd can_light` false; `boss_cheat`, `die_nudged` to 6). The 6 stays cold, per nerve_v1.
  - **flare** of the 5 lit wicks on `bust` (2 Soul)
  - **dim**
- **Assets:** new mesh (candelabrum, snuffer); materials (wax, brass); numeral decals 1–6; prop fire for 5 wicks; smoke; tap animation.

### 1.8 Baron Vig: tally ledger
- **Line** `baron_vig`: "Pot at least 3 dice every throw; -1 hand."
- **Look:** an open ledger with a stamp. Each row has three empty tally boxes. The −1 hand is an empty candle socket (#2).
- **States:**
  - **open**
  - **tally:** each die potted this throw ticks one box (`toggle` and selection)
  - **stamped** when the pot commits with ≥3 dice (`pot`)
  - **refuse-shake** when the player tries to rethrow or bank with fewer than 3 potted (`rethrow_block_reason()`, `rule_greedy_pot.gd min_pot` = 3)
  - **new row** on each `throw_landed`
  - **dim**
- **Assets:** new mesh (ledger, stamp); materials (paper, leather); decals (tally boxes, ticks, stamp); stamp and shake animations.

### 1.9 Odds Bodkin: one-throw hourglass
- **Line** `odds_bodkin`: "Bounties count only on each hand's first throw; +1 hand."
- **Look:** a tiny hourglass on a bookie's slate. The +1 hand shows as an extra candle (#2).
- **States:**
  - **full** on `hand_start`
  - **runs out** after the hand's first throw resolves (`rule_first_throw.gd bounties_count()` turns false). Bounty chits (#2) grey their "progress" layer.
  - **flips back** on the next `hand_start`
  - **dim**
- **Assets:** new mesh (hourglass, slate); glass and sand material; flip animation.

**Elite twists** (Cold Sixes, Cold Hands, Greedy Pot, First Throw) share handlers with Wick, Ashmouth, Vig and Bodkin. Later, they can reuse those props at about 60% scale with a plain finish and their own twist text. Not in this pass.

---

## #2 Table resource props

### 2.1 Hand candle row
- **Purpose:** hands left at a glance.
- **Line** `hands_label`: "Hands left: {n}"
- **Look and placement:** a row of tall candles on the near rail, left side, with one **lit** candle per remaining hand (prop fire is allowed). The row holds up to 8 sockets (tunable display constant `CANDLE_CAP = 8`).
- **States and triggers:**
  - **Table start** (`table_started`, `BonfireRun._init` sets `hands_left = goal.hands`). `goal.hands` already includes `hands_delta` (`scripts/core/map/map_run.gd:108`).
    - **Negative delta** (Ashmouth, Baron Vig): an empty socket with a cold wick stub stays visible.
    - **Positive delta** (Odds Bodkin, elite twists): the extra candle rises in with a brass ring so it reads as a gift.
  - **Hand spent**, on `bank` or `bust` (`hands_left -= 1`, bonfire_run.gd:533): the rightmost lit candle snuffs out with a smoke curl. A bust also adds a gutter-drip on the wax.
  - **Last hand** (`hands_left == 1`): the last flame flickers faster.
  - **Out of hands** (`table_end`): all candles are out.
- **Invariant:** lit candles == `hands_left` at all times.
- **Assets:** new mesh (candle, socket, stub, rail holder); wax material; prop flame and smoke; snuff and rise-in animations.

### 2.2 Soul vessel
- **Purpose:** Soul as a physical level.
- **Lines** `soul label`: "Soul"; glossary **max Soul**: "The most Soul you can have; healing stops there."
- **Look and placement:** a glass reliquary on the near rail, right side, filled with dark-red liquid. Fill height = `soul / max_soul`. Etched ticks every 5 Soul, and the HUD number is printed on the base plate.
- **States and triggers:**
  - **Drain** on any Soul loss (`RunProgress.change_soul(delta<0)`, run_progress.gd:43): `bust(soul_loss)`, a Blood face pot (`pot.soul_cost`), timeout or forfeit (`table_end`), event costs (`event_applier.gd`). The drain is a quick drop plus a drip. With Bloodletter, it shows the twin-spout drip (1.6).
  - **Rise** on heal: Rest "Heal {n} Soul" (`run.rest_heal()`), event heals, contract piece (full heal).
  - **Vessel grows** on a `change_max_soul(+)` such as the Soul Draught (`map_run_shop.gd`; line `shop_soul_button`: "Soul Draught: +4 max Soul, heals 4. {n} Embers") or a contract piece (`contract_max_soul`). The glass stretches taller, then the liquid rises.
  - **Full:** the liquid sits at the brim. An Altar Soul-only choice is greyed out (first_time_clarity_v1 §0c).
  - **Low** (≤5, tunable display constant `SOUL_FROST_AT = 5`): the glass frosts at the edges.
  - **Empty** (`soul == 0`, run over).
- **Assets:** new mesh (reliquary, base plate); materials (glass, liquid shader with fill parameter); drain, rise and stretch animations; frost overlay.

### 2.3 Bounty chits on the felt
- **Purpose:** the bounties as cards lying on the table.
- **Lines** (per bounty, e.g. `triple` / `Trips`: "Pot three of a kind."), `PENDING_TEXT`: "Pending: bank to claim it.", `card_header`: "Claim all {n} bounties · {h} hands left"
- **Look:** paper chits on the far felt edge, one per bounty, reusing the bounty_card art (`scripts/bonfire/bounty_card.gd`: ghost stamp and burgundy CLAIMED wax).
- **States and triggers:**
  - **open** (`set_state("open")`)
  - **progressing** (`set_state("pending")`): a combo matching it was potted but not banked (`BonfireRun.is_pending`). The oxblood ghost stamp shows.
  - **stamped** on `bank` → `bounty_claimed(id)`: the wax seal stamps in (`_stamp_in`, impact signal `stamp_impact`)
  - **pending lost** on `bust`: the ghost stamp fades off. Hint `HB5 lost`: "That bust lost your pending bounty; bank sooner to keep it."
  - **failed** at `table_end` with unticked bounties: the chit chars at the edge (prop-side, no glow) and tilts. Line `end_body (out of hands)`: "{n} bounties unclaimed: -{s} Soul."
  - **Odds Bodkin / First Throw** after the counting throws: the progressing layer greys out (1.9).
- **Assets:** existing stamp textures; new chit mesh (curled paper card); charred-edge decal; tilt and fade animations.

### 2.4 Ember stacks (added by PM)
- **Purpose:** wealth reads physically. The stacks **roughly** track Embers; the HUD number is the source of truth.
- **Line** `coin_label`: "Embers {n}". In player text, call them Embers, never "chips" (banned word).
- **Look and placement:** stacks of dark ember-glass tokens (glowing coal colour, no flame) at the player's right elbow. One token stands for about 2 Embers (tunable display constant `EMBERS_PER_TOKEN = 2`), up to 4 stacks of 8. Above the cap, the stacks stay full.
- **States and triggers:**
  - **Add** tokens on Embers gained: `coin_label` refresh, table points to Embers at `table_end` (`points_to_embers`), Gilded pot (`pot.embers`)
  - **Remove** tokens on spending in the shop
  - **Static** otherwise
  - The token count rounds; it never shows an exact number
- **Assets:** new token mesh plus an instanced stack; ember-glass material (emissive is allowed: it's a prop, not fire); slide-in and slide-out animations.

### 2.5 Point puck
- **Purpose:** set dressing only, with **no readable state**. A heavy bone puck the dealer slides when a hand is banked, adding table texture.
- **Trigger:** cosmetic slide on `banked` (optional).
- **Line:** none needed.
- **Assets:** new mesh (puck); bone material; one slide animation.

---

## #3 Die materials

**Rule (added by PM):** the **body** material comes from the **die type**. A **face mod only adds a marking on its own face** and never changes the body. Several mods on one die means several face marks, one per face, each on its own physical face. Mods stay on their physical faces (Nerve turns the die to an adjacent face list value; it never moves the marks).

**Glow (dice only):**
- **lit:** an even rim glow (warm amber) plus face brightening. Hook: `die_lit_changed(die_id, true)`. Glossary **lit**: "A die that can score right now; it glows."
- **cold:** desaturated and grey, no glow (`die_lit_changed(..., false)`). Glossary **cold**: "A die that can't score this throw; it's grey."
- **Never fire on a die.** Mod "fire" names (Hellfire, Ember Pip, Kindling) are carved marks, not flames.

### 3.1 Body by die type

| Die id (shape) | Body material | Read cue | strings_v1 line (id) |
|---|---|---|---|
| `bone` (d6) | **bone**, ivory with pores | the baseline | **GAP, added:** `bone_die` "A plain six-sided die; 1s and 5s light on their own." |
| `extra` (d6) | bone, with a small "+1" notch on an edge | same as Bone | `extra` "A plain die: throw one more die each hand, up to 7." |
| `mirror` (d6) | **glass**, silvered back (reflective) | reflects the nearest die | `mirror` "After it lands, it copies the nearest other die." |
| `lantern` (d8) | **glass**, smoky lantern panes | still sold by the Gravedigger event (`resources/events/gravedigger.tres`, -10 Embers), so the asset is needed; the choice is hidden while the die is disabled for GIVE_DIE | `lantern` "Rolls 1 to 8, and its 8 is a Wild Face." |
| `wanderer` (d6) | **wood**, walnut with a grain trail | warm, travelled | `wanderer` "A run with this die may skip one number." |
| `knucklebone` (talus) | **wood**, knuckle-carved boxwood (per PM; not literal bone, so it doesn't read as Bone) | 4 sides: 1, 3, 4, 6 | `knucklebone` "Rolls 1, 3, 4, 6; sets with it score +1 Seal level." |
| `last_breath` (d6) | **obsidian** | black, glassy | `last_breath` "Pot it from a rethrow of 1 or 2 dice: x3 mult." |
| `midnight` (d12) | **obsidian**, star-fleck | | `midnight` "Rolls 1 to 12; its 12 is Hellfire, x1.5 score." |
| `cracked` (d6) | bone with deep **fracture** lines (crack decal); on `die_shattered` it breaks (prop debris, no fire) | | `cracked` "x2 mult; 1 in 6 it shatters, unless you own only 5." |
| `twin_flame` (d6) | twin-tone bone (two halves) | flame is in the name only: no fire | `twin_flame` "A Pair or Two Pair with this die gets +4 mult." |
| `coven` (d6) | dark horn | | `coven` "Trips or a Full House with this die gets x2 mult." |
| `bellows` (d6) | leather-wrapped | | `bellows` "Each Hot Hand gives +2 mult instead of +1." |
| `blood_pact` (d6) | oxblood lacquer | | `blood_pact` "When potted: +1 mult for every 5 Soul you are missing." |
| `caltrop` (d4) | blackened iron | spiky | `caltrop` "Rolls 1 to 4, and a run with it gets +2 mult." |
| `tithe` (d10) | pewter; its 10 face carries the Gilded mark | | `tithe` "Rolls 1 to 10; its 10 is Gilded, +1 Ember when potted." |
| `verdict` (d20) | judge's marble; Hellfire mark on 20, Blood mark on 1 | | `verdict` "Rolls 1 to 20; its 20 is Hellfire, its 1 is Blood." |
| `ferryman` (coin) | old silver coin, heads/tails reliefs | copy die: can't be nudged | `ferrymans_coin` "Heads copies your highest die; tails copies your lowest." |
| `powder_keg` (d6, printed 1-1-2-2-3-3) | banded barrel wood; **Twin Face mark** on both 3s | | `powder_keg` "Rolls 1 to 3, and each 3 counts as two 3s." |
| `gilded_d6` (**asset-only**, deprecated) | **brass** | showcase only, no die id (`DiceIds.ASSET_ONLY_KEYS`) | none, never shown in play |
| `hellfire_d6` (**asset-only**, deprecated) | **obsidian** | showcase only | none |

Each body material also needs a lit variant and a cold variant (the glow shader parameters on the body), checked against all of them. Glass and obsidian need their own glow tuning so that lit vs cold still reads at mobile size.

### 3.2 Face-mod marks (decal on its own face only)

| Mod id | Mark | Line (id) |
|---|---|---|
| `wild` | a star sigil replaces the pips | `wild` "Counts as whichever number scores best for you." |
| `ember_pip` | one pip carved as a coal (painted, no flame) | `ember_pip` "+2 mult when you pot it." |
| `hellfire` | a horned brand ring | `hellfire` "x1.5 to the score when you pot it." |
| `gilded` | a brass inlay ring | `gilded` "+1 Ember when you pot it; you keep it if you bust." |
| `twin` | doubled pips (the Twin Face mark) | `twin` "Counts as two dice of its number, but never in runs." |
| `step` | small up and down chevrons | `step` "In a run, counts as one higher or one lower." |
| `stair` | a staircase notch | `stair` "In a run: +10 base for each die in that run." |
| `kindling` | crossed twigs | `kindling` "Pot it, and your next throw can't bust." |
| `blood` | a red drop | `blood` "+4 mult when potted; costs 1 Soul." |
| `heavy` | a lead plate and a thick border | `heavy` "This face lands twice as often." |
| `blank` | the face is smoothed off with no pips; it never lights, even when the body is lit (that face stays matte) | `blank` "Never lights, and you can never pot it." |

- **Collector** (1.5): on the first throw, mod marks desaturate. Body and glow are unchanged.
- **Assets:** 9 new body materials (bone exists; glass ×2, wood ×2, obsidian, iron, pewter, marble, etc. reuse `art/models/dice/materials` where they exist); 11 face-mod decals (normal plus albedo, mobile-legible); crack decal; lit/cold parameters per material; shatter debris.

---

## #4 Nerve token

- **Purpose:** shows Nerve's state at a glance (`design/nerve_v1.md`).
- **Look and placement:** a bone knucklebone-shaped token on the near rail, between the candle row and the Soul vessel. It has a carved up/down chevron and replaces any HUD pip (`nerve_ui.gd` reads `NerveState.ui_state()`). Lines: `nerve_button` "Nerve"; `nerve_tooltip` "Once per table, turn one die up or down one face."

| State | Look | Trigger / hook | Line (id) |
|---|---|---|---|
| **available** | upright, chevron carved crisp, bone bright | table start: `NerveState.reset_table()` on `table_started`; a boss re-sit is a new table (`map_run.gd` boss_misses ≤ `boss_resits`) → reset | `nerve_ready` "Nerve ready: 1 per table." |
| **carried over** | upright, with a small notch mark (no glow) | a throw ends (bank/rethrow) with `uses_left()==1` and no nudge; it stays usable on later throws at the same table | **GAP, added:** `nerve_carried` "Nerve unused: it carries to your next throw this table." |
| **picking** | lifts slightly; arrows appear on the chosen die | `UiState.PICKING` (tap token/die, `NerveTable.armed`) | `nerve_pick` "Pick a die, then tap up or down." |
| **nudged (undoable)** | the token tips over toward the die | `UiState.NUDGED`, `die_nudged(die_id, from, to, dir)` | `nerve_undo` "Tap the die again to undo before you pot." |
| **spent** | lies flat, chevron dulled | `UiState.SPENT` (the nudge commits on pot, rethrow or bank: `NerveState.commit()`) | `nerve_spent` "Nerve spent for this table." |
| **closed this throw** | rests, unchanged | first die potted (`NerveTable.pot_closed`) | `nerve_potted_refusal` "Potted dice are locked; turn a die still on the felt." |
| **rescue wait** | **hovers beside the rescuable die** and bobs | a throw would bust but a nudge could light something: `BonfireRun.bust_hold` returns true (bonfire_run.gd:302); a nudge that leaves nothing lit also enters it (nerve_v1, PM Oct 20) | `nerve_bust_save` "Nothing lit: use Nerve to save the hand, or bust." and, **on the profile's first rescue only**, `HN1 nerve` "Nothing lit, but Nerve can turn one die to save it." |

- **Gestures** (nerve_v1, PM Oct 20): tap then the arrows, drag the die up or down (`NerveTable.DRAG_PX` = 28), or the Up/Down keys.
- **Refusals** shake the token once: `nerve_used_refusal` "Nerve is already used this table.", `nerve_high_refusal` "This die can't go higher.", `nerve_low_refusal` "This die can't go lower.", `nerve_copy_refusal` "Copy dice follow other dice; turn the die they copy."
- **Bloodletter:** Nerve costs no Soul, so the token never links to the vessel.
- **Assets:** new mesh (token, rail cradle); bone material (shared with the Bone die); animations for tip, flat, hover-bob and shake; chevron and notch decals. No glow: it's a prop, and lit glow is reserved for dice.

---

## Strings gaps (resolved via the generator)

Two props had no line. Both rows were added in `sim/build_strings_v1.py` and `check_strings` passes 367/0:
- `bone_die`: "A plain six-sided die; 1s and 5s light on their own." (11 words)
- `nerve_carried`: "Nerve unused: it carries to your next throw this table." (10 words)

**Text to keep in sync** (the props follow strings_v1; data owners should match):
- `straight_man.tres` description "Runs of 3 don't count." (strings_v1 adds "; runs of 4 or 5 still do.")
- `bloodletter.tres` description "Every Soul cost is doubled." (strings_v1 adds ": a bust costs 2 Soul.")
- `mister_wick.tres` description "Snuffs the sixes: 6s never light. A bust costs 2 Soul." (strings_v1: "6s never light, and a bust costs 2 Soul.")
- Fallback texts in `table_rules.gd` for `pit_boss` ("One face value locked each hand.") and `collector` ("Face mods are off on the first throw.")

## Later (after this pass)

- **#4 Seal stamps:** wax Seal stamps on combo faces or table, pulsing when the Seal triggers.
- **#5 Floor tables:** a per-floor felt, wood and lighting swap.
- **#7 Scene props:** shop, rest and event scene props.


**Display constants (approved by PM, Oct 22, 2026):** `SOUL_FROST_AT = 5`, `EMBERS_PER_TOKEN = 2` and `CANDLE_CAP = 8` are display-only and can be tuned without changing any rule.
