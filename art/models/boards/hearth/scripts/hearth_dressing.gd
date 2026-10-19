## Hearth set dressing + ambient motion (node "Hearth/Dressing"; art/concept/bonfire_table/hearth_detail_pass.md).
## Art only: shows / hides the dressing, swaps the felt / rail / stud looks, and plays its own small clips.
## No gameplay logic, no physics, no signals. Godot Dev drives it through the Hearth hub (hearth_fx.gd):
##   dressing  bool  everything on (worn felt, carved rails, worn studs, corner clusters, floor, backdrop,
##                   ambient) / off (exactly the pre-pass board). The dice read test renders both.
##   ambient   bool  the ambient motion (ember motes, lamp dust, tail peeks, chain sway, bell rattle).
##                   Turn off for reduced motion; the dressing stays.
##   scoring   bool  true while a score is shown: the tail whips back (if out) and does not peek again until false.
##   rail_hit(strength)  a die hit a rail: the chain sways (ChainPlayer "chain_sway", 0.4 s).
##   bell_ring()         Smiles' service bell rattles (BellPlayer "bell_rattle", 0.5 s); Hearth.eyes reaching 3 calls it.
## The clips key only the pose params below (tail_out / tail_sway / tail_curl, chain_swing, bell_shake); the
## tail peek is scheduled here every peek_min..peek_max s (8-15 s), on twos like every Hearth clip.
@tool
extends Node3D

const TAIL_OUT_DEG := 16.0      # root lean, out from behind the far-left corner (about +Z: +Y swings toward -X)
const TAIL_HIDE_DEG := 175.0    # folded back under the table
const CHAIN_SWAY_DEG := 7.0
const BELL_DEG := 9.0

@export var enabled: bool = true:
	set(v):
		enabled = v
		_apply_dressing()
@export var ambient: bool = true:
	set(v):
		ambient = v
		_apply_ambient()
@export var scoring: bool = false:
	set(v):
		var was := scoring
		scoring = v
		if scoring and not was:
			_whip_back()
		elif was and not scoring:
			_next_peek = _rng.randf_range(peek_min, peek_max)
@export_range(1.0, 60.0) var peek_min: float = 8.0
@export_range(1.0, 60.0) var peek_max: float = 15.0
## Board looks swapped by `enabled` (set by make_hearth.gd). The worn studs are Dressing/Studs (Board A's
## stud mesh with a few tarnished and a few missing); Board A's Visual/Trim is hidden while it shows.
@export var felt_plain: Material
@export var felt_worn: Material
@export var leather_plain: Material
@export var leather_carved: Material
## Pose params (keyed by the clips).
@export_range(0.0, 1.0) var tail_out: float = 0.0:
	set(v):
		tail_out = v
		_pose()
@export_range(-1.0, 1.0) var tail_sway: float = 0.0:
	set(v):
		tail_sway = v
		_pose()
@export_range(-1.0, 1.0) var tail_curl: float = 0.0:
	set(v):
		tail_curl = v
		_pose()
@export_range(-1.0, 1.0) var chain_swing: float = 0.0:
	set(v):
		chain_swing = v
		_pose()
@export_range(-1.0, 1.0) var bell_shake: float = 0.0:
	set(v):
		bell_shake = v
		_pose()
## Fire alive (Hearth snuff): the ember motes go out with the bust.
var heat: float = 1.0:
	set(v):
		heat = v
		HearthProps.set_param(get_node_or_null("Ambient"), &"heat", heat)

var _rng := RandomNumberGenerator.new()
var _next_peek: float = 3.0
var _hit: float = 1.0
var _ready_done := false


func _ready() -> void:
	_rng.seed = 6661
	_next_peek = _rng.randf_range(2.0, 5.0)
	_ready_done = true
	_apply_dressing()
	_pose()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not enabled or not ambient or scoring:
		return
	var tp := get_node_or_null("TailPlayer") as AnimationPlayer
	if tp == null or tp.is_playing():
		return
	_next_peek -= delta
	if _next_peek <= 0.0:
		tp.play("tail_peek")
		_next_peek = _rng.randf_range(peek_min, peek_max)


