@tool
## The Nerve bone token on its rail cradle (world_props_v1 §4). Pure presentation: no game rules here.
## Godot Dev drives it from NerveTable / NerveUi: set_state(), rescue_at(), shake(). Every pose change
## is stepped on twos (12 fps); with reduced_motion every move cuts straight to its end pose (no bob, no
## shake). Poses: AVAILABLE/CARRIED upright (CARRIED adds the notch), PICKING lifted, NUDGED tipped
## toward the felt, SPENT flat with the chevron dulled, CLOSED rests as it is, RESCUE lifts clear of the
## cradle, slides along the rail track (never past its ends, never off the rail) and bobs.
class_name NerveToken
extends Node3D

enum State { AVAILABLE, CARRIED, PICKING, NUDGED, SPENT, CLOSED, RESCUE }

const STEP := 1.0 / 12.0          # on twos
const BASE_H := 0.008             # cradle plate top (build_nerve_token.py)
const TAB_H := 0.088
const TAB_W := 0.062
const LIFT_PICK := 0.012          # picking: lifts slightly
const LIFT_RESCUE := 0.03         # rescue: clears the cradle cheeks (0.024) before it slides
const TIP_DEG := 35.0             # nudged: tips toward the felt (the dice side)
const FLAT_DEG := 90.0            # spent: lies flat, face up
const BOB_H := 0.006
const BOB_STEPS := 12             # 1 s bob loop, 12 drawings
const SHAKE_DEG := 10.0
const SHAKE_KEYS := [1.0, -1.0, 0.6, -0.3, 0.0]   # refusal: one shake, 5 drawings (0.42 s)
const DUR := {"lift": 0.17, "tip": 0.33, "flat": 0.42, "settle": 0.25, "slide": 0.5}

@export var state: State = State.AVAILABLE:
	get:
		return _state
	set(v):
		set_state(v)
## Cut every move to its end pose (accessibility setting).
@export var reduced_motion := false
## Rescue target along the track, in this node's local x (metres); set by rescue_at().
var rescue_x := 0.0

var lift := 0.0
var lean := 0.0                    # degrees toward the felt
var slide_x := 0.0
var bob := 0.0
var shake_deg := 0.0
var notch := false
var dull := false

var _state: State = State.AVAILABLE
var _segs: Array = []              # [[target pose dict, duration], ...]
var _from := {}
var _t := 0.0
var _shake_t := -1.0
var _bob_t := 0.0
var _mats := {}


func _ready() -> void:
	_apply()


## Rig scale (1.0 PC, larger on mobile): the track half-length in local units.
func track_half() -> float:
	var tr := get_node_or_null("Rig/Track") as Node3D
	return 0.5 * (tr.scale.x if tr else 0.5)


func rig_scale() -> float:
	var r := get_node_or_null("Rig") as Node3D
	return r.scale.x if r else 1.0


func set_state(s: State, animate := true) -> void:
	var prev := _state
	_state = s
	if not is_inside_tree():
		return
	var lean_now := lean
	match s:
		State.AVAILABLE, State.CARRIED:
			notch = s == State.CARRIED
			dull = false
			_plan([[{"lift": 0.0, "lean": 0.0, "slide_x": 0.0}, DUR.settle]], prev)
		State.PICKING:
			dull = false
			_plan([[{"lift": LIFT_PICK, "lean": 0.0, "slide_x": 0.0}, DUR.lift]], prev)
		State.NUDGED:
			dull = false
			_plan([[{"lift": 0.0, "lean": TIP_DEG, "slide_x": 0.0}, DUR.tip]], prev)
		State.SPENT:
			dull = true
			notch = false
			_plan([[{"lift": 0.0, "lean": FLAT_DEG, "slide_x": 0.0}, DUR.flat]], prev)
		State.CLOSED:
			_plan([[{"lift": 0.0, "lean": lean_now, "slide_x": 0.0}, DUR.settle]], prev)
		State.RESCUE:
			var x := clampf(rescue_x, -track_half() + TAB_W * 0.5, track_half() - TAB_W * 0.5)
			_plan([[{"lift": LIFT_RESCUE, "lean": 0.0, "slide_x": slide_x}, DUR.lift],
				[{"lift": LIFT_RESCUE, "lean": 0.0, "slide_x": x}, DUR.slide]], prev)
	if not animate or reduced_motion:
		_finish()
	_apply()


