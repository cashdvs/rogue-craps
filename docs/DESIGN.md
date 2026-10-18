# Dice of the Damned: design summary

A short public summary of the game design, written for contributors. The full living design and
art documents are maintained by the Tiny Anvil team; if an issue needs a number or detail that
isn't here, it will quote it. All numbers are first-pass placeholders, and the numbers the game
actually uses live in `resources/tuning/poc_tuning.tres`.

> **Hook:** Roll your way out of an infernal casino. Rig your dice, unlock crooked bets, and beat
> the Dealers who cheat right back.

Single-player craps roguelite, PC first (mouse and keyboard), made in Godot 4.7.2.

## Pillars

- **No relics.** Power comes only from **dice faces**, **new or better dice**, and **unlocked
  bets**.
- **Every table has a rule that disrupts play** (for example *Hot Seven*: a Seven-out deals
  double Soul damage).
- **Soul is your HP.** It burns during play and only comes back at specific places on the map.
- **You win the run by beating the final Dealer.**
- **Fair dice lose slowly.** With fair dice every bet has a small house edge, like a real casino.
  Your edge comes only from your dice: you beat the house by cheating.

## Core loop

1. Enter a **table**: your stake moves from your purse into the table's **bankroll**.
2. Before each come-out roll, **bet** from the bankroll (Floor 1: 5 to 25 Coin).
3. **Throw** the dice. Resolve the bets, then collect or lose Coin. Bad rolls burn **Soul**.
4. Reach the table's **Coin target** within the **roll limit**, or take a Soul penalty.
5. Between tables (planned): a branching floor map with shops, events, rests and altars, where
   you spend Coin on bets, dice and face mods. Each of the 3 floors ends with a Dealer boss, and
   then comes the Final Table.

## Craps rules (Pass Line)

- **Come-out roll:** 7 or 11 is a **Natural** (win). 2, 3 or 12 is **Craps** (lose). Any other
  total (4, 5, 6, 8, 9, 10) becomes the **Point**.
- **Point phase:** roll the Point again to win (**Point hit**), or a 7 to lose (**Seven-out**).
  The Pass bet is locked while a Point is on.
- **Odds:** an add-on behind Pass, only while a Point is on, capped at 2× the Pass bet. Pays true
  odds (2:1 on 4/10, 3:2 on 5/9, 6:5 on 6/8).
- If the rolls run out with a Point still open, the Pass bet is **returned** (a push).
- Pass wins about 49.3% of the time (1.41% house edge at 1:1).

## Coin and Soul

- **Coin** is money. The **purse** is what you carry between tables; the **bankroll** is what's on
  the current table. At the end of a table the whole bankroll goes back to your purse.
- **Soul** is health. The run ends when it hits 0. Damage during play:
  - **Seven-out:** 2 Soul + 1 per 10 Coin lost on that roll, rounded up.
  - **Craps on the come-out:** 1 Soul + 1 per 10 Coin lost, rounded up.
  - **Any other losing roll:** 1 Soul per full 10 Coin lost.
  - A roll where you lost nothing costs no Soul. Wins never restore Soul.

## Table goal

- **Floor 1 table:** stake 20 Coin, **target bankroll 40**, **12 rolls**.
- **Hit the target:** +5 Coin clear bonus, plus 1 Coin per unused roll.
- **Miss the target:** a final Soul penalty of 3 + 1 per 25% of the gap (max 7).
- **Go bust** (bankroll 0): the table ends immediately with the max penalty of 7.
- The target should feel reachable but usually just out of reach: betting 10 on Pass every
  decision hits +20 in 12 rolls about 22% of the time.

## Proof-of-concept scope (what's being built now)

Goal: prove that the roll and the table cycle **feel** good.

- One table with **2 plain fair dice**, **Pass Line** (plus Odds), Soul, a 12-roll limit and the
  Coin target above. 40 Soul.
- **Throw by mouse:** grab the dice, drag and flick. The seeded `DiceRoller` decides the result
  at release, and the animation (2D now; a top-down 3D physics table is in progress) lands on it.
- A **taunting Dealer** with short text-bubble lines on natural, craps, Point set, Point hit,
  seven-out, big bets and low Soul.
- Juice: tumble and impact, a suspenseful reveal, punchy payout and loss feedback, the Soul burn.
  Click to fast-forward; a reduced-motion option.
- A result screen, then **Next Table** (Soul carries over); 0 Soul shows a run-over screen.
- Debug: a seed input and a "force the next roll" toggle (F1).
- **Out of scope for the POC:** dice selection, rarities, abilities, drawbacks, face mods,
  sacrifice, table rules (Hot Seven exists but ships off), the shop and the map.

## Planned systems (designed, not built)

- **Bets** unlocked in the shop: Field, Any Craps, Any Seven, Yo, Snake Eyes / Boxcars, Hard ways,
  Don't Pass.
- **Dice** in rarity tiers (Bone → Mischievous → Devilish → Satanic): every non-Bone die has a
  clear upside and a clear drawback, both bigger at higher rarity. A **dice bag** holds 2 dice at
  first, with more slots later.
- **Face mods** (Pip Shift, Loaded, Gold, Glass, Warded, Wild, Cursed).
- **Table rules** such as Cold Table, Crooked Dice, Short Stack, House Rake and Snake Pit.
- **Floor map** with Tables, High-Stakes and Elite tables, Shop, Event, Rest and Altar nodes.
  Stakes, targets and bet caps rise each row and each floor.
- **Dealer bosses** that stack table rules plus a signature rule, and a Final Table.
- **Embers** (light meta-progression) earned per run.

## Visual style (short)

Stylized, toonish, moody casino ("the Underhouse"): oxblood walls, teal-black felt, ember lamps,
bone-ivory dice and brass UI. **Soul-Flame cyan `#4FE6E0` is reserved for Soul** (health and
soul effects) so it always reads as "you"; don't use it for anything else.
