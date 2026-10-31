# audio/sfx sources

Every `.wav` here is **procedural**: generated from code by a synth class in
`scripts/audio/` and saved by `tools/bake_sfx.gd`. No recordings, samples or
third-party sounds are used, so they carry the same licence as the rest of the
repository's code. Format: 22,050 Hz, mono, 16-bit PCM.

Each synth's static `bake_all()` lists exactly the files it makes, and its `##`
header says what they are (for example `SfxSynth` in `sfx_synth.gd` makes one
`<event>.wav` per entry in `SfxSynth.EVENTS`). To find a file's recipe, search
`scripts/audio/` for its event name.

Regenerate everything (the output is identical every time; each sound has a
fixed seed):

```bash
godot --headless --path . --script res://tools/bake_sfx.gd
```

If you replace a file with a recording, remove it from its synth's
`bake_all()` (so a re-bake can't overwrite it) and add its source and licence
here:

| File | Source | Licence |
|---|---|---|
| (none yet) | | |

## Revision log

Procedural sounds that were re-designed keep their file names (so the hooks
don't change); the old version is in git history.

| File | Change | Recipe |
|---|---|---|
| `hot_hand.wav` | rev 2 (core-loop cues): dice return to the hand, bone/felt/wood; was a fire ignition | `BonfireSynth._dice_return` |
| `bust.wav` | rev 2: fizzle/burn + ash puff + thud; was a flame snuff | `BonfireSynth._fizzle` |
| `bank.wav` | rev 2: ember tinks of the points landing in the pile | `BonfireSynth._bank` |
| `bounty_claimed.wav` | rev 2: wax CLAIMED stamp (handle knock, press, lift) | `BonfireSynth._stamp` |
| `table_cleared.wav` | new (core-loop cues): TABLE CLEARED sting | `BonfireSynth.make` |
| `no_score.wav` | new: a non-scoring die's soft bounce | `BonfireSynth._no_score` |
| `trigger_<row>.wav` | new (mod trigger cues): one cue per trigger FX spec row, plus `trigger_generic`, `trigger_cluster` and the `trigger_flavor_<flavour>` layers; baked by `tools/bake_sfx.gd` like the rest (`ModTriggerSynth.bake_all()`) | `ModTriggerSynth.make` (recipes: `ModTriggerRecipes.build`) |
| `nerve_nudge.wav`, `nerve_nudge_01..03.wav` | new (Nerve nudge): a brass dial detent click + soft C6 ping + wooden tick, 3 takes | `SfxSynth._dial_tick` |
| `table_goal_reached.wav` | new (table goals): target reached, bone bells climbing A minor into a held A5 + E6 over a wooden knock, 1.1 s | `TableGoalSynth._reached` |
| `table_goal_missed.wav` | new (table goals): table missed (costs 5 Soul), the Soul ring gliding down under a low D2 toll and a drawn-out breath, 1.5 s | `TableGoalSynth._missed` |

**Removed (Oct 25):** `crowd_low.wav`, `crowd_mid.wav`, `crowd_high.wav` (the looping ambience bed) were deleted by request; nothing loops any more. The crowd one-shot recipes (`CrowdStemSynth._crowd`, `_roar`) still feed `stinger_pillar` and the mod-trigger gasps.
