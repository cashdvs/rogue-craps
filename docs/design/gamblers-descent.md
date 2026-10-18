# The Gambler's Descent: Design Doc v0.5

**Hook:** Roll your way out of an infernal casino. Rig your dice, unlock crooked bets, and beat the Dealers who cheat right back.

Single-player craps roguelite in Godot, PC first. It combines Balatro-style engine building with Slay the Spire-level difficulty. All numbers are first-pass placeholders. The starter-table numbers come from a 200k-run simulation (§4), and the economy numbers come from a 50k-run sim (§3b). v0.4 is archived at `gamblers-descent-v0.4.md`, v0.1 at `gamblers-descent-v0.1.md`.

**What changed in v0.5:** Embers (a run-long shop currency) replace the carried Coin purse; Coin now resets every table. Added a 5-dice bag with a pre-table loadout, bet slots and a repeat-by-default bet flow, invented bets, 12 Exotic Dice, the 4 face-mod types (no mod limit), the new map stops, boss pools, feat-based meta unlocks (Heat removed), and POC 2 (§12b).

**Locked pillars (from Cash):**
- No relics. Power comes only from **dice faces**, **new or better dice**, and **unlocked bets**.
- Every table has a rule that disrupts play.
- **Soul** works like HP. It burns during play and only comes back at specific nodes.
- **Embers** are the only money that lasts between tables. Table Coin resets every table.
- One difficulty, and it's hard. You win the run by beating the final Dealer.

---

## 1. Run Structure
- **Story frame:** your soul contract was torn into 3 pieces, and each floor's Dealer holds one.
- **Structure:** 3 floors. You gamble through regular tables to reach each floor's Dealer boss, and beating a Dealer wins back **1 contract piece**. Each floor's Dealer is drawn from a pool of 3 and shown at the top of the map from the start (§10).
- **Finale:** after the 3rd Dealer, the **Final Table** against the Devil (the Pit Boss Below). Beating him wins the run.
- **Length:** about 4 regular tables per floor, so about 16 gambling tables per run (12 regular, 3 Dealers, 1 final) and a 35–45 minute run. Map details are in §9.
- **Start:** 50 Soul, **0 Embers**, a **dice bag** holding up to 5 (you start with **2 Bone dice**, chosen from 3 offered), 3 bet slots with only **Pass** unlocked.
- **The run ends** when Soul hits 0.

**Parked: Opening Bargain (to explore after the next POC).** The run starts with 2 dice (the bag holds up to 5). Before row 1, a special **Devil's Deal** offers one trade, for example a cursed die that's better at something in exchange for Soul, or trading in both starters for one stronger die. No deep spec yet; it would use the Devil's Deal stop (§9).

## 2. Table Rules
- **Coin resets every table.** You sit with a fixed **stake** of table Coin (Floor 1: 20), which becomes your **bankroll**. All bets come out of the bankroll. When you leave, the table's Coin is gone; only Embers carry over (§3).
- **Roll limit:** Floor 1 tables allow 12 rolls.
- **Target:** the bankroll you must reach. On Floor 1 the target is the stake + 20 (40). Targets and stakes scale up each floor (§9).
- **Clear:** the table **clears the moment your bankroll reaches the target** with no Point open (the clear is locked in from then on). You then choose:
  - **Cash Out:** leave now and collect Embers.
  - **Let It Ride:** keep throwing your remaining rolls for surplus Embers. Dropping back under the target can't un-clear the table, but losing rolls still burn Soul.