## Seconds until the next tail peek (for renders / tests); set it to schedule one.
func set_next_peek(seconds: float) -> void:
	_next_peek = seconds


## A die hit a rail: the hanging chain sways (ChainPlayer "chain_sway", 0.4 s), its amplitude scaled by
## strength (clamped to 0.2-1.5). Restarts the sway if one is playing; does nothing while the dressing or
## the ambient motion is off. Called through the Hearth hub (fx.rail_hit).
func rail_hit(strength: float = 1.0) -> void:
	if not enabled or not ambient:
		return
	_hit = clampf(strength, 0.2, 1.5)
	var cp := get_node_or_null("ChainPlayer") as AnimationPlayer
	if cp != null:
		cp.stop()
		cp.play("chain_sway")


## Smiles' service bell rattles (BellPlayer "bell_rattle", 0.5 s). Restarts it if playing;
## does nothing while the dressing or the ambient motion is off. Called through the Hearth hub
## (fx.bell_ring), which also rings it when fx.eyes reaches 3.
func bell_ring() -> void:
	if not enabled or not ambient:
		return
	var bp := get_node_or_null("BellPlayer") as AnimationPlayer
	if bp != null:
		bp.stop()
		bp.play("bell_rattle")


func _whip_back() -> void:
	var tp := get_node_or_null("TailPlayer") as AnimationPlayer
	if tp == null:
		return
	if tail_out > 0.01:
		tp.stop()
		tp.play("tail_whip")


func _board() -> Node:
	var h := get_parent()
	return h.get_parent() if h != null else null


func _apply_dressing() -> void:
	if not _ready_done:
		return
	visible = enabled
	var b := _board()
	if b == null:
		return
	var felt := HearthProps.mesh_of(b.get_node_or_null("Visual/Floor"))
	if felt != null and felt_plain != null and felt_worn != null:
		felt.set_surface_override_material(0, felt_worn if enabled else felt_plain)
	var rails := HearthProps.mesh_of(b.get_node_or_null("Visual/Rails"))
	if rails != null and leather_plain != null and leather_carved != null:
		rails.set_surface_override_material(0, leather_carved if enabled else leather_plain)
	var trim := b.get_node_or_null("Visual/Trim") as Node3D
	if trim != null and get_node_or_null("Studs") != null:
		trim.visible = not enabled
	_apply_ambient()


func _apply_ambient() -> void:
	if not _ready_done:
		return
	var on := enabled and ambient
	var amb := get_node_or_null("Ambient") as Node3D
	if amb != null:
		amb.visible = on
	if not on:
		for p in ["TailPlayer", "ChainPlayer", "BellPlayer"]:
			var ap := get_node_or_null(p) as AnimationPlayer
			if ap != null and ap.is_playing():
				ap.stop()
		tail_out = 0.0
		chain_swing = 0.0
		bell_shake = 0.0


func _pose() -> void:
	var tail := get_node_or_null("Tail") as Node3D
	if tail != null:
		tail.visible = tail_out > 0.02
		var root := tail.get_node_or_null("Root") as Node3D
		var tip := tail.get_node_or_null("Root/Joint/Tip") as Node3D
		if root != null:
			var lean := lerpf(TAIL_HIDE_DEG, TAIL_OUT_DEG, tail_out) + tail_sway * 10.0
			root.rotation_degrees = Vector3(tail_sway * 5.0, 0.0, lean)
		if tip != null:
			tip.rotation_degrees = Vector3(-tail_sway * 6.0, 0.0, lerpf(70.0, -46.0, tail_out) + tail_curl * 26.0)
	var chain := get_node_or_null("Chain") as Node3D
	if chain != null:
		chain.rotation_degrees = Vector3(chain_swing * CHAIN_SWAY_DEG * _hit, 0.0, -absf(chain_swing) * 2.5 * _hit)
	var bell := get_node_or_null("Bell") as Node3D
	if bell != null:
		bell.rotation_degrees = Vector3(bell_shake * BELL_DEG * 0.4, 0.0, bell_shake * BELL_DEG)
