# Audio hooks

Sounds for the Bonfire count-up sequence (`bonfire_map_events_juice.md` §3).
All are procedural (`BonfireSynth`), baked to `audio/sfx/<event>.wav` by
`tools/bake_sfx.gd`, and play through the table's `SfxManager`
(`sfx.play(event, pitch, volume_db, pitch_jitter)`). Hot Hand, bank, bounty,
bust, the Soul flask and the crowd layers come in the next PR.

## One-shots

| Event | When | Call |
|---|---|---|
| `score_tick` | each potted die lifts and ticks its pips into Base | `sfx.play(&"score_tick", BonfireSynth.tick_pitch(i), 0.0, 0.0)`, `i` = 0, 1, 2… **reset to 0 every pot**. Pitch climbs a harmonic-minor scale from C5 and caps after 12 steps. Pass `pitch_jitter = 0` or the scale goes out of tune. |
| `mult_slam` | the red Mult chip slams in | `sfx.play(&"mult_slam")`. Each extra Hot Hand chip: play again ~0.12 s later at pitch `1.0 - 0.05 * k`. |
| `count_tick` | the total counts up into the pot | one per visible step, **at most every 0.03 s** (skip steps rather than stack ticks). Pitch `1.0 + 0.5 * progress` (progress 0..1), volume about -4 dB, jitter 0. |
| `combo_banner` | the combo-name banner sweeps in | `sfx.play(&"combo_banner", 1.0, -3.0)` |
| `stinger_ember` / `stinger_flames` / `stinger_inferno` / `stinger_pillar` | with the banner | `sfx.play(BonfireSynth.stinger_for_tier(tier))`. `tier` 0 = under 100, 1 = 100–299, 2 = 300–999, 3 = 1000+. Use the same tier the flame VFX use (the thresholds are game numbers, so they stay in game logic). Lengths: 0.35 / 0.65 / 1.1 / 1.9 s. |

## Timing and fast-forward

- **Normal sequence (≤ 1.2 s):** pips 0.08 s apart → slam → count-up → banner + stinger. In the capture, the stinger lands at about 0.75 s. Its tail can ring past the end of the sequence; don't wait for it before accepting input.
- **Big sequence (≤ 2.0 s, 1000+):** `stinger_pillar` is built for the 0.25 s slow-mo. Play it at normal pitch (audio ignores `Engine.time_scale`; don't pitch it down).
- **Tap to fast-forward:** stop scheduling the remaining `score_tick` / `count_tick` calls (don't play the skipped ones). Play `mult_slam` if it hasn't played yet, then the banner and stinger right away.
- **2x speed:** keep every tick (the pitch comes from the index, not the speed). The 0.03 s `count_tick` limit thins them out.
- **Instant:** play only the stinger.

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