## Rescue wait: slide to the track point nearest [param world_pos] (the die), then bob.
func rescue_at(world_pos: Vector3) -> void:
	var rig := get_node_or_null("Rig") as Node3D
	var local := (rig if rig else self).to_local(world_pos)
	rescue_x = local.x
	set_state(State.RESCUE)


## Refusal (nerve_potted_refusal etc.): one shake, then back to the pose it was in.
func shake() -> void:
	if reduced_motion:
		return
	_shake_t = 0.0


## Maps NerveState.UiState (READY, PICKING, NUDGED, SPENT) + carried-over flag to a prop state.
func from_ui_state(ui: int, carried := false) -> void:
	match ui:
		0: set_state(State.CARRIED if carried else State.AVAILABLE)
		1: set_state(State.PICKING)
		2: set_state(State.NUDGED)
		_: set_state(State.SPENT)


func is_moving() -> bool:
	return not _segs.is_empty() or _shake_t >= 0.0


func _plan(segs: Array, prev: State) -> void:
	# leaving the rescue slot: lift, slide home, then settle into the target pose
	if prev == State.RESCUE and _state != State.RESCUE and absf(slide_x) > 0.0001:
		segs = [[{"lift": LIFT_RESCUE, "lean": 0.0, "slide_x": 0.0}, DUR.slide]] + segs
	_segs = segs
	_from = {"lift": lift, "lean": lean, "slide_x": slide_x}
	_t = 0.0
	bob = 0.0


func _finish() -> void:
	if not _segs.is_empty():
		var end: Dictionary = _segs[-1][0]
		lift = end.lift
		lean = end.lean
		slide_x = end.slide_x
	_segs = []
	bob = 0.0
	_shake_t = -1.0
	shake_deg = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _segs.is_empty():
		_t += delta
		var seg: Array = _segs[0]
		var d: float = seg[1]
		var k := clampf(floorf(_t / STEP) * STEP / d, 0.0, 1.0)
		k = 1.0 - (1.0 - k) * (1.0 - k)   # ease out
		var to: Dictionary = seg[0]
		lift = lerpf(_from.lift, to.lift, k)
		lean = lerpf(_from.lean, to.lean, k)
		slide_x = lerpf(_from.slide_x, to.slide_x, k)
		if _t >= d:
			_segs.pop_front()
			_from = to.duplicate()
			_t = 0.0
	elif _state == State.RESCUE and not reduced_motion:
		_bob_t += delta
		var i := int(floorf(_bob_t / STEP)) % BOB_STEPS
		bob = BOB_H * sin(TAU * i / BOB_STEPS)
	if _shake_t >= 0.0:
		_shake_t += delta
		var i := int(floorf(_shake_t / STEP))
		if i >= SHAKE_KEYS.size():
			_shake_t = -1.0
			shake_deg = 0.0
		else:
			shake_deg = SHAKE_DEG * float(SHAKE_KEYS[i])
	_apply()


func _mesh(path: String) -> MeshInstance3D:
	var n := get_node_or_null(path)
	if n == null:
		return null
	if n is MeshInstance3D:
		return n
	for c in n.find_children("*", "MeshInstance3D", true, false):
		return c
	return null


func _apply() -> void:
	var rig := get_node_or_null("Rig")
	if rig == null:
		return
	(rig.get_node("Slide") as Node3D).position.x = slide_x
	(rig.get_node("Slide/Bob") as Node3D).position.y = bob
	(rig.get_node("Slide/Bob/Lift") as Node3D).position.y = BASE_H + lift
	var pv := rig.get_node("Slide/Bob/Lift/Pivot") as Node3D
	pv.rotation = Vector3(-deg_to_rad(lean), 0.0, deg_to_rad(shake_deg))
	(pv.get_node("Notch") as Node3D).visible = notch
	for part in ["Tablet", "Chevron"]:
		var mi := _mesh("Rig/Slide/Bob/Lift/Pivot/" + part)
		if mi:
			mi.material_override = (load(_dull_path(part)) if dull else null)


func _dull_path(part: String) -> String:
	return "res://art/models/props/nerve_token/materials/nerve_%s_spent.tres" % ("bone" if part == "Tablet" else "chevron")
