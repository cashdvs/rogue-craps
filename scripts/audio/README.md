# Audio hooks: Bonfire scoring

Sounds for the Bonfire count-up sequence (`bonfire_map_events_juice.md` §3).
All are procedural (`BonfireSynth`), baked to `audio/sfx/<event>.wav` by
`tools/bake_sfx.gd`. One-shots play through the table's `SfxManager`
(`sfx.play(event, pitch, volume_db, pitch_jitter)`); the crowd plays through a
`CrowdLayers` node.

## One-shots

| Event | When | Call |
|---|---|---|
| `score_tick` | each potted die lifts and ticks its pips into Base | `sfx.play(&"score_tick", BonfireSynth.tick_pitch(i), 0.0, 0.0)`, `i` = 0, 1, 2… **reset to 0 every pot**. Pitch climbs a harmonic-minor scale from C5 and caps after 12 steps. Pass `pitch_jitter = 0` or the scale goes out of tune. |
| `mult_slam` | the red Mult chip slams in | `sfx.play(&"mult_slam")`. Each extra Hot Hand chip: play again ~0.12 s later at pitch `1.0 - 0.05 * k`. |
| `count_tick` | the total counts up into the pot | one per visible step, **at most every 0.03 s** (skip steps rather than stack ticks). Pitch `1.0 + 0.5 * progress` (progress 0..1), volume about -4 dB, jitter 0. Also usable softly (-8 dB) while embers flow on Bank. |
| `combo_banner` | the combo-name banner sweeps in | `sfx.play(&"combo_banner", 1.0, -3.0)` |
| `stinger_ember` / `stinger_flames` / `stinger_inferno` / `stinger_pillar` | with the banner | `sfx.play(BonfireSynth.stinger_for_tier(tier))`. `tier` 0 = under 100, 1 = 100–299, 2 = 300–999, 3 = 1000+. Use the same tier the flame VFX use (the thresholds are game numbers, so they stay in game logic). Lengths: 0.35 / 0.65 / 1.1 / 1.9 s. |
| `hot_hand` **(rev 2)** | all 5 dice fly back into your hand | `sfx.play(&"hot_hand")` when the dice **arrive** (after `juice_hot_hand_fly_time`). 0.6 s: five bone clacks into the palm, a wooden "cupped hand" knock, two settle ticks. **No fire on the dice**: the ignite VFX get no sound of their own; the crowd swell comes from `CrowdLayers`. |
| `bank` **(rev 2)** | points flow as embers into the pile (hellish cash register) | `sfx.play(&"bank")`. The ember tinks of the points landing in the pile are now in the cue (0.24–0.85 s), so soft `count_tick`s are optional. |
| `bounty_claimed` **(rev 2)** | each "CLAIMED" wax stamp | `sfx.play(&"bounty_claimed")`, about 0.3 s apart if several. 0.4 s: wooden handle knock, wax press, sticky lift at +0.21 s. |
| `bust` **(rev 2)** | the fire fizzles and burns out, the dice go to ash; the low thud lands at +0.28 s | `sfx.play(&"bust")`. 1.0 s fizzle/burn (the only fire texture on the dice moment). |
| `soul_flask_crack` | the Soul flask cracks and drips | `sfx.play(&"soul_flask_crack")`, about 0.35 s after `bust` |
| `table_cleared` **(new)** | the run ends with TABLE CLEARED (`run.state == CLEARED`, with `bhud.show_end`) | `sfx.play(&"table_cleared", 1.0, 0.0, 0.0)`: 1.3 s sting (a quick rising arpeggio into a held minor chord, a boom and a bell). Play it once, under the `bonfire_clear` taunt. |
| `no_score` **(new)** | you pick a die that can't score / can't join the pot (`run.toggle(i)` returns false in `pick_die`) | `sfx.play(&"no_score")` in place of `chip_refuse`, with the die's little nudge. 0.3 s soft bone-on-felt bounce, quiet (level 0.45). Bone and felt only, no fire. |

**Rev 2 (core-loop cues):** `hot_hand`, `bank`, `bounty_claimed` and `bust` were revised and `table_cleared` and `no_score` added; the event names and calls are unchanged, so existing hooks keep working. `BonfireSynth.REVISED` says what each revision replaced. Rule: dice sounds are bone, felt and wood; fire/ember texture goes only on `bust` and in `bank`'s embers (`tests/test_core_loop_cues.gd` checks the dice cues have no hiss or crackle).

## Crowd (unbanked pot)

```gdscript
var crowd := CrowdLayers.new()
add_child(crowd)
crowd.start()                                  # when the hand starts
crowd.set_pot_fraction(pot / big_pot)          # after every pot (0..1, you choose the scale)
crowd.set_pot_fraction(0.0)                    # after Bank or Bust
crowd.stop()                                   # leaving the table
```

There are three 3.0 s looping stems, `crowd_low`, `crowd_mid` and `crowd_high`, on their own players (never stolen by the SfxManager pool). `BonfireSynth.crowd_gains_db(f)` maps the pot fraction `f` to the stem gains:

| f | low | mid | high |
|---|---|---|---|
| 0.0 | -9 dB (murmur) | off | off |
| 0.3 | 0 dB | -9 dB | off |
| 0.6 | 0 dB | 0 dB | -28 dB |
| 1.0 | 0 dB | 0 dB | 0 dB (roar) |

On top of that, `CrowdLayers.volume_db` (default -6 dB) sets the overall crowd level. Changes glide over 0.4 s.

## Timing and fast-forward

- **Normal sequence (≤ 1.2 s):** pips 0.08 s apart → slam → count-up → banner + stinger. In the capture, the stinger lands at about 0.75 s. Its tail can ring past the end of the sequence; don't wait for it before accepting input.
- **Big sequence (≤ 2.0 s, 1000+):** `stinger_pillar` is built for the 0.25 s slow-mo. Play it at normal pitch (audio ignores `Engine.time_scale`; don't pitch it down).
- **Tap to fast-forward:** stop scheduling the remaining `score_tick` / `count_tick` calls (don't play the skipped ones). Play `mult_slam` if it hasn't played yet, then the banner and stinger right away.
- **2x speed:** keep every tick (the pitch comes from the index, not the speed). The 0.03 s `count_tick` limit thins them out.
- **Instant:** play only the stinger (plus `bank` / `bust` when they happen).
