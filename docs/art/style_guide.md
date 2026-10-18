# DICE OF THE DAMNED — Concept Style Guide v0.1

> Working title was *The Gambler's Descent*; the game is now **Dice of the Damned**.

## Style (one paragraph)
The Underhouse is painted as **stylized, hand-painted 2D with toonish, exaggerated proportions, chunky dark ink outlines, and slightly grimy, textured brushwork under moody low-key lighting**. Every scene is a dark, warm, smoky room (oxblood walls, pit-black shadows) lit only by ember lamps and the glow of the felt, so gameplay elements pop by value contrast: bone-ivory dice and brass-framed UI are the brightest things on screen, and **Soul-Flame cyan is reserved exclusively for the player's soul (health, the player character, soul-tax effects)** so it always reads as "you". Characters are built on one bold silhouette idea each (six arms, a giant belly), with big readable faces and shapes that survive at thumbnail size. UI uses thick brass frames, a heavy serif/slab display face in Bone on dark panels, chunky icons over words, and large touch targets so the same layouts scale from PC (16:9) to phone portrait. Keep surfaces flat-ish with painterly texture overlays rather than rendered detail — affordable for a small team and friendly to Godot 2D sprites/shaders (glow = additive sprite + light, not baked painting).

**Prompt style block (reuse verbatim):** "stylized hand-painted 2D game concept art, toonish exaggerated proportions, chunky dark ink outlines, slightly grimy textured brushwork, moody low-key lighting, palette of deep oxblood burgundy, ember orange, teal-black felt green, tarnished brass gold, bone ivory, soul-flame cyan accent"

## Palette
| Name | Hex | Usage |
|---|---|---|
| Oxblood | #3B0D14 | Backgrounds, walls, screen base, dice-sheet backdrop |
| Burgundy Velvet | #6E1A24 | Upholstery, Dealer costumes, secondary UI panels, Don't-side bets |
| Ember | #E8622A | Lamps, hellfire, ROLL button, Heavy Die pips, danger/loss flashes |
| Underfelt | #123A36 | Table felt (teal-shifted casino green), bet-zone fill |
| Pit Black | #0E1414 | Ink lines, deepest shadows, text backing |
| Tarnished Brass | #B08D3C | Table rims, UI frames, Gold Die, currency, highlights |
| Bone | #E8DCC0 | Dice bodies, all primary UI text and labels |
| Soul Flame | #4FE6E0 | Soul meter, player's flame head, soul-tax VFX ONLY |

Secondary (sparingly): Lucky green #5FD068 for the Lucky Die glow; chip/relic accent hues may vary (purple, teal, crimson) but stay desaturated except the icon.

## Starter dice
- **Lucky Die** — worn bone-ivory, rounded chipped corners; pips are glowing four-leaf clovers, the 1 (or 6) face is a horseshoe; green sparkle aura. Read: soft, warm, magical.
- **Gold Die** — tarnished brass, hard bevels with a milled coin-ridge on every edge, deep engraved coin-pocket pips; sits with loose coins. Read: rigid, valuable, metallic.
- **Heavy Die** — oversized dark iron/lead block with riveted corner brackets, cracked faces, molten ember pips leaking heat through the cracks; kicks up dust. Read: chunky, slow, dangerous.
- Silhouette rule: Lucky = rounded, Gold = crisp bevel + ridged edge, Heavy = bigger + bracketed corners. Pips must stay legible at 48 px; enchanted faces swap the pip shape, not the count layout.

