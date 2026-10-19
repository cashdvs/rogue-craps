## Hearth board FX hub (node "Hearth" under the board root). The one place Godot Dev drives the
## board's visual state from; art only (sets the props' visual params, no gameplay logic).
##   pot_step  0-4  brazier fire step (Anchors/TargetPlate/Plate)
##   eyes      0-3  both demon faces (off / ember / hot / white); eyes_left / eyes_right = -1 follow `eyes`
##   fill      0-1  ember cauldron (Anchors/ChipTray/Tray)
##   lit_count 0-8  progress candles lit, order L far, R far, L ... R near (Candle1..Candle8).
##                  Reaching 8 at runtime plays the "flare" clip.
##   seam      0-1  idle glow of the ember seam on the inner rail lip; pulse 0-1 = the seam pulse
##                  (SeamPlayer "seam_pulse", 0.15 s). Call pulse_seam() to fire it.
##   snuff     0-1  bust: 0 = everything as set, 1 = everything out (AnimationPlayer "snuff").
##   wisp      0-1  smoke wisp progress (charcoal #1E1B1A curl over each lit fire), "snuff" drives it.
##   flare     0-1  the all-lit candle flare ("flare" drives it).
## The clips only key snuff / wisp / flare / pulse, never the state params, so after "snuff" every
## prop relights to its previous state (candles keep their progress).
@tool
extends Node3D

const CANDLES := 8

var _ready_done := false

@export_range(0, 4) var pot_step: int = 1:
	set(v):
		pot_step = clampi(v, 0, 4)
		_apply()
@export_range(0, 3) var eyes: int = 0:
	set(v):
		eyes = clampi(v, 0, 3)
		_apply()
@export_range(-1, 3) var eyes_left: int = -1:
	set(v):
		eyes_left = clampi(v, -1, 3)
		_apply()
@export_range(-1, 3) var eyes_right: int = -1:
	set(v):
		eyes_right = clampi(v, -1, 3)
		_apply()
@export_range(0.0, 1.0) var fill: float = 0.5:
	set(v):
		fill = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0, 8) var lit_count: int = 0:
	set(v):
		var was := lit_count
		lit_count = clampi(v, 0, CANDLES)
		_apply()
		if lit_count == CANDLES and was < CANDLES and is_inside_tree() and not Engine.is_editor_hint():
			var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
			if ap != null and ap.has_animation("flare"):
				ap.play("flare")
@export_range(0.0, 1.0) var seam: float = 0.6:
	set(v):
		seam = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.0) var pulse: float = 0.0:
	set(v):
		pulse = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.0) var snuff: float = 0.0:
	set(v):
		snuff = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.0) var wisp: float = 0.0:
	set(v):
		wisp = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.0) var flare: float = 0.0:
	set(v):
		flare = clampf(v, 0.0, 1.0)
		_apply()


func _ready() -> void:
	_ready_done = true
	_apply()


## Plays the 0.15 s ember seam pulse (its own player, so it can overlap "snuff" / "flare").
func pulse_seam() -> void:
	var sp := get_node_or_null("SeamPlayer") as AnimationPlayer
	if sp != null:
		sp.stop()
		sp.play("seam_pulse")


## Plays the bust: everything snuffs, a smoke wisp, then everything relights to its previous state.
func bust() -> void:
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap != null:
		ap.stop()
		ap.play("snuff")


func candle(i: int) -> Node3D:
	return find_child("Candle%d" % i, true, false) as Node3D


func _board() -> Node:
	return get_parent()


func _apply() -> void:
	var b := _board()
	if b == null or not _ready_done:
		return
	var heat := 1.0 - snuff
	var pot := b.get_node_or_null("Anchors/TargetPlate/Plate")
	if pot != null and "step" in pot:
		pot.step = pot_step
		pot.heat = heat
		pot.wisp = wisp
	for side: String in ["FL", "FR"]:
		var face := b.get_node_or_null("Anchors/Corner_%s/Cap" % side)
		if face != null and "eyes" in face:
			var own := eyes_left if side == "FL" else eyes_right
			face.eyes = eyes if own < 0 else own
			face.heat = heat
	var caul := b.get_node_or_null("Anchors/ChipTray/Tray")
	if caul != null and "fill" in caul:
		caul.fill = fill
		caul.heat = heat
		caul.wisp = wisp
	for i in range(1, CANDLES + 1):
		var c := candle(i)
		if c != null:
			c.lit = i <= lit_count
			c.heat = heat
			c.flare = flare
			c.wisp = wisp
	var rails := HearthProps.mesh_of(b.get_node_or_null("Visual/Rails"))
	if rails != null:
		rails.set_instance_shader_parameter(&"level", seam)
		rails.set_instance_shader_parameter(&"pulse", pulse)
		rails.set_instance_shader_parameter(&"heat", heat)
