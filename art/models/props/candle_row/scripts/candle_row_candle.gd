## One socket of the hand candle row (world_props_v1 §2.1). Visual only: node visibility, material
## swaps and shader instance uniforms; no gameplay, no signals into the game. Driven by CandleRow.
##   state EMPTY: socket unused (plate hidden too) | LIT: flame on | COLD: candle out (snuffed / table end)
##   STUB: a cold wick stub in an empty socket (negative hands_delta: Ashmouth, Baron Vig)
## Animated params (AnimationPlayer clips key only these, never `state`):
##   heat 1 = flame alive, 0 = out | wisp 0-1 smoke curl progress | gutter 0-1 (0.5 last-hand flicker,
##   1 guttering) | drip 0-1 bust gutter-drip run | rise 0 = sunk in the socket, 1 = standing (rise-in)
@tool
class_name CandleRowCandle
extends Node3D

enum State { EMPTY, LIT, COLD, STUB }

const WAX_H := 0.072      # build_candle_row.py WAX_H (wax rim at height 1)
const WICK_TOP := 0.0795  # WAX_H + WICK_H
const STUB_H := 0.28      # stub = the candle at 28 % height (a burnt-down butt)
const CARD_FOOT := 0.113  # the tongue drawing's foot inside its card (hearth_candle.gd)
const WAX := preload("res://art/models/props/candle_row/materials/candle_row_wax.tres")
const WAX_LIT := preload("res://art/models/props/candle_row/materials/candle_row_wax_lit.tres")
const WAX_COLD := preload("res://art/models/props/candle_row/materials/candle_row_wax_cold.tres")

signal snuffed  ## a snuff clip finished (the candle is now COLD); art-side only

@export var state: State = State.LIT:
	set(v):
		state = v
		_apply()
@export_range(0.7, 1.3) var height: float = 1.0:
	set(v):
		height = v
		_apply()
@export var spin: float = 0.0:
	set(v):
		spin = v
		_apply()
@export_range(0.0, 1.0) var heat: float = 1.0:
	set(v):
		heat = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.0) var wisp: float = 0.0:
	set(v):
		wisp = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.0) var gutter: float = 0.0:
	set(v):
		gutter = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.0) var drip: float = 0.0:
	set(v):
		drip = clampf(v, 0.0, 1.0)
		_apply()
@export_range(0.0, 1.2) var rise: float = 1.0:
	set(v):
		rise = v
		_apply()
@export_range(0.0, 1.0) var flare: float = 0.0:
	set(v):
		flare = clampf(v, 0.0, 1.0)
		_apply()


func _ready() -> void:
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap != null and not ap.animation_finished.is_connected(_on_clip_done):
		ap.animation_finished.connect(_on_clip_done)
	_apply()


## Snuff this candle: smoke curl, out by 0.17 s. bust = gutter + a wax drip first (1.0 s clip).
## reduced = cut straight to the end state (reduced motion).
func snuff(bust := false, reduced := false) -> void:
	if state != State.LIT:
		return
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if reduced or ap == null:
		_end_snuff(bust)
		return
	ap.play(&"snuff_bust" if bust else &"snuff")


## The extra (+hand) candle rises out of its socket and lights (0.5 s).
func rise_in(reduced := false) -> void:
	state = State.LIT
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if reduced or ap == null:
		rise = 1.0
		heat = 1.0
		return
	ap.play(&"rise_in")


## Back to a fresh lit candle (table start).
func reset_lit() -> void:
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap != null:
		ap.stop()
	heat = 1.0
	wisp = 0.0
	drip = 0.0
	rise = 1.0
	state = State.LIT


func _end_snuff(bust: bool) -> void:
	state = State.COLD
	heat = 1.0
	wisp = 0.0
	gutter = 0.0
	drip = 1.0 if bust else drip
	snuffed.emit()


func _on_clip_done(clip: StringName) -> void:
	if clip == &"snuff" or clip == &"snuff_bust":
		_end_snuff(clip == &"snuff_bust")


func _apply() -> void:
	var plate := get_node_or_null("Plate") as Node3D
	var model := get_node_or_null("Model") as Node3D
	var fl := get_node_or_null("Flame") as GeometryInstance3D
	if model == null or fl == null:
		return
	var used := state != State.EMPTY
	if plate != null:
		plate.visible = used
	model.visible = used
	var h := height * (STUB_H if state == State.STUB else 1.0)
	model.scale = Vector3(1.0, h, 1.0)
	model.rotation.y = spin
	model.position.y = -(1.0 - clampf(rise, 0.0, 1.0)) * WAX_H * h + maxf(rise - 1.0, 0.0) * 0.01
	var mi := HearthProps.mesh_of(model)
	if mi != null:
		var wax: Material = WAX
		if state == State.LIT:
			wax = WAX_LIT
		elif state == State.STUB:
			wax = WAX_COLD
		mi.set_surface_override_material(0, wax)
	var top := model.position.y + WICK_TOP * h
	fl.position.y = top - 0.004 - fl.mesh.get_aabb().size.y * CARD_FOOT
	fl.visible = state == State.LIT and heat > 0.001 and rise > 0.6
	fl.set_instance_shader_parameter(&"heat", heat)
	fl.set_instance_shader_parameter(&"level", gutter)
	fl.set_instance_shader_parameter(&"pulse", flare)
	var wp := get_node_or_null("Wisp") as MeshInstance3D
	if wp != null:
		wp.position.y = top - wp.mesh.get_aabb().size.y * CARD_FOOT
		HearthProps.wisp(wp, wisp)
	var dr := get_node_or_null("Drip") as GeometryInstance3D
	if dr != null:
		dr.position.y = model.position.y + WAX_H * h - 0.002
		dr.visible = used and state != State.STUB and drip > 0.001
		dr.set_instance_shader_parameter(&"level", drip)
		dr.set_instance_shader_parameter(&"heat", 1.0)