## Dealer bosses
- **Madame Shuffle** (Floor 1 Dealer) — a lanky six-armed spider-like croupier in a burgundy coat, grinning porcelain skull-mask under a green visor, dice up every sleeve. *Rig: "Sleight of Hand" — each roll she swaps one of your dice for one of hers (a loaded house die) unless you pay chips to keep your hand on it.*
- **Baron Vig** (Floor 2 Dealer) — a huge bloated toad-demon pit boss in an oxblood pinstripe waistcoat, reading glasses, cigar, abacus and ledger, enthroned on chip stacks with a jar of collected soul-flames. *Rig: "The Vig" — every win is taxed (a % of payout skimmed to his ledger) and when the ledger fills he collects it as Soul damage.*
- **The Proprietor** (Floor 3 Dealer, final boss) — the owner of the Underhouse and holder of your soul contract: a gaunt figure in an oxblood tailcoat and brass top hat whose head is a bone-ivory die with ember pips, a brass roulette-wheel halo, a pen dripping cyan soul-ink, and a burning contract scroll. *Rig: "House Rules" — every few rolls he signs a new clause into your contract, permanently rewriting one table rule for the rest of the fight (e.g. 7 becomes a loss on the come-out, your Point changes, a bet's payout flips), and stacks the clauses up as the fight goes on; burning clauses costs Soul.*
- Baron Vig was restyled (v3) to flatter toon: thicker outlines, simpler shapes.

## Notes / known weaknesses
- AI-generated UI text is mostly clean in these renders but not production-ready; all labels must be rebuilt as real Godot UI with a licensed font.
- Field box in the alt mockup has a wrong number sequence (skips 8, odd highlights); Snake Eyes/Hard 8 die icons in the mobile mockup are not 1+1/4+4. Treat as layout reference only.
- Image generator returned every image at 1024x576 (16:9) regardless of requested ratio, so the "mobile" mockup is a stacked single-column layout, not a true 9:16 frame.
- Gold Die v1 had 9 pips on a face (rejected, regenerated).

- Pass 2: the image tool still returns 1024x576 even with aspect_ratio 3:4 or 9:16, so boss and mobile renders are landscape frames.

## Image files (source renders)
See README_ASSETS.md for render paths.


## Logo & title
All AI images are **direction only**. The final wordmark must be rebuilt as **vector** (SVG/AI) from a real font, with hand-adjusted letterforms.

**Three directions**
1. **Marquee** (`logo_concept_marquee`): a casino marquee sign with a brass frame and ember bulbs. "DICE" and "DAMNED" are big bone slab letters, and "of the" is a small brass script whose "o" is a bone die. Mark: a horned bone die with a skull pip in a brass rounded square. Strongest "casino" read and the most fun, but the busiest; the bulbs and frame die at small sizes.
2. **Brand** (`logo_concept_brand`): the wordmark is hot-iron branded into oxblood leather with ember-glowing edges, and a die replaces the A in DAMNED. Mark: a horned black die with a glowing skull pip pressed into a dripping wax seal. The most "damned" and the best texture story, but the dark-on-dark letters lose contrast unless the ember edge stays strong.
3. **Contract** (`logo_concept_contract`): bone lettering on oxblood parchment torn into **three pieces** (DICE / OF THE / DAMNED, tying into the contract torn in three in the backstory), with a brass quill flourish and a die-shaped wax seal. Mark: the die seal alone. The cleanest letter read and the closest tie to the lore.

**Recommendation: Contract (3) as the primary wordmark, with the horned skull-pip die from Marquee (1) as the icon mark.**
- The bone-on-oxblood lettering has the best contrast and survives shrinking.
- The three-piece tear is a story hook and an animation opportunity: the pieces snap together on the title screen.
- The marquee's horned die reads best as a 32–48 px icon.
- Keep the branded-iron treatment as an **effect** (a hover/press state or loading screen), not the base logo.

**Font notes**
- Base: **Alfa Slab One** (SIL Open Font License 1.1). Modifying it is allowed, but under the OFL a modified font that is *distributed* as a font must not use the reserved name "Alfa Slab One". The **wordmark** is outlined artwork, so it's safest to convert the letters to outlines, then hand-modify them: chip the serifs, ink-wobble the edges, tighten the kerning, and swap the "A" in DAMNED or the "O" in OF for a die only in decorative lockups.
- If a modified font file ships in the game, rename it (e.g. "DotD Slab") and keep the OFL license file with it.
- "of the" can be a contrasting script. Suggested OFL options: Rye for a western display look, or keep Alfa Slab One small caps for consistency.
- Menu and UI text: Alfa Slab One (headings), Barlow Condensed (body and numbers), both OFL.

**Color usage**
- Primary lockup: Bone #E8DCC0 letters with a 6–8% stroke of Pit Black #0E1414 ink outline, on Oxblood #3B0D14. Accents in Tarnished Brass #B08D3C (flourish, frame), Ember #E8622A (glow and edge light only).
- **Soul cyan #4FE6E0:** at most one tiny accent (e.g. the ink drop on the quill). Optional; never on the letters.
- One-color versions: Bone on Pit Black, and Pit Black on Bone. A dark-background version is the default.
- Don't put the logo on teal felt without an oxblood or black plate behind it.

**Minimum sizes**
- Full wordmark (3 lines): ≥ 160 px wide on screen, ≥ 30 mm in print.
- Compact one-line "DICE OF THE DAMNED": ≥ 240 px wide (thin "OF THE" is the limit).
- Below that, use the icon mark only.
- Clear space: the height of the "D" in DICE on all sides.

**Icon mark**
- A bone die at a 3/4 tilt with two short curved horns (Pit Black outlines) and **one skull-shaped pip** on the top face, Ember-lit edge, inside a rounded-square Oxblood plate with a Brass rim.
- At **≤ 32 px**: drop the rim, use a flat die square with a skull pip and horns (no tilt, no texture), Bone on Oxblood.
- App-icon sizes: test at 1024, 180, 48 and 32 px.

**Title screen** (`title_screen_mood`)
- High-angle Floor 1 table under the lamp, the dealer silhouette, two dice mid-air, the logo top-center, the menu bottom-left (PLAY in Ember, OPTIONS/QUIT in Bone).
- In-engine: the logo is a 2D overlay (vector → PNG at 2×). The dice are the live 3D dice on an idle "juggle" loop. The menu uses Alfa Slab One 56 px with an 8 px ink outline.
