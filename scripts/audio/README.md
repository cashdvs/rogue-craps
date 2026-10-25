# Audio hooks

Sounds for the Bonfire count-up sequence (`bonfire_map_events_juice.md` §3).
All are procedural (`BonfireSynth`), baked to `audio/sfx/<event>.wav` by
`tools/bake_sfx.gd`, which saves every `bake_all()` in `scripts/audio/`
(the mod trigger cues' `trigger_*.wav` included). Re-bake them all with
`godot --headless --path . --script res://tools/bake_sfx.gd`. One-shots play
through the table's `SfxManager`
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
| `hot_hand` **(rev 2)** | all 5 dice fly back into your hand | emit `table.events.hot_hand(count)` when the dice **arrive** (after `juice_hot_hand_fly_time`); `scripts/fx/table_audio.gd` plays it. 0.6 s: five bone clacks into the palm, a wooden "cupped hand" knock, two settle ticks. **No fire on the dice**: the ignite VFX get no sound of their own; the crowd swell comes from `CrowdLayers`. |
| `bank` **(rev 2)** | points flow as embers into the pile (hellish cash register) | `sfx.play(&"bank")`. The ember tinks of the points landing in the pile are now in the cue (0.24–0.85 s), so soft `count_tick`s are optional. |
| `bounty_claimed` **(rev 2)** | each "CLAIMED" wax stamp | `sfx.play(&"bounty_claimed")`, about 0.3 s apart if several. 0.4 s: wooden handle knock, wax press, sticky lift at +0.21 s. |
| `bust` **(rev 2)** | the fire fizzles and burns out, the dice go to ash; the low thud lands at +0.28 s | `sfx.play(&"bust")`. 1.0 s fizzle/burn (the only fire texture on the dice moment). |
| `soul_flask_crack` | the Soul flask cracks and drips | `sfx.play(&"soul_flask_crack")`, about 0.35 s after `bust` |
| `table_cleared` **(new)** | the run ends with TABLE CLEARED (`run.state == CLEARED`, with `bhud.show_end`) | emit `table.events.table_cleared`; `scripts/fx/table_audio.gd` plays it once: 1.3 s sting (a quick rising arpeggio into a held minor chord, a boom and a bell), under the `bonfire_clear` taunt. |
| `no_score` **(new)** | you pick a die that can't score / can't join the pot (`run.toggle(i)` returns false in `pick_die`) | emit `table.events.no_score`; `scripts/fx/table_audio.gd` plays it in place of `chip_refuse`, with the die's little nudge. 0.3 s soft bone-on-felt bounce, quiet (level 0.45). Bone and felt only, no fire. |

**Rev 2 (core-loop cues):** `hot_hand`, `bank`, `bounty_claimed` and `bust` were revised and `table_cleared` and `no_score` added; the event names and calls are unchanged, so existing hooks keep working. `BonfireSynth.REVISED` says what each revision replaced. Rule: dice sounds are bone, felt and wood; fire/ember texture goes only on `bust` and in `bank`'s embers (`tests/test_core_loop_cues.gd` checks the dice cues have no hiss or crackle).

## Nerve nudge

| Event | When | Call |
|---|---|---|
| `nerve_nudge` **(new)** | every Nerve nudge and undo (VFX Dev's #140 plays it through `TableAudio`, falling back to `chip_place` if it's missing) | `sfx.play(&"nerve_nudge")`. A brass dial clicking one detent: 80–110 ms, a tiny click, a soft C6 brass ping and a low wooden tick, no noise. `SfxSynth` recipe `_dial_tick`, 3 takes (`nerve_nudge_01..03`, a few cents apart) rotated without repeats so rapid nudges don't sound robotic. Peaks at the SfxSynth level (0.85); play it at about -6 dB if it stacks with chip sounds. |

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

## Mod trigger cues

One short cue per row of the Art Director's trigger FX spec
(`art/concept/special_dice/trigger_fx_spec.md` §2; a team doc kept outside
this repo, per AGENTS.md). Each plays on top of the
count-up when a face mod or special die fires. The cues are procedural
(`ModTriggerSynth`, recipes in `ModTriggerRecipes`), baked to
`audio/sfx/trigger_<row>.wav` by `tools/bake_sfx.gd`, and sound
0.15–0.45 s after their hit. They sit mostly in 1–5 kHz, so they read over
`score_tick` / `count_tick`, and peak 6 dB under the stingers. Tones use the
tick scale (C harmonic minor), so overlaps stay consonant. There's no fire on
any of them, Hellfire included.

```gdscript
sfx.crowd = crowd                     # once, if there is a crowd: signature hits nudge it
sfx.trigger_speed_mode = speed_mode   # 0 = 1x, 1 = 2x, 2 = Instant (JuicePlan)
# At each trigger's FX start, once per trigger, in resolve order. No timers: the hook staggers.
for trig in fired:
	var hit_in := sfx.play_mod_trigger(trig.id, trig.tier, intensity)   # seconds to the hit, -1 = silent
```

**One caller, one owner.** Exactly one place in the game calls `play_mod_trigger`: the feel layer's listener, `TableAudio`. **Pending:** nothing calls it yet; wiring it into `TableAudio` (VFX Dev's #72) is a follow-up PR. The hook owns everything after that call: stagger, voice cap, cluster, speed modes, the Bellows once-rule and the crowd nudge. The caller doesn't add timers, count voices or call `crowd.nudge()`, or those would happen twice.

- **id:** a spec row id (`&"ferryman_heads_copy"`) or a mod / die id (`&"mirror"`, `&"hellfire"`). `ModTriggerSynth.ALIASES` maps an id to its default row. Pass the row id when one die has several moments (`kindling_armed` / `kindling_save`, `cracked_mult` / `cracked_shatter`). Unknown ids play `trigger_generic`. `heavy` and `extra` play nothing, and `blank` plays the existing `no_score`.
- **tier:** `ModTriggerSynth.Tier` MINOR / MAJOR / SIGNATURE is −4 / −2 / 0 dB; −1 uses the row's tier. **intensity** 0..1 trims −9..0 dB.
- **hit_ms:** the hit frame from the FX start; −1 uses the row's. The hook schedules the file so its transient lands on the hit. If the hit comes sooner than the file's anticipation, the cue starts at once and skips in. Retune `ROWS` without re-baking.
- **Several per pot:** triggers called at the same moment (one resolve step, e.g. several copy dice on LAND) are staggered 0.08 s apart in call order (`ModTriggerSynth.stagger(k)`, halved at 2x), and the return value includes the stagger, so the FX can use it for its own key hit. Triggers at different moments (each die's pip tick) aren't delayed. At most `MAX_VOICES` (4) cues sound at once, matching the spec's burst cap. The 5th and later play one shared `trigger_cluster` at their hit (the spec's shared pop); the rest are dropped while it's pending. Trigger cues have their own players, so count ticks never cut them off.
- **Bellows:** `SfxManager.ONCE_ROWS` (`bellows_hot`) play once while one is still sounding, so extra Bellows in the same Hot Hand return −1 (spec §2b: the effect plays once, on the first Bellows).
- **Crowd:** with `sfx.crowd` set, every SIGNATURE trigger (by its actual tier) nudges the crowd on its hit (`CrowdLayers.nudge()`: +3 dB, back over 0.3 s, only while the crowd plays). It's still public for other uses.
- **Fast-forward:** set `sfx.trigger_speed_mode` like JuicePlan: 0 = 1x; 1 = 2x (the hit comes at half the time, the cue plays 1.12x up and 2 dB down); 2 = Instant (one `trigger_cluster` per frame, no stagger). A tap-to-skip should stop calling the hook for triggers that haven't started.

| Row (tier, hit) | Cue |
|---|---|
| `wild_face` (minor, 167) | a card-shuffle flick into a short crystalline ting bending up (C7) |
| `ember_pip` (minor, 167) | a warm soft wooden pop + two little ember ticks (B7) |
| `hellfire_face` (major, 250) | an infernal brass hand-bell clang (E♭6, inharmonic) + a dry bone sting, with a low brass growl |
| `gilded_payout` (minor, 167) | a bright coin clink + a brass shimmer; a tiny chink into the pile 0.35 s later |
| `twin_face` (minor, 167) | two quick wooden knocks, the second a frame later and higher |
| `step_face` (minor, 167) | a soft wooden slide into a click (F6) |
| `stair_face` (major, 250) | three ascending steps (C–E♭–G), a firm thunk on the last |
| `kindling_armed` (minor, 167) | a dry twig snap + a papery flick |
| `kindling_save` (signature, 333) | a reversed thud breathing in, then a wooden knock and a warm C minor chord |
| `blood_face` (major, 250) | a wet heartbeat (thump-thump) + the Soul motif (hollow ring gliding up, glass drip) |
| `twin_flame_pair` (minor, 167) | a two-note glass chime, the partner a fifth up one frame later |
| `coven_set` (major, 250) | three hums converging into one C minor chord + a light bone rattle |
| `mirror_copy` (major, 250) | a glass shimmer swelling through the hop, a soft knock on the copied face, glass tail |
| `wanderer_gap` (major, 250) | an airy whistle glide + a brass compass ping (D6) |
| `bellows_hot` (major, 250) | a leathery reed wheeze, twice, with a wooden creak between (no air hiss) |
| `last_breath` (signature, 333) | a hushed rising intake, a hollow iron thunk with no ring, a falling exhale tone |
| `blood_pact` (major, 250) | a wax-seal thud + the Soul motif drawn up + three soft ticks |
| `cracked_mult` (major, 167) | a ceramic stress creak, a stone tick and ring (A♭6), discrete grit pings (no crackle) |
| `cracked_shatter` (signature, 250) | ceramic shards + a low thud + a dry trickle of tiny ticks |
| `caltrop_run` (minor, 167) | a quick run of three iron tinks |
| `ferryman_heads_copy` / `ferryman_tails_copy` (major, 333) | a flick ping, a spin whirr speeding up, the landing ring (heads C7, tails a fourth lower, G6) |
| `ferryman_alone_heads` (minor, 250) | a flick ping, a short one-turn spin, a bright lucky landing ring (E♭7) + a glint |
| `knucklebone_level` (major, 250) | a dry bone clack + a two-note brass "level up" blip (G5–C6) |
| `verdict_20_alt` (signature, 250) **optional variant** | the v0.1 Verdict 20 cue, kept at the Art Director's request: the gavel lifts (creak), a wood crack + deep brass hit, a crowd gasp. Never the default (Verdict 20 plays `hellfire_face` + `verdict`); only `sfx.play_mod_trigger(&"verdict_20_alt")` plays it. Its gasp is crowd noise, not the die, so the no-hiss test allows it. |
| `generic` | any other id: a plain two-note ding (C6–G6) |
| `cluster` | the shared pop for the 5th+ trigger and Instant: four quick chimes fanned up over a soft pop |

**Batch 3** follows the final rules (`design/nonstandard_dice.md` §10, Game Designer, Oct 19; spec v0.2; both team docs kept outside this repo). Pre-carved faces reuse the face-mod row, so pass the face-mod id plus `ctx.flavor` (`play_mod_trigger(&"hellfire_face", -1, 1.0, -1.0, &"verdict")`), or the die's own id, which implies both (`ALIASES`, `FLAVOR_OF`). The flavour adds one small layer (`trigger_flavor_<flavour>.wav`) on the same hit, 6 dB under the cue, and never a new beat:

| Face (id) | Row | Flavour layer |
|---|---|---|
| Lantern 8 (`lantern_8`) | `wild_face` | `lantern`: a faint glass chime (A♭6) |
| Tithe 10 (`tithe_10`) | `gilded_payout` | `tithe`: a soft wooden slot-clunk 60 ms before the clink |
| Midnight 12 (`midnight_12`) | `hellfire_face` | `midnight`: one soft clock tick just after the bell |
| Verdict 20 (`verdict_20`) | `hellfire_face` | `verdict`: a small dry wood gavel tap on the hit |
| Verdict 1 (`verdict_1`) | `blood_face` | none (Blood as-is) |
| Powder Keg 3 (`powder_keg_3`) | `twin_face` | `powder_keg`: a hollow barrel thump on each tick |

The Ferryman's Coin alone on tails (`ferryman_alone_tails`, a Blank face) and on its edge (`ferryman_edge`, a physics re-settle) plays nothing. Die, face and cue ids follow Systems Dev's dice-id map (`docs/DICE_IDS.md`, #107): cue ids start with the die id (`ferryman_*`, `powder_keg`), and face keys use Arabic digits (`midnight_12`).

The heavies differ in envelope as well as pitch: Hellfire's bell clang rings
on, Last Breath's 80 ms iron thunk stops dead, and Cracked shatter scatters.
Double hits (Twin, Bellows, and Keg through Twin) are one cue with two
transients, so they don't use two voices.

**Wiring note (Blank / `no_score`):** `play_mod_trigger(&"blank")` plays `no_score`, and `TableAudio` also plays `no_score` when you pick a die that can't score. For one die, play only one of them: when a Blank face's trigger plays through the hook, don't also play the pick refusal sound for that die (or the reverse).

## Timing and fast-forward

- **Normal sequence (≤ 1.2 s):** pips 0.08 s apart → slam → count-up → banner + stinger. In the capture, the stinger lands at about 0.75 s. Its tail can ring past the end of the sequence; don't wait for it before accepting input.
- **Big sequence (≤ 2.0 s, 1000+):** `stinger_pillar` is built for the 0.25 s slow-mo. Play it at normal pitch (audio ignores `Engine.time_scale`; don't pitch it down).
- **Tap to fast-forward:** stop scheduling the remaining `score_tick` / `count_tick` calls (don't play the skipped ones). Play `mult_slam` if it hasn't played yet, then the banner and stinger right away.
- **2x speed:** keep every tick (the pitch comes from the index, not the speed). The 0.03 s `count_tick` limit thins them out.
- **Instant:** play only the stinger (plus `bank` / `bust` when they happen).

## Throw momentum and impacts

The throw is physical and has almost no UI, so the sound tells the player how
hard they threw. Both calls live on the table's `SfxManager`; the curves are
sound tuning constants in `ThrowSynth` (`scripts/audio/throw_synth.gd`), not
game numbers.

```gdscript
# When the dice leave the hand (once per throw). Returns the 0..1 intensity.
func play_throw(flick_speed_px_s: float) -> float
# Every die contact. Returns true if it made a sound.
func play_impact(kind: StringName, speed_mps: float, material: StringName = &"bone", die_id: int = -1) -> bool
```

### play_throw(flick_speed_px_s)

Pass the flick speed the launch uses (after Throw sensitivity), the same value
`Table3D.thrown` emits. Intensity = `((speed - 700) / (6000 - 700))^0.6`,
clamped to 0..1 (`FLICK_MIN_PX_S`, `FLICK_MAX_PX_S`, `FLICK_CURVE`).

| Intensity | Flick (about) | Plays |
|---|---|---|
| 0.00–0.33 | up to ~1580 px/s (logged soft: 820–870) | `throw_fwip` (light cloth swish) + `throw_rattle_soft` (a few clicks) |
| 0.34–0.66 | ~1580–3420 px/s (logged medium: 1800–2150) | + `throw_fwip_whump` (low air whump), `throw_rattle_medium` |
| 0.67–1.00 | ~3420–6000+ px/s (logged hard: 4150–4400, harder up to 5900) | + `throw_fwip_tail` (bright tail), `throw_rattle_hard` (dense, heavy) |

Every layer plays at `lerp(-14, 0, intensity)` dB and pitch
`lerp(0.9, 1.15, intensity)` (the rattle 2 dB under). It replaces the
`dice_shake` played on release.

### play_impact(kind, speed_mps, material, die_id)

- `kind`: `felt`, `rail`, `backboard`, `die`, `chip` or `puck` (unknown kinds
  sound like felt). `speed_mps`: relative contact speed. `material`: the die's
  `DieData.material` (unknown materials sound like bone).
- **Under 0.3 m/s it's silent.** Strength = `((speed - 0.3) / (7.0 - 0.3))^0.75`,
  clamped (`IMPACT_FULL_MPS`, `IMPACT_CURVE`). Pitch is `lerp(0.92, 1.12)` times
  the kind's pitch. Volume runs over each kind's own range:

| Kind | dB range | Soft ~2 m/s | Medium ~3.5 | Hard ~5.9 | Sound |
|---|---|---|---|---|---|
| felt | -18..-5 | -13 | -10.5 | -6.6 | `dice_hit` at 0.72 pitch, almost no click: a patter, never a slam (dice skim at ~6 m/s) |
| backboard | -20..0 | -13 | -8.5 | -2.5 | `rim_hit` at 0.8 (deep leather) + `impact_wood` (hollow wood knock, 9 dB under → level with the body) |
| rail | -22..0 | -14 | -9.5 | -2.9 | `rim_hit` |
| die | -24..-2 | -16 | -11.4 | -4.8 | `dice_hit` at 1.25, the brightest click |
| chip / puck | -24..-2 / -22..0 | | | | `chip_place` |

  The speeds are Godot Dev's logged relative contact-point speeds (first floor
  hit soft 1.9–2.2, medium 3.1–4.5, hard 5.8–7.3, harder up to 8.3; backboard
  on hard throws 1.5–6.8, up to 8.9; the rail is rarely hit).
- **Brightness:** an `impact_click` transient is laid on top, from 26 dB under
  the body (weak taps, dull) to 3 dB under (hard hits), scaled by the kind's
  brightness (die 1.0, chip 0.8, puck 0.6, rail 0.5, backboard 0.4, felt 0.15).
- **Takes rotate** (no repeats): felt and die use `dice_hit`, rail and
  backboard `rim_hit`, chip and puck `chip_place`.
- **Rate limit:** with `die_id >= 0`, one sound per die every 0.04 s of game
  time (`IMPACT_MIN_GAP_S`; it follows slow-mo and fixed-fps recordings).
  Without a die id there's no limit.
- **Voices:** the pool (12 players) takes a free player first, so a burst of
  landings doesn't cut off the throw tail while it still rings.

### Call sites (Table3D, used by Bonfire3D)

```gdscript
# table_3d.gd, where the release sound is hooked up:
thrown.connect(func(speed: float) -> void:
	if sfx.has_method("play_throw"):
		sfx.call("play_throw", speed)
	else:
		sfx.play(&"dice_shake"))

# table_3d.gd _on_die_impact: also pass the die id.
sfx.call("play_impact", surface, speed_mps, material, die_id)
```
