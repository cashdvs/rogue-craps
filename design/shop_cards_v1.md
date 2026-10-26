# Shop cards v1: hover/tap description card per shop offer (Oct 26, 2026)
Status: PROPOSAL for AD's visual shop mock (items on a counter/shelf). Strings: `shop_card_*` in `sim/build_strings_v1.py` → `design/strings_v1.md`; `check_strings.py` 0 problems.

## 1. Real offer list (from code, not invented)
Source: `game/scripts/map/shop_view.gd`, `game/scripts/core/map/map_run_shop.gd`, `run_progress.gd`, test_map_run.gd.

| Slot | Count | Contents | Price rule |
|---|---|---|---|
| Dice | 2 | special die (SpecialDieData, e.g. Mirror, Cracked, Powder Keg, Verdict); shaped die (Caltrop, Lantern d8, Tithe d10, Midnight d12… when shapes are on, `shape_offer_chance`); rare die in slot 2 (`shop_rare_die_chance` 10/20/30%) | die price + floor markup |
| Face mods | 2 | Hellfire, Ember Pip, Gilded, Wild, Twin, Blood, … | escalates per mod already on the picked die (+50%), + floor markup; shown as a range "by die" |
| Seals | 2 | combo Seals (Pair, Trips…) | 5, +1 per Seal bought this visit |
| Rare Seal | 0–1 | premium rare Seal (Ashen, Transference, Black…) | `shop_premium_rare_price` 12 |
| Soul Draught | 1 | +N max Soul, heals N | `soul_price()` |
| Sell | per owned non-starting die | half base price (`die_sell_percent`) | — |
| Reroll | 1 | restock; banked free rerolls first | 3, then +1 |
| Leave | 1 | — | — |

**Not shop offers:** Fence, Back Room, Gravedigger are **events** (own event screen; out of scope). Lantern/Tithe/Midnight are shaped dice in the dice slot (price 18 per economy_balance_v1 §4). **No** plain Bone die is sold in the shop and there is no "remove a die" service; sell is the only removal. "Plain die" is therefore only a bag/sell-view card (§4), not a counter item.

## 2. Field decisions (AD's list → add/cut)
| Field | Decision |
|---|---|
| Name | KEEP, line 1, with price right-aligned on the same line (saves a line). |
| Rare tag | KEEP for rare dice only: a small tag chip on line 1 ("Rare"); the full `shop_rare_tag` sentence goes on line 4. |
| 6-face strip | KEEP for d6 bodies; carved faces drawn with the mod icon, locked rare faces get a lock pip. d4/d8: strip of 4/8 small faces. **d10+ (d10, d12, d20): no strip**, show `shop_card_faces_range` ("10 faces: 1 to 10") plus the one special face as a single chip. Strip faces are art, not glow (glow only on the 3D die on the counter). |
| One-line effect | KEEP, ≤12 words; reuse the item's existing description string (strings_v1). |
| Price in Embers | KEEP (line 1, right). Final price incl. floor markup. Mods show the range "{lo}–{hi}" with `shop_card_mod_price_note`. |
| Buy button | KEEP, line 5, `shop_card_buy`. |
| Can't-afford line | KEEP but **replaces** the Buy button on line 5 (greyed button with the reason), never an extra line. One blocker shown, priority: bag full > no free face > can't afford > Seal not usable. |
| Carve target face | KEEP for mods, but it's chosen after Buy in the face picker (price depends on die). Card line 3 states the rule (`shop_card_mod_pick`). |
| **Sell value** | **CUT from the buy card.** Shown only on the sell/bag card (`shop_card_sell_value`). Reason: one number per card = clarity; sell is a separate action. |
| **ADD: bag-full blocker** | `shop_card_bag_full` (bag cap 6). |
| **ADD: shape line** | shaped dice say their face count (players must know it isn't a d6). |
| **ADD: owned rare rule** | Owned rares are never re-offered (rare_dice_v1 no-repeats), so no "owned" state needed. |

Text: light on dark, numerals ≥24 px on phone (price, face strip numbers); body ≥ the HUD body size. 5 lines max on phone.

## 3. Per-type layout (phone; PC identical content)
| Type | Line 1 | Line 2 | Line 3 | Line 4 | Line 5 |
|---|---|---|---|---|---|
| Special die (d6) | Name · price | face strip (6, mod faces iconed) | effect (description) | — | Buy / blocker |
| Shaped die d4/d8 | Name · price | face strip (4/8) | `shop_card_shape` ("8 faces: rolls 1 to 8.") | effect | Buy / blocker |
| Shaped die d10+ | Name · price | `shop_card_faces_range` + special-face chip | `shop_card_shape_rule` (runs go past 6) | effect | Buy / blocker |
| Rare die | Name · [Rare] · price | face strip, locked faces with lock pip | effect | `shop_rare_tag` | Buy / blocker |
| Face mod | Name · price range | mod icon on a blank face | effect | `shop_card_mod_pick` | Buy (opens face picker) / blocker |
| Seal | Name Seal · price | combo shown (e.g. Pair) | `shop_card_seal` | — | Buy / blocker |
| Rare Seal | Name · [Rare] · price | effect | `shop_card_seal_rare` | — | Buy / blocker |
| Soul Draught | `shop_card_soul_name` · price | `shop_card_soul` | — | — | Buy / blocker |
| Reroll | `shop_card_reroll_name` · price (or "Free") | `shop_card_reroll` | `shop_card_reroll_free` if banked | — | Buy |
| Owned die (sell view) | Name | face strip | effect | `shop_card_sell_value` | `shop_card_sell` / `shop_card_cant_sell` |
| Plain Bone die (bag view only) | Bone Die | strip | `bone_die` | — | no sell button (Bone sells for 0) |

Locked rare face tapped in the carve picker: `rare_carved_locked` (existing).
Rare dice v2: **placeholder only**. Cash hasn't picked (A+ / A+ with C prototype / B); cards for v2 items are added after the pick, and they will reuse the rows above.

## 4. Phone vs PC
- **PC:** hover shows the card (after 150 ms, anchored above the item, clamped on screen); click item or Buy buys. Mouse-out hides it.
- **Android:** first tap selects the item (lifts it and shows the card); **Buy on the card buys**; tapping the item again does NOT buy (no accidental purchases). Tap elsewhere / another item swaps or closes. One card open at a time. No side panel: the card floats over the counter.
- Blocker replaces Buy on both platforms; the button stays visible but greyed so the reason stays readable.
- Mods: Buy → face picker (existing DicePanel) with per-die prices; picker refuses locked rare faces.

## 5. Strings (new, `shop_card_*`)
See strings_v1 "Shop card" rows. Existing reused: item descriptions, `shop_rare_tag`, `rare_carved_locked`, `bone_die`, EconomyStrings Soul/Rare Seal buttons (cards replace those labels when the visual shop lands).

Sell rule (run_progress.sell_die): refused when the bag is at `starting_dice` (5) or fewer; Bone/no-def dice have sell value 0, so they get no sell button. `shop_card_cant_sell` covers the 5-dice floor.

## Rulings for AD (Oct 26, 2026)
- RARE chip goes on every rare item token, Rare Seal included (overrides §2 "rare dice only").
- Reroll stays a button with a small card; on phone the first tap shows the card and the card button rerolls.
- The mod price range is the min to max of mod_price_range() over bag dice with a free face; show one price if only one die is eligible.
- d6 rares show the mod icon plus a corner lock on pre-carved faces only.
- The 5-line phone cap counts rendered (wrapped) lines.
