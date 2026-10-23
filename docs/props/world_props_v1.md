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

**Purpose:** The player reads the cheat from the table before the first throw. **Each boss is ONE asset: the boss bust plus their signature prop**, placed on the dealer rail at the dealer end, inside the decoration zone (|x| ≥ 1.11, |z| ≥ 0.61, under 0.25 m tall; Art Director, CONFLICTS_133 #2). **Nothing sits on the felt behind the pot.** The prop must read at 48 px from the game camera. Exception: Ashmouth reuses the board's existing brazier (1.3). Each prop has three base states: **idle** on table start (`table_started`), **pulse** when the cheat bites (`boss_cheat(cheat_id, die_ids)` or the specific hook below), and **resolved** on `table_end` (it dims and stays). The boss list comes from `resources/map/floor_{1,2,3}.tres` `boss_cheats` and the handlers in `scripts/core/rules/table_rules.gd`.

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
  - **pulse** on `throw_landed` when any die's value equals `rule_pit_boss.gd` `locked` (not on `boss_cheat`: the Pit Boss never changes a face)
  - **dim** on `table_end`
- **Assets:** one boss asset: bust + (plaque, stand); material (aged brass, enamel); decal set for numerals 2–6 plus the bar; flip animation (0.3 s).

### 1.2 Madame Shuffle: fanned card hand
- **Line now (stopgap)** `madame_shuffle`: "Each hand, a 2 or a 4 never lights." Live data uses this text.
- **Look:** a gloved hand prop holding three fanned cards. The front card shows the locked 2 or 4 as pips, with a red bar.
- **States:**
  - **face-down** (table start)
  - **reveal 2/4** on `hand_start` (same `locked` hook as Pit Boss, pool [2, 4])
  - **pulse** on `boss_cheat`
  - **dim** on `table_end`
- **After the rework** (line "After each throw, she rerolls one random lit die.", `rule_madame_shuffle.gd`): the prop changes to a **swap** state. A card flicks toward the rerolled die on `boss_cheat(die_ids)` after `throw_landed`. Build the card-flick animation now, but **don't ship the reroll state until the handler is live**, or the prop will contradict the stopgap text.
- **Assets:** one boss asset: bust + (gloved hand, 3 cards); material (lace glove, card stock); decals for pips 2 and 4, the bar, and the card back; reveal and flick animations.

### 1.3 Ashmouth: cold brazier
- **Line** `ashmouth`: "No Hot Hand, and you get one fewer hand."
- **Look:** the Hearth board's **existing TargetPlate brazier**, shown in an **unlit** state (grey ash, faint smoke), plus the Ashmouth bust on the dealer rail. No second brazier. Its fire stays out (props may hold fire; this one shows none on purpose). The −1 hand shows as an empty socket in the candle row (#2).
- **States:**
  - **cold** (ash, faint smoke)
  - **puff** when the player pots every die and Hot Hand is denied (`BonfireRun.hot_hand_allowed()` false; `rule_no_hot_hand.gd`). An ash puff, and the dice do *not* fly back.
  - **dim** on `table_end`
- **Assets:** **no new brazier mesh** (reuse the TargetPlate brazier); an unlit/ash material state for it; the Ashmouth bust (one boss asset); ash-puff particle (prop-only); smoke loop.

### 1.4 The Straight Man: measuring rod
- **Line** `straight_man`: "Runs of 3 don't count; runs of 4 or 5 still do."
- **Look:** the Straight Man bust holding a short tailor's rod across the dealer rail (not on the felt) with notches 1–5. The 3-length section is taped off in red, and marks 4 and 5 are bright.
- **States:**
  - **idle**
  - **pulse on the red section** when a run of 3 is excluded (`rule_straight_man.gd excluded_combos` removes it from the pot preview, on `throw_landed` or a pot attempt)
  - **brighten the 4/5 mark** on `combo_potted` with run4/run5
  - **dim**
- **Assets:** one boss asset: bust + (rod); material (wood, brass caps); decals (numbers, red tape); pulse animation.

### 1.5 The Collector: small cloche on the rail
- **Line** `collector`: "Face mods do nothing on each hand's first throw."
- **Look:** the Collector bust beside a **small glass cloche on the dealer rail, over one die marker** (a single carved die token). It never covers the throw zone or the dice (AD, CONFLICTS_133 #3).
- **States:**
  - **lowered** over the rail die marker on `hand_start`, for the first throw (`rule_collector.gd mods_active()` false). Face-mod decals on the dice desaturate (marks only; body and glow unchanged).
  - **lifted** after the first throw's resolve (next `throw_landed` with throws ≥ 1)
  - **lowered again** on the next `hand_start`
  - **dim**
- **Assets:** Collector bust plus small cloche and die marker (one boss asset); clear glass material (small, so no felt reflections); lower/lift animation; a mod-decal desaturate parameter on the die shader (decal only).

### 1.6 The Bloodletter: lancet and double bowl
- **Line** `bloodletter`: "Every Soul cost is doubled: a bust costs 2 Soul."
- **Look:** the Bloodletter bust with a **clean** tarnished-silver lancet and a twin-spout bowl, linked visually to the Soul vessel (#2). **Not gory:** no pooling, splatter or stains. **Danger red appears only on the falling drop**, as the cost cue, and nowhere else on the asset (AD, CONFLICTS_133 #4).
- **States:**
  - **idle**
  - **double drip:** whenever Soul is lost at this table (`bust`, Blood face pot `soul_cost`, timeout), two red drops fall from the twin spouts and the vessel drains by the doubled amount (`rule_bloodletter.gd soul_cost`)
  - **dim**
- **Note:** Nerve costs no Soul (nerve_v1), so Nerve never triggers the drip.
- **Assets:** Bloodletter bust plus bowl and lancet (one boss asset); tarnished silver material; Danger-red drop material (the drop only); drip animation.

### 1.7 Mister Wick: six-wick candle
- **Line** `mister_wick`: "6s never light, and a bust costs 2 Soul."
- **Look:** a squat candelabrum with six wicks numbered 1–6. Wicks 1–5 burn (fire on the prop is allowed). Wick 6 is snuffed under a small brass snuffer cap and trails smoke.
- **States:**
  - **idle**
  - **snuffer tap** when any die lands or is nudged to 6 (`rule_cold_sixes.gd can_light` false; `boss_cheat`, `die_nudged` to 6). The 6 stays cold, per nerve_v1.
  - **flare** of the 5 lit wicks on `bust` (2 Soul)
  - **dim**
- **Assets:** one boss asset: bust + (candelabrum, snuffer); materials (wax, brass); numeral decals 1–6; prop fire for 5 wicks; smoke; tap animation.

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
- **Assets:** one boss asset: bust + (ledger, stamp); materials (paper, leather); decals (tally boxes, ticks, stamp); stamp and shake animations.

### 1.9 Odds Bodkin: one-throw hourglass
- **Line** `odds_bodkin`: "Bounties count only on each hand's first throw; +1 hand."
- **Look:** a tiny hourglass on a bookie's slate. The +1 hand shows as an extra candle (#2).
- **States:**
  - **full** on `hand_start`
  - **runs out** after the hand's first throw resolves (`rule_first_throw.gd bounties_count()` turns false). Bounty chits (#2) grey their "progress" layer.
  - **flips back** on the next `hand_start`
  - **dim**
- **Assets:** one boss asset: bust + (hourglass, slate); glass and sand material; flip animation.

**Elite twists** (Cold Sixes, Cold Hands, Greedy Pot, First Throw) share handlers with Wick, Ashmouth, Vig and Bodkin. Later, they can reuse those props at about 60% scale with a plain finish and their own twist text. Not in this pass.

---

## #2 Table resource props

### 2.1 Hand candle row
- **Purpose:** hands left at a glance.
- **Line** `hands_label`: "Hands left: {n}"
- **Look and placement:** a row of tall candles on the near rail, left side, with one **lit** candle per remaining hand (prop fire is allowed). The row holds up to 8 sockets (tunable display constant `CANDLE_CAP = 8`).
  - **Layout (AD v4, Oct 22):** on PC and landscape phone, two tiers of 4: hands 1-4 on the front bar, 5-8 on a back bar just behind, offset half a pitch so every flame shows. The back bar only shows when more than 4 sockets are used. Portrait is single file, clear of the cauldron. One marker per layout (`Anchors/CandleRow`, `CandleRowPhone`, `CandleRowPortrait`); the table code picks it by orientation.
  - **More than 8 hands:** all 8 lit, and candle 8 carries the cue (no text): raised to the tallest wax, a flared flame, and two stacked gold collars. It clears when hands_left drops to 8.
- **States and triggers:**
  - **Table start** (`table_started`, `BonfireRun._init` sets `hands_left = goal.hands`). `goal.hands` already includes `hands_delta` (`scripts/core/map/map_run.gd:108`).
    - **Negative delta** (Ashmouth, Baron Vig): an empty socket with a cold wick stub stays visible.
    - **Positive delta** (Odds Bodkin, elite twists): the extra candle rises in with a brass ring so it reads as a gift.
  - **Hand spent**, on `bank` or `bust` (`hands_left -= 1`, bonfire_run.gd:533): the rightmost lit candle snuffs out with a smoke curl (two tiers: the back tier's right end first, candle 8 -> 1). A bust also adds a gutter-drip on the wax.
  - **Last hand** (`hands_left == 1`): the last flame flickers faster.
  - **Out of hands** (`table_end`): all candles are out.
- **Invariant:** lit candles == `hands_left` at all times.
- **Assets:** new mesh (candle, socket, stub, rail holder); wax material; prop flame and smoke; snuff and rise-in animations.

### 2.2 Soul vessel
- **Purpose:** Soul as a physical level.
- **Lines** `soul label`: "Soul"; glossary **max Soul**: "The most Soul you can have; healing stops there."
- **Look and placement:** a glass reliquary on the near rail, right side, filled with **Soul cyan #4FE6E0** liquid. Cyan is the Soul colour and appears only on this liquid; the glass and base stay neutral. The Bloodletter drop stays red only at the drop. Fill height = `soul / max_soul`. Etched ticks every 5 Soul, and the HUD number is printed on the base plate.
- **States and triggers:**
  - **Drain** on any Soul loss (`RunProgress.change_soul(delta<0)`, run_progress.gd:43): `bust(soul_loss)`, a Blood face pot (`pot.soul_cost`), timeout or forfeit (`table_end`), event costs (`event_applier.gd`). The drain is a quick drop plus a drip. With Bloodletter, it shows the twin-spout drip (1.6).
  - **Rise** on heal: Rest "Heal {n} Soul" (`run.rest_heal()`), event heals, contract piece (full heal).
  - **Vessel grows** on a `change_max_soul(+)` such as the Soul Draught (`map_run_shop.gd`; line `shop_soul_button`: "Soul Draught: +4 max Soul, heals 4. {n} Embers") or a contract piece (`contract_max_soul`). The glass stretches taller, then the liquid rises.
  - **Full:** the liquid sits at the brim. An Altar Soul-only choice is greyed out (first_time_clarity_v1 §0c).
  - **Low** (≤5, tunable display constant `SOUL_FROST_AT = 5`): the glass frosts at the edges.
  - **Empty** (`soul == 0`, run over).
- **Assets:** new mesh (reliquary, base plate); materials (glass, liquid shader with fill parameter); drain, rise and stretch animations; frost overlay.

### 2.3 Bounty chits on the far rail
- **Purpose:** the bounties as cards lying on the table.
- **Lines** (per bounty, e.g. `triple` / `Trips`: "Pot three of a kind."), `PENDING_TEXT`: "Pending: bank to claim it.", `card_header`: "Claim all {n} bounties · {h} hands left"
- **Look:** paper chits **on the far rail** (not the felt), one per bounty, reusing the bounty_card art (`scripts/bonfire/bounty_card.gd`: ghost stamp and burgundy CLAIMED wax).
- **States and triggers:**
  - **open** (`set_state("open")`)
  - **progressing** (`set_state("pending")`): a combo matching it was potted but not banked (`BonfireRun.is_pending`). The oxblood ghost stamp shows.
  - **stamped** on `bank` → `bounty_claimed(id)`: the wax seal stamps in (`_stamp_in`, impact signal `stamp_impact`)
  - **pending lost** on `bust`: the ghost stamp fades off. Hint `HB5 lost`: "That bust lost your pending bounty; bank sooner to keep it."
  - **failed** at `table_end` with unticked bounties: the chit's edge goes **soot-dark** (soot only: no flame, no ember glow) and the chit tilts. Line `end_body (out of hands)`: "{n} bounties unclaimed: -{s} Soul."
  - **Odds Bodkin / First Throw** after the counting throws: the progressing layer greys out (1.9).
- **Assets:** existing stamp textures; new chit mesh (curled paper card); soot-edge decal (no flame); tilt and fade animations.

### 2.4 Ember stacks (added by PM)
- **Purpose:** wealth reads physically. The stacks **roughly** track Embers; the HUD number is the source of truth.
- **Line** `coin_label`: "Embers {n}". In player text, call them Embers, never "chips" (banned word).
- **Look and placement:** stacks of **non-emissive warm metallic tokens** (dark bronze/copper lacquer, darker than any die, **no glow**) at the player's right elbow. One token stands for about 2 Embers (tunable display constant `EMBERS_PER_TOKEN = 2`), up to 4 stacks of 8 (tunable display constants `EMBER_STACKS = 4` and `EMBER_STACK_HEIGHT = 8`). Above the cap, the stacks stay full.
- **States and triggers:**
  - **Add** tokens on Embers gained: `coin_label` refresh, table points to Embers at `table_end` (`points_to_embers`), Gilded pot (`pot.embers`)
  - **Remove** tokens on spending in the shop
  - **Static** otherwise
  - The token count rounds; it never shows an exact number
- **Assets:** new token mesh plus an instanced stack; warm metallic material (non-emissive); slide-in and slide-out animations.

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

### 3.1 Body by die type: AD's 5 families

Every die body uses one of the Art Director's **5 material families: bone, brass, glass, wood, obsidian** (MERGED_PLAN rank 2). Within a family, the die type stays readable through its **shape** (coin, d4, talus, d8, d10, d12, d20) and its **marks**. Each d6 special carries a small **identity emblem** engraved on one corner bevel, never on a face, so it never collides with face-mod marks. The emblem reuses that die's existing trigger glyph from `art/vfx/trigger_fx/icons/svg/`. **Obsidian dice have bone pips.** Mirror and Lantern are **frosted pale glass**. Oxblood stays clear of Danger red, and no violet appears on any die.

| Die id (shape) | Family | Read cue (shape / emblem) | strings_v1 line (id) |
|---|---|---|---|
| `bone` (d6) | **bone** | baseline, no emblem | `bone_die` "A plain six-sided die; 1s and 5s light on their own." |
| `extra` (d6) | bone | "+1" corner emblem (new small decal) | `extra` "A plain die: throw one more die each hand, up to 7." |
| `cracked` (d6) | bone | fracture decal over the body; `glyph_cracked_mult` emblem; on `die_shattered` it breaks (debris, no fire) | `cracked` "x2 mult; 1 in 6 it shatters, unless you own only 5." |
| `twin_flame` (d6) | bone | `glyph_twin_flame_pair` emblem (no fire) | `twin_flame` "A Pair or Two Pair with this die gets +4 mult." |
| `verdict` (d20) | bone | d20 shape; Hellfire mark on 20, Blood mark on 1 | `verdict` "Rolls 1 to 20; its 20 is Hellfire, its 1 is Blood." |
| `tithe` (d10) | **brass** | d10 shape; Gilded mark on 10 | `tithe` "Rolls 1 to 10; its 10 is Gilded, +1 Ember when potted." |
| `ferryman` (coin) | brass | coin shape, heads/tails reliefs; copy die, can't be nudged | `ferrymans_coin` "Heads copies your highest die; tails copies your lowest." |
| `mirror` (d6) | **glass**, frosted pale | `glyph_mirror_copy` emblem | `mirror` "After it lands, it copies the nearest other die." |
| `lantern` (d8) | glass, frosted pale | d8 shape; Wild mark on 8; still listed in gravedigger.tres (hidden in play while the die is disabled), so the asset is needed | `lantern` "Rolls 1 to 8, and its 8 is a Wild Face." |
| `wanderer` (d6) | **wood** | `glyph_wanderer_gap` emblem | `wanderer` "A run with this die may skip one number." |
| `knucklebone` (talus) | wood | talus shape (values 1, 3, 4, 6) | `knucklebone` "Rolls 1, 3, 4, 6; sets with it score +1 Seal level." |
| `powder_keg` (d6, printed 1-1-2-2-3-3) | wood | printed faces; Twin mark (two-dice glyph) on both 3s | `powder_keg` "Rolls 1 to 3, and each 3 counts as two 3s." |
| `bellows` (d6) | wood | `glyph_bellows_hot` emblem | `bellows` "Each Hot Hand gives +2 mult instead of +1." |
| `blood_pact` (d6) | wood, dark lacquer (kept clear of Danger red) | `glyph_blood_pact` emblem | `blood_pact` "When potted: +1 mult for every 5 Soul you are missing." |
| `last_breath` (d6) | **obsidian**, bone pips | `glyph_last_breath` emblem | `last_breath` "Pot it from a rethrow of 1 or 2 dice: x3 mult." |
| `coven` (d6) | obsidian, bone pips | `glyph_coven_set` emblem | `coven` "Trips or a Full House with this die gets x2 mult." |
| `midnight` (d12) | obsidian, bone pips | d12 shape; Hellfire mark on 12 | `midnight` "Rolls 1 to 12; its 12 is Hellfire, x1.5 score." |
| `caltrop` (d4) | obsidian, bone pips | d4 shape | `caltrop` "Rolls 1 to 4, and a run with it gets +2 mult." |
| `gilded_d6` (**asset-only**, deprecated) | brass | showcase only, no die id (`DiceIds.ASSET_ONLY_KEYS`) | none, never shown in play |
| `hellfire_d6` (**asset-only**, deprecated) | obsidian, bone pips | showcase only | none |

**Extras needing PM approval:** none. Every die can be told apart by family, shape and emblem.

Each family needs a lit variant and a cold variant (glow shader parameters on the body), checked as stills at 48 px in both renderers. Glass and obsidian need their own glow tuning so that lit vs cold still reads.

### 3.2 Face-mod marks (decal on its own face only)

| Mod id | Mark | Line (id) |
|---|---|---|
| `wild` | a plain spark / wildcard shape (`glyph_wild_face`; no star sigil or pentagram) | `wild` "Counts as whichever number scores best for you." |
| `ember_pip` | `glyph_ember_pip` (painted, no flame) | `ember_pip` "+2 mult when you pot it." |
| `hellfire` | a flame-free heat mark (`glyph_hellfire_face`; no horns, no flame) | `hellfire` "x1.5 to the score when you pot it." |
| `gilded` | brass inlay matching `glyph_gilded_payout` | `gilded` "+1 Ember when you pot it; you keep it if you bust." |
| `twin` | AD's approved **two-dice glyph** (`glyph_twin_face`) | `twin` "Counts as two dice of its number, but never in runs." |
| `step` | `glyph_step_face` | `step` "In a run, counts as one higher or one lower." |
| `stair` | `glyph_stair_face` | `stair` "In a run: +10 base for each die in that run." |
| `kindling` | `glyph_kindling_armed` | `kindling` "Pot it, and your next throw can't bust." |
| `blood` | `glyph_blood_face` (red drop) | `blood` "+4 mult when potted; costs 1 Soul." |
| `heavy` | **new mark, drawn by AD** (no glyph yet) | `heavy` "This face lands twice as often." |
| `blank` | **new mark, drawn by AD** (no glyph yet); the face has no pips; it never lights, even when the body is lit (that face stays matte) | `blank` "Never lights, and you can never pot it." |

- All marks reuse the glyphs in `art/vfx/trigger_fx/icons/svg/` so the face mark matches the trigger FX.
- **Collector** (1.5): on the first throw, mod marks desaturate. Body and glow are unchanged.
- **Assets:** 5 family materials (bone exists; brass, frosted pale glass, wood, obsidian with bone pips), each with lit/cold parameters; 9 face-mod decals cut from existing glyphs plus 2 new marks AD draws (Heavy, Blank); 9 corner identity emblems (8 from existing glyphs, 1 new "+1" for Extra); crack decal; shatter debris.

---

## #4 Nerve token

- **Purpose:** shows Nerve's state at a glance (`design/nerve_v1.md`).
- **Look and placement:** a bone token on the near rail, between the candle row and the Soul vessel. It is **bigger than a die on screen (at least 48 px from the game camera)**, with a **bold** up/down chevron and a silhouette distinct from a bone die: a flat, upright tablet or rail marker, not a cube. Each state changes the silhouette (upright, tipped, flat), checked as a 48 px still. It and replaces any HUD pip (`nerve_ui.gd` reads `NerveState.ui_state()`). Lines: `nerve_button` "Nerve"; `nerve_tooltip` "Once per table, turn one die up or down one face."

| State | Look | Trigger / hook | Line (id) |
|---|---|---|---|
| **available** | upright, chevron carved crisp, bone bright | table start: `NerveState.reset_table()` on `table_started`; a boss re-sit is a new table (`map_run.gd` boss_misses ≤ `boss_resits`) → reset | `nerve_ready` "Nerve ready: 1 per table." |
| **carried over** | upright, with a small notch mark (no glow) | a throw ends (bank/rethrow) with `uses_left()==1` and no nudge; it stays usable on later throws at the same table | **GAP, added:** `nerve_carried` "Nerve unused: it carries to your next throw this table." |
| **picking** | lifts slightly; arrows appear on the chosen die | `UiState.PICKING` (tap token/die, `NerveTable.armed`) | `nerve_pick` "Pick a die, then tap up or down." |
| **nudged (undoable)** | the token tips over toward the die | `UiState.NUDGED`, `die_nudged(die_id, from, to, dir)` | `nerve_undo` "Tap the die again to undo before you pot." |
| **spent** | lies flat, chevron dulled | `UiState.SPENT` (the nudge commits on pot, rethrow or bank: `NerveState.commit()`) | `nerve_spent` "Nerve spent for this table." |
| **closed this throw** | rests, unchanged | first die potted (`NerveTable.pot_closed`) | `nerve_potted_refusal` "Potted dice are locked; turn a die still on the felt." |
| **rescue wait** | slides along the **rail edge** to the point nearest the rescuable die's side and bobs there; it never moves onto the felt | a throw would bust but a nudge could light something: `BonfireRun.bust_hold` returns true (bonfire_run.gd:302); a nudge that leaves nothing lit also enters it (nerve_v1, PM Oct 20) | `nerve_bust_save` "Nothing lit: use Nerve to save the hand, or bust." and, **on the profile's first rescue only**, `HN1 nerve` "Nothing lit, but Nerve can turn one die to save it." |

- **Gestures** (nerve_v1, PM Oct 20): tap then the arrows, drag the die up or down (`NerveTable.DRAG_PX` = 28), or the Up/Down keys.
- **Refusals** shake the token once: `nerve_used_refusal` "Nerve is already used this table.", `nerve_high_refusal` "This die can't go higher.", `nerve_low_refusal` "This die can't go lower.", `nerve_copy_refusal` "Copy dice follow other dice; turn the die they copy."
- **Bloodletter:** Nerve costs no Soul, so the token never links to the vessel.
- **Assets:** new mesh (≥48 px tablet token, rail cradle and slide track); bone material (shared family, distinct silhouette); animations for tip, flat, rail-slide plus bob, and shake; bold chevron and notch decals. No glow: it's a prop, and lit glow is reserved for dice.

---

## Asset totals (after Art Director pass, Oct 22, 2026)

- **Boss assets (8 new, one asset each = bust + prop):** Pit Boss (plaque), Madame Shuffle (card hand), Straight Man (rod), Collector (small rail cloche + die marker), Bloodletter (bowl + lancet), Mister Wick (candelabrum + snuffer), Baron Vig (ledger + stamp), Odds Bodkin (hourglass + slate). Plus the **Ashmouth bust** (9th), which reuses the existing TargetPlate brazier in an unlit state, with no new brazier mesh.
- **Table props (new meshes):** candle, socket and stub (row unchanged); Soul vessel (Soul cyan #4FE6E0 liquid shader with fill parameter); bounty chit for the far rail; warm metallic Ember token and stack (non-emissive); point puck; Nerve tablet token with rail track.
- **Materials:** 5 die families (bone, brass, frosted pale glass, wood, obsidian with bone pips) with lit/cold parameters; brazier unlit/ash state; Danger-red drop (Bloodletter only); warm metal tokens.
- **Decals:** 9 face marks from existing `glyph_*`; **2 new marks by AD (Heavy, Blank)**; 9 die identity emblems (1 new: Extra "+1"); crack; soot edge; boss numerals and pips; Nerve chevron and notch.
- **FX and animation, fire on props only:** candle and candelabrum flame and smoke; ash puff; drip; flip, reveal and flick; cloche lower and lift; stamp and shake; hourglass flip; vessel drain, rise and stretch; chit stamp, tilt and fade; token stack slide; puck slide; Nerve tip, flat, rail-slide and shake; mod-mark desaturate parameter (Collector).

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


**Display constants (approved by PM, Oct 22, 2026):** `SOUL_FROST_AT = 5`, `EMBERS_PER_TOKEN = 2`, `EMBER_STACKS = 4`, `EMBER_STACK_HEIGHT = 8` and `CANDLE_CAP = 8` are display-only and can be tuned without changing any rule.