- **Miss the target** (rolls run out first): a final **Soul penalty** of 3 + 1 per full 25% of the gap, measured against the target (max 7). Ending on 20 of 40 is a 50% gap, so 5 Soul.
- **Go bust** (no bet on the felt and the bankroll can't cover a 1-chip Pass): the table ends immediately with the max penalty of 7.
- **Craps flow:**
  - **Come-out roll:** 7 or 11 is a Natural, which wins. 2, 3, or 12 is Craps, which loses. Any other sum becomes the **Point**.
  - **Point phase:** roll the Point again to win, or a 7 to lose (Seven-out).
  - A Pass bet still unresolved when rolls run out is **returned** (a push).
- **Bet size:** set in chips per bet slot, up to the table cap per bet (Floor 1: 25). Bets repeat by default (§5b). Bigger bets reach the target faster but hurt Soul more.

## 3. Soul (HP) and Embers (shop currency)
### Soul
**Damage during play** (U = half this table's stake, which is 10 Coin on a 20-Coin table):
- **Seven-out:** 2 Soul plus 1 per U lost on that roll, rounded up.
- **Craps on the come-out:** 1 Soul plus 1 per U lost, rounded up.
- **Any other losing roll:** 1 Soul per full U lost (so small one-roll losses are free).
- **Missing the target or going bust:** the final penalty in §2.

*Why U scales (new in v0.5):* stakes grow about ×2.2 per floor, so a flat "per 10 Coin" rule would make every Floor 3 Seven-out cost 10+ Soul. The sim (§3b) shows that with the flat rule, fair-dice runs that survive Floor 2 almost never survive Floor 3 (for example 0.5% vs 5.5% reach the Final Table, cautious greedy route). On a 20-Coin table the two rules are identical, so POC 1 is unaffected.

**Simulated cost:** on Floor 1 with fair dice, a regular table costs about 7.1–8.7 Soul and an Elite about 8.6–10.9, depending on bet style (§3b).

**Restoring Soul (only these):**
- **The Lounge:** heal 30% of max Soul.
- **Soul Marks** on dice faces (§8), capped per table.
- Certain **Mystery Door** events and **Side Games**.
- **Altar sacrifice** (§7b).
- **Dealer kill:** the contract piece restores 15 Soul and adds +5 max Soul (proposed; see §9).

Max Soul can rise only through Dealer kills and events.

### Embers
Embers persist through the run and are spent at Shops (and a few stops). Table Coin never converts to Embers except through the surplus bonus below.

| Table result | Embers |
|---|---|
| **Clear a regular Table** | 10 + surplus bonus |
| **Clear a High-Stakes Table** | 12 + surplus bonus (plus its guaranteed face mod or bet unlock) |
| **Clear an Elite Table** | 15 + surplus bonus (plus its die pick) |
| **Beat a Dealer** | 30 + surplus bonus (plus the contract piece) |
| **Miss a regular, High-Stakes, or Elite table** | **3** ("pity chips") |
| **Miss a Dealer** | 0, and you must sit again (§10) |

- **Surplus bonus:** +1 Ember per full 25% of this table's stake that your final bankroll ends above the target, max +10. On Floor 1 (stake 20) that's +1 per 5 Coin of surplus; on Floor 3 (stake 100) +1 per 25 Coin, so it scales with the floor automatically.
- **Why 3 for a miss (not 0):** with fair dice about 70% of tables are missed. With a 0 payout, the sim shows a quarter of players reaching the first Shop with **0 Embers**, and the median "balanced" player has 0 there. With 3, the p25 rises to 6 and the median to 6, and the typical pre-boss total rises from 14 to 23 (balanced, §3b). It softens the death spiral without making missing attractive (a clear is still worth 10+).
- **No interest, no Vig, no clear bonus in Coin, no House fronting.** Those belonged to the old carried purse.

## 3b. Run Economy Sim (fair dice = the floor case)
Script: `/workspace/dice/sim/economy_sim.py` (full output in `sim/results_v05.txt`, seed 7). 50,000 full runs per configuration plus 100,000 single tables per row type.

**What it models:** two plain fair d6, Pass only, the §2 table rules, the §3 Soul rules (scaled U), the §9 escalation (×1.1 per row, High-Stakes ×1.5 stake/target/cap, Elite +3 miss penalty), Embers as above, Dealer re-sits on a miss, +15 Soul/+5 max per Dealer, Lounge at row 6 if Soul is under 60% of max (otherwise Shop). **What it doesn't:** table rules, dice abilities, face mods, Ember spending, other bets. **Treat it as the no-build floor case;** real runs should do better because building is the whole game. Because stake, target, and cap scale together, the fair-dice game is the same at every table type; the real difference between Table, High-Stakes, and Elite comes from their rules, which aren't simulated.

**Profiles:** *cautious* = Pass at 40% of the cap (10 on Floor 1), cash out on clear. *balanced* = 60% of the cap (15), cash out on clear. *aggressive* = bet the cap (25), let it ride until surplus reaches 100% of the stake.
**Route:** "greedy" = r1 Table, r2 Table, r3 Shop, r4 High-Stakes, r5 Elite, r6 Lounge-or-Shop, r7 Dealer. "Safe" swaps r4/r5 for regular Tables.

**Per table, Floor 1 (100k tables each, no Soul death):**

| Profile | Type | Clear % | Avg Embers (miss pays 3) | Avg Soul lost |
|---|---|---|---|---|
| cautious | Table / High-Stakes / Elite / Dealer | 30.6 / 30.7 / 30.2 / 30.3 | 5.14 / 5.76 / 6.62 / 9.09 | 7.63 / 7.60 / 10.68 / 8.57 |
| balanced | Table / High-Stakes / Elite / Dealer | 27.6 / 27.5 / 27.3 / 27.4 | 5.48 / 6.02 / 6.81 / 8.51 | 8.72 / 8.71 / 10.92 / 8.73 |
| aggressive | Table / High-Stakes / Elite / Dealer | 48.4 / 48.3 / 48.7 / 48.5 | 7.66 / 8.61 / 10.10 / 15.81 | 7.09 / 7.11 / 8.57 / 7.06 |

(Dealer Embers count only clears; a missed Dealer pays 0 and you sit again.)

**Full runs, greedy route, miss pays 3:**

| Profile | Embers earned per floor (F1 / F2 / F3) | Survive F1 / F2 / F3 / win | Chose Lounge at F1 row 6 |
|---|---|---|---|
| cautious | 54.3 / 57.4 / 57.5 | 59.5% / 18.5% / 5.5% / 2.9% | 77.7% |
| balanced | 57.5 / 60.3 / 60.6 | 51.7% / 16.6% / 5.2% / 4.3% | 75.4% |
| aggressive | 67.4 / 70.5 / 71.0 | 86.2% / 51.1% / 29.2% / 23.5% | 82.5% |

**Cumulative Embers on arrival at each Shop (median, greedy route, miss pays 3):**

| Stop | cautious | balanced | aggressive |
|---|---|---|---|
| F1 mid-shop (r3) | 13 | 6 | 13 |
| **F1 pre-boss (r6)** | **21** | **23** | **33** |
| F2 mid-shop | 64 | 69 | 83 |
| F2 pre-boss | 82 | 87 | 106 |
| F3 mid-shop | 123 | 130 | 155 |
| F3 pre-boss | 141 | 148 | 179 |
| Contract Room | 172 | 181 | 212 |

(Medians among runs still alive at that stop. Means for F1 pre-boss: 23.6 / 25.6 / 34.1. The safe route earns less: F1 pre-boss medians 19 / 21 / 31.)

**What you can afford by each shop (prices in §5, §7, §8):**
- **F1 mid-shop (6–13):** one Swap (10), or save.
- **F1 pre-boss (21–33): the tuning target.** One cheap bet unlock + one first mod (Field 12 + Swap 10 = 22), **or** one Mischievous die (25). The aggressive median (33) affords a bit more, such as Field + Burn (27).
- **F2 pre-boss (82–106):** one Devilish die (55) plus a mod or bet, or 3–4 mods spread over two dice.
- **Contract Room (172–212):** a full Shop visit: about 3–5 purchases.
- Rough run total for a survivor: about 170–210 Embers, enough for about 8–12 purchases. That should feel like a Balatro run: every Shop is a real choice, never a shopping spree.

**Sim findings that need design attention (see §9 flags):**
1. **Betting the cap beats careful play.** Aggressive clears 48% of tables vs 31% for cautious, and loses less Soul per table (7.1 vs 7.6). At 25, the Floor 1 cap is larger than the stake, so one all-in Pass win (49%) clears the table. A what-if run with the cap cut to 60% (15 on Floor 1, `--cap-scale 0.6`, 100k tables) gives 27.6% clears for cap-betting and 5.0% for a 6-Coin bettor.
2. **Dealer re-sits are the biggest Soul drain.** Floor 1 Dealers were sat about 2 times per run (99,501 sits in 50,000 cautious runs).
3. **The pre-boss Shop is usually skipped.** About 75–83% of fair-dice runs arrive at row 6 under 60% Soul and pick the Lounge, so the r3 Shop is the reliable one.
4. **Fair-dice win rate is not zero.** Aggressive no-build runs win 23.5% (greedy) without any table rules. Rules and boss signatures are what should pull that down; we need to re-run once rules are in the sim.

## 4. Probability and Payouts (2d6, fair dice)
| Sum | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Ways /36 | 1 | 2 | 3 | 4 | 5 | 6 | 5 | 4 | 3 | 2 | 1 |

- **Pass:** wins 244/495 ≈ 49.3% (1.41% house edge at 1:1). On the come-out it's 8/36 win, 4/36 lose, and 24/36 set a Point. The chance to make the Point is 3/9 for 4 or 10, 4/10 for 5 or 9, and 5/11 for 6 or 8.
- **Rule:** with fair dice, every bet is slightly negative, like a real casino. The player's edge comes *only* from dice and face mods. That's the fantasy: you beat the house by cheating.
- **Simulation:** 200k runs of Pass 10 per decision over 12 rolls give these chances of finishing with a net gain:
  - +20 or more: 22% (25% if you add a 5-Coin Field bet each roll)
  - +30 or more: 10% (15% with the Field bet)

  That's why the Floor 1 target is the stake + 20.

## 5. Bets (unlocked in the Shop, permanent for the run)
- **How you get them:** each Shop offers **1–2 random bets** from the pool. Bets you already own never appear. Once bought, an unlock lasts the rest of the run. Owning a bet doesn't place it; you load it into a slot before each table (§5b).
- **Pool (Cash's list):** Field, Snake Eyes, Hardways, Any Craps, Odds, Don't Pass. The invented bets below are a proposal to add to the pool, unlocked over time by feats (§11).
- All edges are exact for fair 2d6 (`/workspace/dice/sim/bet_edges.py`).

| Bet | Type | Wins on | Pays | House edge | Unlock (Embers) |
|---|---|---|---|---|---|
| **Pass** | Line | Pass rules | 1:1 | −1.41% | Starter |
| **Field** | One roll | 2,3,4,9,10,11,12 (16/36) | 1:1; 2 pays 2:1, 12 pays 3:1 | −2.78% | 12 |
| **Any Craps** | One roll | 2, 3, 12 (4/36) | 7:1 | −11.11% | 12 |
| **Snake Eyes** | One roll | 2 (1/36) | 30:1 | −13.89% | 15 |
| **Odds** (behind Pass, up to 2× the Pass bet) | Point add-on | Point before a 7 | True odds (2:1 / 3:2 / 6:5) | 0% | 15 |
| **Hardways** (one unlock = all four) | Stays up, Point phase only | The pair before a 7 or the easy version | Hard 6/8 9:1; Hard 4/10 7:1 | −9.09% / −11.11% | 18 |
| **Don't Pass** | Line | Reverse of Pass; 12 is a push | 1:1 | −1.36% | 20 |

*Parked (not in Cash's pool):* Any Seven (4:1, −16.7%), Yo (15:1, −11.1%), Boxcars (30:1, −13.9%). They can come back as invented-bet variants later.

**Invented bets** (they don't follow real craps; slightly favorable ones carry a real cost):

| Bet | Win condition | Pays | Edge (fair dice) | Unlock | Synergy |
|---|---|---|---|---|---|
| **Devil's Number** | One roll. At each table start a number is drawn from 2–12 (never 7) and shown on the felt; win if the sum is exactly that. | By rarity: 2/12 30:1, 3/11 15:1, 4/10 10:1, 5/9 7:1, 6/8 5:1 | −8.33% to −16.67%; −12.22% averaged over draws | 16 | Swap and Burn steer sums (two 1-faces make Snake Eyes 2/36), Marble Eye's Peek, Severed Hand, Tooth (low draws) |
| **Streak** | Rides on each Pass decision; pays by wins in a row including this one | 1st win 1:2, 2nd 1:1, 3rd 2:1, 4th+ 3:1; any loss resets | **+3.97%** | 20 | Pass-boosting dice: Hellbent, Splitter, Horned d4, d13. **Cost:** a Seven-out while Streak is up costs +1 Soul; Velvet Widow's rule also hits streak play |
| **Blood Bet** | Rides on Pass; stake 1–3 **Soul** instead of Coin | Win: 5 Embers per Soul staked; lose: the Soul is gone; push: returned | Not a Coin bet: per Soul staked, +2.46 Embers and −0.507 Soul, so about **4.86 Embers per Soul lost** | 22 | Late-run Ember farming with a strong Pass build and spare Soul. Altars sell Soul back at about 2.5 Embers per Soul (Bone: 10 Embers for 4 Soul), so this is the "spend Soul for power" valve |
| **Mirror** | One roll: any pair | 4:1; 1-1 or 6-6 pays 6:1 | −5.56% | 14 | Mirror Imp (copies faces), The Ninth Circle, Hardways builds. Countered by Doubles Tax |
| **Hedge** | Point phase only, one roll: a 7 | 3:1, and halves that Seven-out's Soul damage | −33.33% in Coin | 10 | A Soul shield, not a money bet. Hot Seven tables, The Collector, Black Moon, low-Soul runs |
| **High Side / Low Side** (pick a side when loading) | One roll. High: 8–12. Low: 2–6 | 1:1; High 11/12 and Low 2/3 pay 2:1 | −8.33% | 12 | High: Leadfoot, Candle Die, Swap-up builds. Low: Tooth (sums 2–9), Knucklebone, Horned d4, Burned high faces |
| **Sinner** | One roll: an odd sum other than 7 (3, 5, 9, 11) | 2:1 | **0.00%**, but a rolled 7 also costs 1 Soul | 14 | Dice that dodge 7: Two-Face Coin (can't roll 7), Mirror Imp, Horned d4's Gore |

**Balance watch:** face mods turn long shots positive very quickly. One die with two 1-faces makes Snake Eyes 2/36, which is +72% EV at 30:1. The Tooth Die alone makes it 2.33/36. That's intended to be the build payoff; Snake-Eye Sal (§10) and Banned Bet (§6) push back.

## 5b. Bet Slots & Bet Flow
**Slots (the build constraint).** You have a capped number of bet slots, and **Pass always takes one**.
- **Recommendation: 3 slots (Pass + 2) at the start, +1 for beating each of the first two Dealers, for a max of 5.** The 3rd Dealer gives no slot, because the Final Table comes right after it.
- **Why:** the slot cap is the build constraint, like Balatro's joker slots. Unlocks grow faster than slots (a typical run buys 3–6 bets), so you must choose which bets fit this table's rules and your dice. Five slots still fit one row on a phone. A slot from each Dealer also makes the boss reward feel physical. (PM leaned toward 3 + 1 per boss = up to 6; open question §13.)
- Slots can't be bought, so Embers can't skip the constraint.

**Loading (pre-table loadout, §7a).** Before each table you drag unlocked bets into your slots on the same screen where you pick 2 dice. Empty slots are allowed. The loadout is remembered between tables.

**Chips.** One chip = the floor's bet cap ÷ 5, rounded to the nearest 5: **Floor 1: 5 Coin, Floor 2: 10, Floor 3: 25, Final: 60.** Each bet holds up to "cap ÷ chip" chips (Floor 1: 5 chips = 25). Pass needs at least 1 chip. As caps rise 10% per row inside a floor, the chip stays fixed and the max chip count rounds down.
- **PC:** click a slot to add a chip, right-click to remove one. Shift-click adds or removes 5.
- **Mobile:** tap to add, long-press or swipe down on the slot to remove one. Swipe up fills it to the max.

**Repeat by default.** Your bets stay as set, so you can just keep throwing.
- **One-roll bets** (Field, Any Craps, Snake Eyes, Devil's Number, Mirror, High/Low Side, Sinner, Hedge) re-place automatically after every roll, win or lose.
- **Multi-roll bets** (Pass, Don't Pass, Odds, Hardways, Streak, Blood Bet) re-place when they resolve. Hardways that win or lose re-place at the next Point.
- **Bankroll can't cover the repeat:** bets are funded in slot order (Pass first, then left to right). A bet that can't get its full chips gets as many as remain. A bet that can't get 1 chip sits out greyed for that throw. If Pass can't get 1 chip and nothing is on the felt, you're bust (§2).
- **Blood Bet** never auto-repeats if it would take you to 10 Soul or less; you have to re-arm it by hand.
- Repeats never exceed the bet cap. Rule changes such as High Roller raise chips to the new minimum if the bankroll allows.

**Come-out vs Point phase.**
- When a Point is set, the felt **highlights the bets you can change right now**: Odds opens (up to 2× Pass), Hardways turn on, and Hedge becomes available. One-roll bets stay adjustable between every throw.
- **Locked during the Point phase:** Pass, Don't Pass, Streak, and Blood Bet (they ride until the Point resolves). Odds can be added or raised, not removed.
- **Off on the come-out:** Odds, Hardways (chips stay but don't work), and Hedge.

**Pace target: one throw every 2–3 seconds,** like Balatro's hands.
- **Default reveal ≤ 1.5 s** from release to result: dice settle in about 0.8 s, each die locks in turn, the result banner shows at about 1.0 s, and the bankroll counts during the banner. Big moments (Point hit, Seven-out, clear) may run to 2.5 s.
- **Speed toggle:** 1× / 2× / Instant, plus hold-to-throw repeat (keep throwing with the same bets while the button is held, stopping on any Point set, Point resolved, or clear).
- **For the POCs:** POC 1's reveal should hit the 1.5 s default and get the speed toggle. POC 2 needs repeat-by-default from day one.

## 6. Table Rules (each normal table rolls one; High-Stakes and Elite tables roll two)
1. **Cold Table:** 6s count as 1s. (7 becomes rarer and 2 becomes more common, so Any Craps and Snake Eyes get stronger.)
2. **Crooked Dice:** before each roll, a random face on one of your dice is shifted −1 for that roll.
3. **Banned Bet:** your most-used bet other than Pass can't be placed at this table (its slot is locked).
4. **Hot Seven:** a Seven-out deals double Soul damage.
5. **Short Stack:** the roll limit is −4, but the target is −25%.
6. **House Rake:** 1:1 bets pay 4:5.
7. **Tithe:** every roll costs 1 Coin from the bankroll before betting.
8. **Snake Pit:** on the come-out, a 2 counts as a Seven-out (Soul damage included) instead of Craps.
9. **Dead Pips:** your dice abilities are disabled for the first 4 rolls.
10. **High Roller:** the minimum bet equals the table cap.
11. **Blind Felt:** the Point isn't shown after it's set; you have to remember it.
12. **Doubles Tax:** each pair you roll costs 1 Soul (this works against Hard-way builds).

## 7. Dice
**Rarities:** **Bone** is the normal starter tier: plain or lightly improved dice with no drawbacks. Above it are three themed tiers: **Mischievous → Devilish → Satanic**.
- **Swing rule:** every non-Bone die has a clear upside **and** a clear drawback, and the rarer the die, the bigger both get.
  - Mischievous: small edge, small cost.
  - Devilish: strong edge, a cost that can hurt.
  - Satanic: run-defining edge, a cost that can end a run.
- **Fair-partner note:** if the other die is a fair d6 and this die only shows 1–6, a sum of 7 always comes up 1/6 of the time, whatever you do to this die. So dice that boost Naturals do it with an ability, or with faces outside 1–6 (§7c).
- **No mod limit:** any die can carry any number of face mods (§8). Rarity no longer sets mod slots.

| Rarity | Shop price (Embers) | Sell value (~40%) | Shop odds F1 / F2 / F3 | Sacrifice: Soul value |
|---|---|---|---|---|
| **Bone** (normal) | 10 | 4 | 40% / 20% / 10% | 4 |
| **Mischievous** | 25 | 10 | 45% / 50% / 45% | 8 |
| **Devilish** | 55 | 22 | 15% / 30% / 45% | 14 |
| **Satanic** | Not sold: Elite/Dealer reward only | 40 | — | 22 |

**Leveling:** you can level a die three times (Lv2/3/4) in the Shop, at the Lounge, or through sacrifice, for 10/20/35 Embers. Levels strengthen the upside; drawbacks don't scale with level.

**Example dice:**

**Bone (normal, no drawback)**
- *Plain Bone:* no ability. It's cheap and a blank canvas for face mods.
- *Leadfoot:* its 6-face is Loaded (lands twice as often).
- *Lucky Knuckle:* the first Seven-out each table deals 0 Soul.

**Mischievous (small swing)**
- *Imp's Knuckle:*
  - Upside: reroll this die once per table (+1 reroll per level).
  - Drawback: each reroll costs 1 Soul.
- *Mirror Imp:*
  - Upside: 2 in 6 chance to copy the other die's face (3 in 6 at Lv3), which feeds Hard ways and avoids 7s during the Point phase.
  - Drawback: it also copies on the come-out, so you roll fewer Naturals. A pair can never sum to 7 or 11.
- *Cinder Die* (renamed from "Ember Die" so it isn't confused with the currency):
  - Upside: +1 Coin per pip shown when you win a Natural (+1 per level).
  - Drawback: its 1-face is "Scald," dealing 1 Soul whenever it shows.

**Devilish (big swing)**
- *Hellbent Die* (Cash's 7/11 example):
  - Upside: on the come-out, a 6 or 8 shifts to 7, so Naturals go from 8/36 to **18/36 (50%)**.
  - Drawback: its 1-face is "Brimstone," dealing 2 Soul whenever it shows, about 4 Soul per 12-roll table.
- *Forked Die:*
  - Upside: rolls twice, and you keep either result.
  - Drawback: if both rolls match (1 in 6), you take 3 Soul.
- *Gilded Fang:*
  - Upside: on a 6, all winning bets that roll pay ×1.5.
  - Drawback: on a 1, all losing bets that roll lose ×1.5, and the Soul damage scales with them.

**Satanic (run-defining swing)**
- *Pact Die:*
  - Upside: before any roll, you can set its face.
  - Drawback: each use costs 2 Soul, and your max Soul is −5 while you own it.
- *The Ninth Circle:*
  - Upside: any pair rolled with this die triples all payouts on that roll.
  - Drawback: a pair of 1s or 6s is "Damnation," and you lose half your bankroll.
- *Devil's Due:*
  - Upside: all winning bets pay ×2.
  - Drawback: all Soul damage is ×2, including the target-miss penalty.

## 7a. Dice Bag & Pre-Table Loadout
- **Bag:** you hold **up to 5 dice**. Before every table you **bring 2** of them. This replaces the old "hold 2 dice" model. You can never go below 2 dice.
- **Bring 3 (shop upgrade, 60 Embers, once per run):** you may bring 3 dice to a table, roll all 3, and keep any 2 after seeing them. It's the old 3rd-die idea, now an upgrade on top of the bag. Open question (§13): it may be too strong as a flat upgrade.
- **Loadout screen** (opens on entering any table node; it's also where you load bets, §5b):
  - **Top:** the table's name and type, its rule(s) as plaques, stake, target, rolls, bet cap and chip size, the reward (Embers base, plus any die pick or guaranteed mod), and the floor's boss icon.
  - **Middle, the bag:** 5 die cards. Each shows the die (3D turntable), its rarity, level, face strip (every face with its mods), a one-line **odds summary** when paired with a fair d6 ("Nat 25% · Craps 8% · Pass 54%"), and its **drawback in red**. Dice that this table's rules hurt get a warning icon (for example Dead Pips on an ability die).
  - **Bottom, the felt strip:** 2 dice sockets (3 with Bring 3) and your bet slots. Drag dice into sockets and owned bets into slots. Chips can be pre-set here.
  - **Confirm** ("Sit Down") is disabled until 2 dice are socketed. The last loadout is pre-filled, so a repeat loadout is one tap.
  - **Mobile:** portrait layout with the rules and reward card on top, the bag as a horizontal carousel of die cards (tap to socket, tap again to remove), the sockets and slots pinned above the thumb zone, and Confirm as a full-width bottom button. Long-press a die card for its full odds and face sheet.
- **Bag full when you gain a die:** a "Bag Full" prompt shows the new die next to your 5. Choose one:
  - **Sell** any one die (new or old) for its sell value: Bone 4, Mischievous 10, Devilish 22, Satanic 40 Embers. Face mods add nothing to the sell price.
  - **Pocket sacrifice** any one die for **half** its Altar Soul value (2 / 4 / 7 / 11 Soul), no empower. **Limit: one pocket sacrifice per floor.**
  - **Sacrifice at full value** if you are standing at an Altar (that uses the Altar's one sacrifice).
  - **Discard** either die for nothing.
- **Bosses that confiscate or disable dice** (Madame Shuffle, The Collector, the Devil) now hit the **loadout**, not the whole bag. That's the counterplay: you see the boss from the start of the floor and can bring decoys or spread power across dice.

## 7b. Sacrifice (at Altars)
At an Altar you can destroy one die per visit (the bag can't drop below 2 dice). Choose **one** reward:
- **Restore Soul**, based on the sacrificed die's rarity.
- **Empower** another die. **Rule:** the target must be the **same or lower rarity** than the die you sacrifice. Any die in your bag can be the target.

| Sacrificed die | Restore Soul | Or empower a target (same or lower rarity), choosing one |
|---|---|---|
| **Bone** | 4 | +1 level, **or** one free Swap mod |
| **Mischievous** | 8 | +1 level, **or** one free mod of any type, **or** move all its face mods onto the target |
| **Devilish** | 14 | +2 levels, **or** two free mods, **or** move its mods |
| **Satanic** | 22 | **Purge** the target's drawback permanently, **or** +2 levels and two free mods, **or** move its mods |

"Free" mods ignore the escalating price (§8) but still count toward the target's mod count for later purchases.

**Soul budget check with a 5-dice bag:** a bigger bag is more sacrifice fodder, so the limits are one sacrifice per Altar, Altars at about 10% of non-table stops (§9), and one half-value pocket sacrifice per floor. The realistic ceiling is about one Altar plus one pocket sacrifice per floor. Spent on Bone dice that's 6 Soul per floor for 20 Embers of dice (2.5 Embers per Soul at an Altar, 5 for a pocket sacrifice). **Watch the loop:** Blood Bet turns Soul back into about 4.9 Embers per Soul lost, so a 10-Ember Bone sacrificed for 4 Soul can come back as about 19 Embers. One sacrifice per Altar caps it, so it's a fine combo, not an engine; cut Blood Bet's payout to 4 Embers per Soul if testers farm it. Spending your Mischievous/Devilish dice on Soul is a real trade-off against power. Fair-dice tables cost 7–9 Soul each, so sacrifice can top up a run but can't fund one.

Design intent: the Altar is the "late-run" decision. You can trade a swingy die you found for safety (Soul), or sacrifice a die you've outgrown to make your main die better. Purging a drawback with a Satanic die is the rarest and most valuable outcome.

## 7c. Exotic Dice (non-d6)
Built on the Art Director's concept (`art/concept/dice_rarities.md`, "Creative dice"): the same names, shapes, and printed values. Results are seeded with the late label remap, so face weights are a design choice, not physics. All odds are exact, for **this die paired with one plain fair d6**, from `/workspace/dice/sim/exotic_odds.py` (output in `sim/exotic_odds_results.txt`). Baseline: **Nat 8/36 (22.2%), Craps 4/36 (11.1%), Point 24/36 (66.7%), Pass win 49.3%.**

**Rules for faces outside 1–6:**
- **Snake Bite (sum of 1 or less):** counts as Craps on the come-out. In the Point phase it's no decision. It counts for Any Craps; it loses every other one-roll bet.
- **Overdraw (sum of 13 or more):** counts as a Natural on the come-out. In the Point phase it's no decision but burns Soul equal to the sum − 12. It loses every one-roll bet except High Side.
- **Points** are still only 4, 5, 6, 8, 9, 10. **Pairs and Hard ways** need both dice to show the same value from 1–6; a 0, 7, 8, or 13 can never pair.

| Die | Tier | Faces | Upside | Drawback | Nat / Craps / Point (/36), Pass win |
|---|---|---|---|---|---|
| **Knucklebone** | Bone | 1, 3, 4, 6 (even odds) | *Lucky Bone:* the first Craps each table deals 0 Soul. | None (Bone). Slightly worse at Pass; can't make Hard 10. | 7.50 / 4.50 / 24.00, **47.8%** |
| **Tooth Die** | Bone | 1–3 | Low sums (2–9) feed Low Side, Any Craps, and Snake Eyes (2.33/36, vs 1/36 fair). *Bite:* 1 in 12 throws it stands on its roots and you pick its face (1, 2, or 3). | None (Bone). Can't make 10, 11, or 12. | 7.00 / 5.50 / 23.50, **53.6%** (47.5% without Bite) |
| **Two-Face Coin** | Mischievous | 0 or 7 | It adds normally, so a total of 7 is impossible: **you can never Seven-out.** Pass wins 66.7% of the decisions it finishes. | Craps triples (sums 1, 2, 3, 12). Points are slow (1/12 per roll), so 86% of tables end with a Point still open and returned. Per 12-roll table: 1.26 Pass wins vs 1.84 fair. Odds and Hardways can't be loaded with it. | 6.00 / 12.00 / 18.00, 66.7% per finished decision |
| **Marble Eye** | Mischievous | 1–6 | *Peek:* during betting, the pupil looks at the face it will roll next, so you size bets knowing it (Pass win ranges from 41.7% on a peeked 1 to 66.7% on a peeked 5). | *Glare:* each peeked 1 costs 1 Soul. | 8.00 / 4.00 / 24.00 overall, **49.3%** (fair, info only) |
| **Splitter** | Mischievous | 1–6 | 1 in 3 come-out throws it splits into two minis and you keep either one. | Each split costs 1 Soul ("shrapnel"). It never splits in the Point phase. | 10.00 / 3.00 / 23.00, **54.1%** |
| **Horned d4** | Devilish | 1–4 | *Gore:* in the Point phase, a 7 rolled with the d4 showing 3 or 4 is gored and doesn't count. | No 11 or 12, so Naturals drop to 6/36 (craps 4.5/36). Each Gore costs 2 Soul. Can't make Hard 10. | 6.00 / 4.50 / 25.50, **59.4%** (47.7% without Gore) |
| **Candle Die** | Devilish | d8, 1–8, melting | *Candlelight:* winning bets pay ×1.25 while it's lit (rolls 1–9). Fresh, it's 54.5% Pass with Overdraw Naturals. | *Melt:* every 3 rolls its top face drops (8→7, then 7→6). From roll 10 it's a stub that only shows 1: Craps 12/36, Pass 41.7%, no bonus. Overdraws in the Point phase burn 1–2 Soul. Fresh each table. | Rolls 1–3: 9.75 / 4.50 / 21.75, 54.5%. Rolls 4–6: 9.00 / 4.50 / 22.50, 54.0%. Rolls 7–9: 9.00 / 4.50 / 22.50, 49.7%. Rolls 10+: 6.00 / 12.00 / 18.00, 41.7% |
| **Hourglass** | Devilish | 1–6 | *Turn the Glass:* when your rolls run out, flip it once for 4 overtime rolls (+1 per level). | Each 1 it shows removes a roll from the limit ("empty bulb", about 2 per table). Each overtime roll costs 2 Soul. | 8.00 / 4.00 / 24.00, **49.3%** (fair faces; changes the roll count) |
| **d13** | Satanic | 1–13 | Overdraw Naturals: Naturals jump to **18/36 (50%)** (12.46 of them Overdraws). | In the Point phase, an Overdraw comes up 34.6% of rolls and burns 3.07 Soul on average. A long Point can end a run. | 18.00 / 4.15 / 13.85, **67.8%** |
| **Severed Hand** | Satanic | 0–5 fingers | *Sleight:* after the dice land, set the d6 to any face. Every Sleight roll can be a win, except a fist (0), which can't reach 7 or 11. | Sleight costs 3 Soul, +1 per extra use at the same table (3, 4, 5…). *Restless:* if you finish a table without using it, it takes 2 Soul anyway. Passive odds are poor. | Passive: 6.00 / 6.00 / 24.00, 47.3%. Sleight used: 30.00 / 0.00 / 6.00, 100% |
| **Black Moon** | Satanic | 1–6 (glowing dots) | *Eclipse:* when a Point is set, you may eclipse it. Until it resolves, **a 7 wins and the Point loses** (Point 4/10: 66.7% win, vs 33.3%). | Each Eclipse costs 4 Soul. Losing an eclipsed Point deals Seven-out Soul damage ×2. Max Soul −10 while you own it. | 8.00 / 4.00 / 24.00 passive, 49.3%. Every Point eclipsed: **61.8%** |

**Notes:**
- **Swing check:** Bone dice sit at 47.5–53.6% Pass. Mischievous dice reach 54.1% or turn variance into Soul safety (Coin). Devilish reach 54.5–59.4% with real Soul costs. Satanic reach 61.8–100% with costs that can end a run. That matches the swing rule.
- **Deviations from the art concept, and why:**
  - **Two-Face Coin:** the coin's 7 is **not** an automatic Natural (see Q3).
  - **Splitter:** the AD's version sums both minis. That would make a 3-die total of 3–18, which breaks every 2d6 bet; here you keep one mini instead (see Q4).
  - **Candle Die:** values 1–8 kept, plus a melting rule.
  - **Severed Hand:** the AD's 0–5 kept, with a fist as a real result.
- **Rejected:** Knucklebone with historical astragalus weights (1:4:4:1) made Craps 1.8/36 and Pass 52.3%, too strong for a no-drawback Bone. Splitting in the Point phase too gave Splitter 63.1% Pass, too strong for Mischievous.

> **Art/feel Q&A (answers to the Art Director's questions)**
> 1. **Severed Hand 0 (a fist):** yes, 0 is a valid result. The hand adds its finger count to the d6, so sums run 1–11. Come-out: **P(Natural) 6/36 (16.7%), P(Craps) 6/36 (16.7%), P(Point) 24/36 (66.7%).** 7 comes from 1+6 through 5+2 (5/36), and 11 only from 5+6 (1/36). **Sum 1** (fist + 1) is new: it's a **Snake Bite** and counts as Craps on the come-out, no decision in the Point phase. **Sum 12 can't happen.** A fist can't pair, so Hard ways need 1–5 fingers matching the d6. With Sleight, a fist still can't make 7 or 11, so a Sleight Natural is 30/36, not 36/36.
> 2. **Displayed dice (Black Moon, Hourglass, Marble Eye, Severed Hand):** yes, reveal **after they settle**, with a flicker during the roll (Black Moon's dots cycle, the Hourglass sand sloshes through numerals, the Hand's fingers twitch). It fits POC 1's reveal sequence (each die settles and locks in turn, then the sum, then the result) and stays inside the 1.5 s reveal (§5b). Every result is seeded either way, so the flicker is honest theater. One exception: the **Marble Eye** shows its *next* value during betting (Peek), so its pupil points before the throw and just confirms at the reveal.
> 3. **Two-Face Coin's 7:** **no, it is not an automatic Natural.** The coin adds 0 or 7 like any die, so a total of 7 can't happen at all. With the coin's 7 as an auto-Natural, Naturals would be 50% (Devilish-level, the same as Hellbent) and Any Seven would pay +150% EV. Additive, it's a "never Seven-out" die: Nat 6/36 (11 and the 13 Overdraw), Craps 12/36 (sums 1, 2, 3, 12), Point 18/36, and Pass wins 66.7% of the decisions it finishes. But Points take 12 rolls on average, so it's safe and slow. Make the 0 face read as a hollow or crossed 0.
> 4. **Splitter:** the split is **not guaranteed**. It splits on **1 in 3 come-out throws** (seeded; play the hard-hit split animation when the seed says split) and never in the Point phase. When it splits, you **keep one mini**; the other just giggles and fades. It always counts as **one die**: one value in the sum, a pair only if the kept mini matches the other die, its face mods apply to the kept mini, and it takes one loadout socket. Settle detection still waits for both minis.
> 5. **Knucklebone 1/3/4/6 and Tooth 1–3:** confirmed, both with even odds per face. Knucklebone + d6: **Nat 7.50/36, Craps 4.50/36, Point 24/36, Pass 47.8%.** Tooth + d6 without Bite: **Nat 6/36, Craps 6/36, Point 24/36, Pass 47.5%**. With Bite: **Nat 7.00/36, Craps 5.50/36, Point 23.50/36, Pass 53.6%**, and Snake Eyes 2.33/36. Both are Bone sidegrades: weaker at Pass, but they feed low-number bets.
> 6. **Tooth standing on its roots:** a **bonus**, called **"Bite."** It happens on **1 in 12 throws** (seeded). The tooth stands upright with a snap SFX, and you **choose its value (1, 2, or 3)** for that roll. That's included in the odds above, and it's what lifts the Tooth from 47.5% to 53.6% Pass.

## 8. Face Mods (Shop, The Carver, and some events)
There is **no limit on mods per die**. Instead, **each mod costs more the more mods that die already has:**

**Price = round(base × (1 + 0.5 × mods already on that die))**

| Mod | 1st | 2nd | 3rd | 4th | 5th |
|---|---|---|---|---|---|
| **Swap** (base 10) | 10 | 15 | 20 | 25 | 30 |
| **Mark: Coin** (base 12) | 12 | 18 | 24 | 30 | 36 |
| **Mark: Soul** (base 15) | 15 | 23 | 30 | 38 | 45 |
| **Curse** (base 12) | 12 | 18 | 24 | 30 | 36 |
| **Burn** (base 15) | 15 | 23 | 30 | 38 | 45 |

This keeps a "one carry die" build possible but makes spreading mods across the bag cheaper, which matters because bosses hit the loadout (§10).

**The four mod types:**
- **Swap:** set one face to any value 1–6. Two 1-faces make Snake Eyes 2/36; two 6-faces feed High Side.
- **Mark** (a symbol stamped on a face; pick one when buying):
  - **Coin Mark:** whenever this face shows, +10% of the table's stake to your bankroll, rounded up (Floor 1: +2 Coin). That's about +4 Coin per Floor 1 table, a fifth of the target gap.
  - **Soul Mark:** whenever this face shows, heal 1 Soul (max 2 per table across all Soul Marks).
- **Curse:** a strong but painful face. Whenever it shows, **winning bets on that roll pay ×2**, and it **burns 2 Soul** whether you win or lose. Mystery Door traps can force a Curse onto a random face.
- **Burn:** remove a face entirely. The die now has **N−1 faces**, each equally likely (it doesn't reroll the burned face). A die can't go below 2 faces. Examples with a fair d6 partner:
  - Burn the 1 (faces 2–6): **Nat 8.40/36, Craps 2.40/36, Point 25.20/36, Pass 52.9%.**
  - Burn the 1 and 2 (faces 3–6): Nat 9.00/36, Craps 1.50/36, Pass 56.0%.
  - Burn the 6 (faces 1–5): Nat 7.20/36, Craps 3.60/36, Pass 49.6%.
  - Burn down to 1 and 6 only: Nat 9/36, **Craps 9/36**, Pass 41.7%. Burning isn't free power; it can dig a hole.
- **Removing a mod:** 8 Embers at a Shop (it doesn't lower future prices on that die; the count is "mods ever bought"). Removing a Burn restores the face to its original value.
- **Folded or cut from v0.4:** Pip Shift → Swap. Gold → Coin Mark and Curse. Warded → Soul Mark. Loaded, Glass, and Wild are cut (Loaded survives only as a die ability, like Leadfoot). The old Dealer "Cursed face" is now a forced Curse.

## 9. Floor Map and Stops
**Layout:** each floor is a branching map 7 rows deep, shown up front so you can plan a route. **The floor's Dealer is revealed at the top of the map** (portrait, signature rule, and stacked rules) from the moment you enter the floor, so you can build toward or against them.
- **Row 1:** always a Table.
- **Rows 2–5:** a mix of tables and stops (about 55% tables, 45% stops).
- **Row 6:** every path offers a **Lounge or a Shop**.
- **Row 7:** the Dealer.
- A typical route plays **4 tables** (including High-Stakes and Elite) plus 2 stops. A greedy route can play 5, and a cautious route 3.
- **Before Floor 1 row 1:** the Opening Bargain slot (a special Devil's Deal; parked, §1).

**After Floor 3:** beating the 3rd Dealer opens the **Contract Room**, a fixed Shop plus Lounge. Then comes the **Final Table**. There is no map.

**Escalation:** within a floor, the stake, target, and bet cap rise by 10% per row. Between floors they scale roughly ×2.2:

| | Floor 1 | Floor 2 | Floor 3 | Final |
|---|---|---|---|---|
| Stake | 20 | 45 | 100 | 220 |
| Target | stake + 20 | stake + 45 | stake + 100 | stake + 260 |
| Bet cap | 25 | 60 | 130 | 300 |
| Chip | 5 | 10 | 25 | 60 |

**Tuning:** the Dealer is tuned for a player who took about 1 Elite and 1 High-Stakes table. The target is about a 30% boss win on the safest route vs. about 60% on a greedy-but-sane one.

**Table nodes:**

| Node | What happens |
|---|---|
| **Table** | One table rule. Standard stake and target. Clear: 10 Embers + surplus bonus. |
| **High-Stakes Table** | Two rules, 1.5× stake, target, and cap. Clear: 12 Embers + bonus, plus a guaranteed face mod or bet unlock. |
| **Elite Table (Pit Captain)** | Two rules plus a mini signature rule. Clear: 15 Embers + bonus, plus a die pick (1 of 3, Devilish or better). The miss penalty is +3. |
| **Dealer** | The revealed boss (§10). 30 Embers + bonus, a contract piece, and +1 bet slot (Dealers 1–2). |

**Stops** (share of the non-table nodes in rows 2–5; row 6 is separate):

| Stop | Share | Guarantee | What happens |
|---|---|---|---|
| **Shop** | 20% | At least 1 reachable in rows 2–4 on every floor | 2 dice (rarity odds §7), 1–2 bets you don't own, 3 face-mod offers, mod removal (8), die levels (10/20/35), Bring 3 (60, once). Rerolls cost 3 Embers, +1 each. |
| **The Lounge** | 15% | Always offered at row 6 (with the Shop) | Heal 30% of max Soul, **or** level a die for free. |
| **Side Game** | 15% | — | One quick throw with any 2 of your bag dice. **Ember Toss:** stake up to 20 Embers on one Pass decision at 1:1. **Blood Toss:** stake 5 Soul; win heals 5 Soul and gives 5 Embers. Fair dice win 49.3%, so a good build turns this into profit. |
| **Mystery Door** | 25% | — | A random event (list below). |
| **Devil's Deal** | 10% | At most 1 per floor | Pick 1 of 3 offers, or walk away: **(a)** a random Devilish die for −8 max Soul. **(b)** Any bet unlock from the pool for 6 Soul. **(c)** 40 Embers, but your best die gets a forced Curse on its two lowest faces. **(d)** Remove all mods from a die and refund their full price, for 5 Soul. |
| **The Altar** | 10% | At least 1 reachable on Floors 2 and 3 | Sacrifice one die for Soul or to empower another (§7b). |
| **The Carver** | 5% (rare) | At most 1 per floor; never on rows 1–2 | One **free** mod of any type on any die, **or** any two mods at half price. Carver mods ignore the price escalation. |

**Mystery Door events (examples):**
1. **A Loser's Note:** you learn the rules of every table on the next row, and the note has 5 Embers folded inside.
2. **The Stranger's Trade:** trade a bag die for a random die one rarity higher. It arrives with a forced Curse on one face.
3. **Pickpocket (trap):** lose 25% of your Embers (max 15). If you have 0, lose 2 Soul instead.
4. **Hex Spring (trap):** a random bag die gets a forced Curse on a random face.
5. **Fallen Gambler:** take his die (a random Mischievous). Prying it loose costs 4 Soul.
6. **Back-Room Doctor:** pay 15 Embers to heal 10 Soul, or leave.
7. **Lucky Chip:** +10 Embers, and your next Shop reroll is free.
8. **Confession Booth:** lose 6 Soul, gain +5 max Soul. Or confess for free and remove one mod.

**Balance implications of the locked structure:**
1. **Soul budget is the big one.** About 16 tables at the fair-dice rate of 7–9 Soul each is roughly 130 Soul, against 50 starting Soul.
   - The intended curve is that a decent build cuts the cost of a cleared table to about 3–5 Soul.
   - Even so, we need about 50–60 Soul of healing across the run.
   - Proposal: start at **50 Soul**. Each contract piece **restores 15 Soul and adds +5 max Soul**, which also makes the pieces matter mechanically. Keep the Lounge at 30%.
   - Sim (§3b): Dealer re-sits are the biggest single Soul drain, and fair-dice survival through Floor 1 is only 52–88% depending on bet style and route. Must be re-run once dice and rules are in the sim.
2. **Final Table spike.** The Devil comes right after the 3rd Dealer, with no tables in between to recover. The Contract Room (a guaranteed Shop plus Lounge) exists to prevent a run ending on a Soul-drained arrival.
3. **What do the contract pieces do in the final?** Option: each recovered piece is a **Clause** that cancels one of the Devil's stacked rules at the Final Table. It's boss-specific, so it doesn't break the no-relics rule. This needs Cash's call.
4. **Route greed.** A run has only about 4 regular tables per floor, so each Elite or High-Stakes choice is a big share of a floor's power. That's good for decisions, but the variance between maps is high, so guarantee at least 1 Elite reachable on every floor.
5. **Cap-betting dominates (new, from the sim).** With a Floor 1 cap of 25 on a 20 stake, betting the cap clears 48% of tables vs 31% for careful play, and costs *less* Soul. Recommendation: cut every bet cap to 60% of its current value (15 on Floor 1), which the what-if shows brings cap-betting to 27.6%. This needs Cash's call because it changes the feel of POC 1 (open question §13).
6. **Row 6 Shop rarely gets used (new).** About 75–83% of fair-dice runs need the Lounge at row 6, so the r3 Shop carries the economy. That's fine if builds lower Soul costs; otherwise consider a Lounge that also sells one item.

## 10. Boss Pools and the Final Table
- **Pools:** each floor has a pool of 3 Dealers. One is drawn per run and **revealed at the top of that floor's map** when you arrive, so you can build toward or against them.
- **Design rule:** every Dealer **counters a popular build** (named below), has a signature with concrete numbers, and stacks 1–2 table rules from §6.
- **Dice effects** hit your **loadout** (the 2 dice you brought), never the whole bag.
- **On a miss:** you take the miss penalty and must sit again (a fresh table), until you clear or run out of Soul. (Sim assumption; open question §13.)
- **Rewards:** 30 Embers + surplus bonus, a contract piece (+15 Soul, +5 max Soul, proposed), +1 bet slot after Dealers 1–2, and a Satanic die choice (1 of 2) after Floors 1–2.

**Floor 1** (stake 35, target 70, cap 44 at row 7)

| Dealer | Counters | Signature | Stacks |
|---|---|---|---|
| **Madame Shuffle** | One-die carry (all mods on one heavily modded die) | **Shell Game:** before every even-numbered throw, she palms the loadout die with more mods and swaps in a Plain Bone for that throw (its mods and ability are off). Ties: the rarer die. | Crooked Dice |
| **Snake-Eye Sal** | Snake Eyes and low builds (Tooth, two 1-faces, Low Side, Any Craps) | **Snake Charmer:** any rolled 2 deals double Soul damage, and at least 2 Soul even if you won on it. Snake Eyes and Any Craps pay half at his table. | Snake Pit |
| **The Rat King** | Big-payout builds (Curse ×2, Coin Marks, Candle, stacked one-roll bets) | **Rat Tax:** on every winning roll, rats take 20% of the payout (rounded up). A pair scares them off: on any pair they take nothing and drop 5 Coin back onto your bankroll. | Tithe |

**Floor 2** (stake 80, target 160, cap 106 at row 7)

| Dealer | Counters | Signature | Stacks |
|---|---|---|---|
| **Baron Vig** | Slow, long-Point grinding (Odds stacks, Two-Face Coin, Hourglass overtime) | **Growing Vig:** he takes 5% of every payout per roll already thrown at this table (roll 6: 30%), max 50%. | Banned Bet |
| **The Twins** | Single-number builds (Swap stacks, Marble Eye, Hardways, Devil's Number) | **Cursed Numbers:** before each throw, the left twin names a number from 4–6 and the right twin one from 8–10, shown on the felt. Rolling either costs your choice of 2 Soul or 20% of your bankroll. Making your own Point on a cursed number is exempt. | Doubles Tax |
| **Velvet Widow** | Burst and streak play (cap bets, Streak, Let It Ride) | **The Goal Heals:** every roll that isn't a win raises the target by 5% of the stake, up to +50%. **Two winning rolls in a row** wipe all the creep. | Hot Seven |

**Floor 3** (stake 177, target 354, cap 230 at row 7)

| Dealer | Counters | Signature | Stacks |
|---|---|---|---|
| **Odds Bodkin** | Point and Odds builds (big Odds behind Pass, Black Moon) | **Scratched:** each time a Point is set, he scratches 2 numbers from {3, 4, 5, 9, 10, 11} (never your Point). In the Point phase, rolling a scratched number loses every bet on the felt instantly and counts as a Seven-out for Soul. | High Roller |
| **The Collector** | Satanic carry (one run-defining die) | **Confiscation:** at the start, he takes the rarer die in your loadout (ties: the one with more mods). You play with your other die plus a Plain Bone. **Debts Due:** every Seven-out also takes 10% of your bankroll. | Dead Pips |
| **The Proprietor** | "Solved" builds tuned to a known rule set | **House Rules:** every 4 rolls, he adds a random §6 rule not already in play, up to 3 added rules. The added rules stay for the rest of the table. | Blind Felt |

**Final Table: The Pit Boss Below (the Devil)** (stake 220, target 480, cap 300)
- **Borrowed signatures:** he plays **one signature from each floor's pool, taken from the Dealers you did NOT face** (one of the two per floor, drawn at run start and shown in the Contract Room). The finale always tests something your build hasn't seen.
- **Stacked rule:** Hot Seven.
- **Own signature, "The House Always Wins":** for the first 6 rolls he comps (disables the ability and mods of) the rarer die in your loadout.
- **Clauses (pending, §9 item 3):** each recovered contract piece cancels one borrowed signature or stacked rule of your choice.
- Beating him wins the run.

## 11. Meta-Progression (light, post-POC)
- **One difficulty, and it's hard.** Heat and ascension levels are removed.
- **Unlocks by feats, not currency.** **Recommendation: remove the meta currency entirely** (it was "Embers" in v0.4, then proposed as "Ash"). Feats make it unnecessary, keep the screen simple, and leave "Embers" meaning only the shop money.
- **Starting pool:** the 12 example dice in §7, the 6 craps-pool bets, and all 9 Dealers.
- **The run-over screen shows the next 3 locked feats** with progress bars. That's the "one more run" hook.
- **Characters with unique starting dice:** parked for later.

| Unlock | Feat |
|---|---|
| Knucklebone | Play 2 runs |
| Tooth Die | Roll Snake Eyes 3 times (lifetime) |
| Two-Face Coin | Finish a table with 0 Seven-outs |
| Marble Eye | Clear a table in 6 rolls or fewer |
| Splitter | Roll 3 pairs at one table |
| Horned d4 | Beat any Floor 1 Dealer |
| Candle Die | Clear a table with 5 Soul or less remaining |
| Hourglass | Clear a table on its final roll |
| d13 | Beat any Floor 2 Dealer |
| Severed Hand | Sacrifice a Satanic die |
| Black Moon | Reach the Final Table |
| Invented bets (each joins the Shop pool) | Mirror: roll 2 pairs in a row. High/Low Side: clear 5 tables (lifetime). Hedge: survive 3 Seven-outs at one table. Sinner: lose a run to a Floor 2 Dealer. Devil's Number: take 3 Devil's Deals (lifetime). Streak: win 4 Pass decisions in a row. Blood Bet: clear a table with 5 Soul or less after a Blood Bet. |

## 12. PROOF-OF-CONCEPT Scope (for Godot Dev, build now)
**Goal:** prove that the basic roll and table cycle feels good: the roll, the reveal, win or loss, and the push to hit the target. Use **2 plain fair dice**.

**Out of scope for the proof of concept:** dice selection, rarities, abilities, drawbacks, face mods, sacrifice, table rules, the shop, and the map. These stay designed in the sections above for later.

- **Setup:**
  - 40 Soul and a 20 Coin stake, with a target bankroll of 40 (net +20).
  - 12 rolls, and a bet of 5–25 chosen before each come-out roll.
- **Bet:** **Pass** only, with the full craps flow.
  - **Come-out:** 7 or 11 wins (a Natural). 2, 3, or 12 loses (Craps). Any other sum sets the Point.
  - **Point phase:** roll the Point again to win, or a 7 to lose (Seven-out).
  - The bet locks in while a Point is set. If rolls run out with a Point still open, the bet is returned.
- **Roll and reveal:**
  - Press Roll and both dice tumble.
  - Each die settles on its value in turn, and the sum is shown.
  - Then the result appears: Natural, Craps, Point set, Point hit, Seven-out, or no decision.
  - The bankroll counts up or down after the result.
- **Soul damage (from §3):**
  - Seven-out: 2 Soul plus 1 per 10 Coin lost, rounded up.
  - Craps: 1 Soul plus 1 per 10 Coin lost, rounded up.
  - Missing the target: 3 Soul plus 1 per 25% of the gap (max 7). Going bust: 7 Soul.
- **Table cycle:** clearing or failing a table shows the result screen (bankroll, Soul lost, surplus). Then **Next Table** starts a new table with the same stake, target, and rolls, and Soul carries over. Reaching 0 Soul shows a run-over screen and a Restart button.
- **UI:** bankroll, target, rolls left, Soul, Point marker, bet selector, and the Roll button.
- **Data-driven:** stake, target, rolls, bet limits, and Soul formulas go in one config resource so design can tune them without code.
- **Debug:** a seed input plus a toggle that forces the next roll.
- **Stretch (only if trivial):** Field and Any Craps as one-roll side bets.
- **Success test:**
  - The reveal should feel exciting.
  - The target should feel reachable but usually just out of reach. In simulation, Pass at 10 hits +20 in 12 rolls about 22% of the time, and varying the bet size changes that.
  - Players should want to hit Next Table.

**v0.5 notes on POC 1 (the section above is otherwise unchanged):**
- **Out of scope:** Embers, the Shop, bet slots, and the dice bag. POC 1 is still one table with plain dice; its "surplus" on the result screen is just table Coin.
- **Pace:** aim for the ≤ 1.5 s default reveal with a speed toggle (§5b), and let the Pass bet repeat by default if that's cheap.
- On a 20-Coin table the v0.5 scaled Soul unit (U = half the stake) is exactly the "per 10 Coin" rule above, so no tuning changes.

## 12b. Mini-Run POC (POC 2, next build after the 3D table POC)
**Goal:** the smallest slice that's fun as a run: build a bag, pick a loadout, spend Embers, and beat one boss. Everything is Floor 1 numbers.

**Node layout (recommended: a fixed linear path with one fork):**
Table 1 → Shop → Table 2 → High-Stakes Table → **fork: Lounge or Altar** → Boss.
A linear path keeps the build small and makes runs comparable for tuning. The one fork tests the stop decision without a map generator. A tiny 2-branch map is the stretch goal.

| Node | Stake / target / cap / chip | Rules | Clear reward |
|---|---|---|---|
| Table 1 | 20 / 40 / 25 / 5 | Tithe | 10 Embers + bonus |
| Shop | — | — | — |
| Table 2 | 24 / 48 / 30 / 5 | Banned Bet | 10 Embers + bonus |
| High-Stakes | 40 / 80 / 50 / 5 | Cold Table + Tithe | 12 Embers + bonus + a free mod or bet unlock |
| Lounge **or** Altar | — | — | Heal 15 Soul (30% of 50) or a free level / sacrifice (§7b) |
| **Boss: Madame Shuffle** | 35 / 70 / 44 / 5 | Shell Game + Tithe | 30 Embers, "Floor cleared" screen |

- **Rolls:** 12 per table. **Soul:** start 50 (max 50), §3 rules with U = half the stake. A missed table pays 3 Embers. A missed boss means sitting again.
- **Embers:** start at 0. Surplus bonus +1 per 25% of the stake, max +10. Cash Out / Let It Ride after clearing.
- **Why Madame Shuffle:** she directly tests POC 2's new system, the bag and loadout. The obvious "pile everything on one die" plan gets punished, so players must spread mods or bring two good dice. She only needs a Plain Bone swap on even throws (no new bet types). Snake-Eye Sal would need Snake Eyes in scope; The Rat King only tests payouts.
- **Table rules (3):** Tithe, Banned Bet (it tests bet slots), Cold Table. The boss also stacks Tithe instead of Crooked Dice, to stay at 3 rules.
- **Dice (7):**
  - **Starters:** choose 2 of Plain Bone, Leadfoot, Knucklebone.
  - **Shop/reward pool:** Tooth Die (Bone, 10), Imp's Knuckle (Mischievous, 25), Marble Eye (Mischievous, 25), Hellbent Die (Devilish, 55).
  - The POC Shop always offers 1 Mischievous die plus 1 other random die from the pool.
  - Bag of 5, bring 2, with the Bag Full prompt (sell, discard, or pocket sacrifice).
- **Bets:** Pass (starter) + **Field (12), Odds (15), Mirror (14)**. The Shop offers 2 of them, and the High-Stakes reward can grant one. **3 slots** (Pass + 2), so with all 3 unlocked the slot cap bites.
- **Mods:** all 4 types (Swap, Mark Coin/Soul, Curse, Burn) at §8 prices with escalation. The Shop shows 3 mod offers. Removal costs 8.
- **Shop:** rerolls 3 Embers (+1 each), levels 10/20/35. No Bring 3.
- **Loadout screen** (§7a + §5b) before every table, including the boss (her icon and rule shown from the start of the run).
- **Data-driven:** nodes, dice (faces, abilities, drawbacks), bets (win table, payout, phase), mods (base price, escalation), rules, bosses, Ember payouts, and Soul formulas are all resources. The layout is a resource listing node types in order.
- **Debug:** seed input, force next roll, grant Embers or Soul, give any die, mod, or bet, jump to any node, toggle reveal speed (1× / 2× / Instant), and log every run to CSV (Embers, Soul per table, purchases, loadouts) for tuning against §3b.
- **Success criteria:**
  - A run takes 10–15 minutes, at about one throw every 2–3 seconds.
  - Players make at least one purchase per Shop and change their loadout at least once a run.
  - First-time players beat the boss about 30–50% of the time, and want to restart right away.
  - Players can explain why they lost (the boss rule, Soul spent, or a bad Shop choice), not just "bad luck."
  - Logged Embers at the Shop land near §3b (median about 6–13 after Table 1).
- **Out of scope:** Floors 2–3 and the Final Table, the branching map generator, Side Game, Devil's Deal, Mystery Door, The Carver, Satanic dice, exotic dice other than Knucklebone, Tooth, and Marble Eye, invented bets other than Mirror, the Opening Bargain, Bring 3, meta unlocks, contract-piece story beats, Elite tables, and audio or art polish beyond POC 1.

## 13. Open Questions for Cash
1. **Bet slots:** 3 at the start, +1 for each of the first two Dealers (max 5, my recommendation), or the PM's 3 + 1 per boss (up to 6 at the Final Table)? The cap is the build constraint, like Balatro's joker slots, and 5 fits one phone row.
2. **Bet caps:** cut every bet cap to 60% of its current value (15 on Floor 1)? The sim shows that betting the 25 cap beats careful play on clears and on Soul.
3. **Soul scaling:** make Soul damage count per half-stake lost (v0.5 draft) instead of per flat 10 Coin? It's identical on Floor 1, but without it Floor 3 is close to unwinnable.
4. **Missed Dealer:** sit again until you clear or die (v0.5 assumption), or does a miss end the run?
5. **Meta currency:** remove it (recommended, since feats unlock everything) or keep it under a new name such as "Ash"? The v0.4 meta currency was called "Embers," which is now the shop money, so it can't keep that name.
6. **Pity Embers:** a missed table pays 3 Embers (the sim supports it). Or 0 for a harsher economy?
7. **Bring 3 upgrade:** keep it as a 60-Ember Shop upgrade (roll 3, keep 2), or move it to a rare Devil's Deal? It may be too strong as a flat buy.
8. **Final Table:** the Devil borrows signatures from Dealers you didn't face (draft). And should contract pieces be Clauses that cancel one rule each?
9. **Invented bets:** add them to the Shop pool via feats (draft), or keep the pool to your six craps bets for launch?
10. **Two-Face Coin:** OK as a "can't Seven-out, but slow" die, with its 7 not an automatic Natural?
11. Should a Satanic sacrifice be able to purge a drawback (current draft), or is that too strong?
12. Should missing the target end the table quietly with a Soul penalty (current draft)? The Hourglass now offers a die-based overtime instead of a global "double or nothing."
13. Should rarity names stay as Bone, Mischievous, Devilish, and Satanic, or would you prefer a softer final tier name for store ratings?
