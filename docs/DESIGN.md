# Dice of the Damned: design overview

A short overview of the game as it plays on `main` today, for contributors. The full rules,
with a worked example, are in **`how_bonfire_plays.md`** (the team's plain-language guide). It
lives in the team design folder (`design/`), not in this repo; issues quote anything you need
from it. This page gives no tuning numbers of its own: each value is named by the data file that
holds it, so the data always wins. Terms match the glossary in
[ARCHITECTURE.md](ARCHITECTURE.md#glossary).

> **Pitch:** Farkle-style push-your-luck with Balatro-style scoring. Throw 5 dice, keep the
> scoring ones, then bank or throw again. Win a table by claiming its bounties before your hands
> run out.

Single-player dice roguelite, PC first (mouse and keyboard), made in Godot 4.7.2.

## The run

- **Floors:** a run is the floors listed in `resources/map/bonfire_run.tres` (`RunData.floors`:
  `floor_1.tres` to `floor_3.tres` in `resources/map/`).
- **Map:** each floor is a branching map of **Table, Elite, Event, Shop, Rest** and **Boss**
  nodes (`MapGenData`; floor 1's map is `resources/map/floor_1_map.tres`). You pick a path upward.
  - **Table:** a normal Bonfire table.
  - **Elite:** a harder table with one random **twist** from the floor's `elite_twists`. Clearing
    one offers a pick of special dice and a bigger Seal pick.
  - **Event:** a choice with costs and rewards (`resources/events/`). No event repeats until
    you've seen them all.
  - **Shop:** spend Embers (see below).
  - **Rest:** pick one: heal Soul, carve a free face mod, or add Seal levels to a combo you own.
  - **Boss:** the floor's boss, drawn from `boss_cheats` when you enter the floor, plays a table
    with its **cheat**. On the last floor the boss also adds a twist (`boss_adds_twist`). Missing
    the boss isn't the end straight away: you get a **re-sit** (`RunData.boss_resits`).
- **Contract:** each boss beaten gives a contract piece, which raises max Soul and heals you to
  full. After the last boss, you win the run if you hold enough pieces
  (`contract_pieces_to_win`).
- **Soul** is your HP for the whole run (`starting_soul` / `max_soul` in `bonfire_run.tres`).
  At 0 the run is over.
- Every random choice is seeded per run and node, so a run seed replays exactly.

## A table

1. **Throw** the dice in your handful (5 to start: `RunData.starting_dice`). A full 5-die throw
   always has a scoring die, so it can't bust.
2. **Lit vs cold:** dice that can form a combo (a lone 1 or 5, a pair, a run, ...) light up; the
   rest are cold.
3. **Pot** one combo per throw from the lit dice. It scores **(base + potted faces) × mult** into
   the hand's unbanked **pot**. The combo list, with base and mult, is `combos` in
   `resources/tuning/bonfire_tuning.tres`.
4. **Bank or throw again:** bank to keep the pot and end the hand, or rethrow the remaining cold
   dice. A rethrow that lights nothing is a **bust**: you lose the pot, the hand's pending bounty
   ticks and some Soul (`bust_soul_loss`).
5. **Hot Hand:** pot every die and all of them come back, with extra mult on every later pot that
   hand (`hot_hand_mult_bonus`).
6. **Bounties** are the table's goal (`TableGoal`). A bounty ticks when a pot contains its pattern
   (e.g. a Full House contains a Triple). Ticks stay pending until you bank. The floor's `.tres`
   sets how many bounties are required, the bonus bounties and the hands per table (`hands`,
   `boss_hands`).
7. **Cleared or failed:** bank every required bounty within the hands and the table is cleared.
   Run out of hands with bounties missing and each one costs Soul (`timeout_soul_per_bounty`).
8. **Embers** are the run's money. At table end, banked points convert at `points_per_ember`
   (`bonfire_tuning.tres`), plus the floor's `clear_embers` on a clear and boss Embers
   (`boss_embers`) for a boss.
9. **Seals:** after a cleared Table, Elite or Boss you pick one free Seal (or skip it for Embers).
   A Seal levels one combo, adding base and mult per level (`seal_base_step` / `seal_mult_step`).
   Rare Seals (Transference, Black, Ashen) are used on the spot.

Leaving a cleared table early (Leave table) is arriving with Godot Dev's Leave table PR; it isn't
on `main` yet.

## The shop

The shop sells special dice, face mods and Seals, plus paid rerolls of the stock. Its sizes and
prices are the Shop group in `bonfire_run.tres` (`RunData`), and each die's or mod's price is in
its own `.tres`. Each face mod costs more for every mod already on that die
(`mod_price_step_percent`), each Seal bought on a visit raises the next one's price, and you can
sell a die for part of its price (`die_sell_percent`).

## Dice bag and face mods

- **Your handful** starts at `starting_dice` dice and can grow to `max_dice`. Plain dice are
  "Bone" d6s.
- **Special dice** (`resources/dice/special/`, e.g. Coven, Twin Flame, Cracked, Last Breath, Blood
  Pact, Bellows, Mirror) are whole dice with a power. The table scores them.
- **Face mods** (`resources/mods/`, e.g. Wild, Twin, Blank, Gilded, Ember Pip, Heavy, Step,
  Stair, Kindling, Hellfire, Blood) change one face of one die and are carved on that face.
  Effects are listed in `FaceModData.Effect`.
- One sentence each: a **Seal** upgrades a combo; a **face mod** changes one face; a **special
  die** is a new die with a power.

## Twists and cheats

Both are table rules (`RunRuleData`, `resources/map/rules/`):

- A **twist** is an Elite's rule: Cold Sixes, Cold Hands, First Throw, Greedy Pot, Heavy Toll
  and Short Table.
- A **cheat** is a boss's own rule, named after the boss: Madame Shuffle, The Pit Boss, The
  Collector, The Bloodletter, Ashmouth and The Straight Man.
- Each floor's `.tres` lists which twists and bosses it can draw. The table enforces the rules
  (handlers in `scripts/core/rules/`).

## Look and feel

The setting is a toon-noir infernal casino. Dice show their state with glow only, never fire.
Art direction is in [ARCHITECTURE.md](ARCHITECTURE.md#art-direction).
