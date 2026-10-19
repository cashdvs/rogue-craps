# Audio hooks

## Throw momentum

The throw is physical and has almost no UI, so the sound tells the player how
hard they threw. `play_throw` lives on the table's `SfxManager`; the curves are
sound tuning constants in `ThrowSynth` (`scripts/audio/throw_synth.gd`), not
game numbers.

```gdscript
# When the dice leave the hand (once per throw). Returns the 0..1 intensity.
func play_throw(flick_speed_px_s: float) -> float
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

### Call sites (Table3D, used by Bonfire3D)

```gdscript
# table_3d.gd, where the release sound is hooked up:
thrown.connect(func(speed: float) -> void:
	if sfx.has_method("play_throw"):
		sfx.call("play_throw", speed)
	else:
		sfx.play(&"dice_shake"))
```
