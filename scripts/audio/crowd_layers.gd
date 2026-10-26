## The Bonfire crowd hook, now silent. The looping crowd bed (crowd_low /
## crowd_mid / crowd_high stems that followed the unbanked pot) was removed
## by request: no background ambience at the table. The crowd's one-shots
## (stinger_pillar's roar, the mod-trigger gasps, verdict layers) still play
## through SfxManager.
##
## The API stays so callers outside the audio module (BonfireJuice and the
## Bonfire scene) need no change; every call is a harmless no-op and this
## node never owns an AudioStreamPlayer.
class_name CrowdLayers
extends Node

const SILENT_DB: float = -60.0

## Kept for callers/tests that read it; nothing plays at this level.
@export var volume_db: float = -14.0
## The last unbanked-pot fraction passed in (0..1); nothing follows it.
var pot_fraction: float = 0.0


## No-op (there is no bed to start).
func start(_fade_seconds: float = 0.6) -> void:
	pass


## Records the fraction; no sound changes.
func set_pot_fraction(fraction: float, _seconds: float = 0.4) -> void:
	pot_fraction = clampf(fraction, 0.0, 1.0)


## No-op.
func stop(_fade_seconds: float = 0.6) -> void:
	pass


## No-op (signature triggers used to swell the bed).
func nudge(_db: float = 3.0, _seconds: float = 0.3) -> void:
	pass


## No stems: always empty.
func current_db() -> PackedFloat32Array:
	return PackedFloat32Array()
