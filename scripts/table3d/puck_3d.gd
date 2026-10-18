## The Point puck (poc_3d.md section 5): a 0.10 m disc, black OFF face up by
## default; on Point set it lifts, flips 180 degrees and lands on the box
## (ON face up, bone with the point number), with a warm glow light under it.
class_name Puck3D
extends Node3D

const RADIUS: float = 0.05
const THICK: float = 0.014

var is_on: bool = false
var point: int = 0
var disc: Node3D
var glow: OmniLight3D
var number_label: Label3D
var _side_mat: ShaderMaterial
var _t: float = 0.0
var _danger: float = 0.0


func _init() -> void:
	disc = Node3D.new()
	add_child(disc)
	_side_mat = Toon.inked(Palette.PIT_BLACK, Color.BLACK, Toon.INK_DICE, {"rim_color": Palette.BRASS_HI, "rim_strength": 0.0, "emission_color": Palette.BRASS_HI}, 1)
	var body := Toon.add_mesh(disc, Toon.cylinder(RADIUS, THICK, 32), _side_mat)
	body.name = "Body"
	# Two thin face caps: OFF (black) on top, ON (bone) underneath.
	var off_cap := Toon.add_mesh(disc, Toon.cylinder(RADIUS * 0.96, 0.001, 32), Toon.mat(Palette.PIT_BLACK, Color.BLACK), Vector3(0, THICK * 0.5 + 0.0003, 0))
	off_cap.name = "OffFace"
	var on_cap := Toon.add_mesh(disc, Toon.cylinder(RADIUS * 0.96, 0.001, 32), Toon.mat(Palette.BONE, Toon.SHADOW_BONE, {"wrap": 0.3}), Vector3(0, -THICK * 0.5 - 0.0003, 0))
	on_cap.name = "OnFace"
	var off_text := _label("OFF", Palette.BONE, 0.0009, 32)
	off_text.position = Vector3(0, THICK * 0.5 + 0.001, 0)
	off_text.rotation_degrees = Vector3(-90, 0, 0)
	disc.add_child(off_text)
	# The ON side faces down until the flip (rotated 180 around X).
	var on_root := Node3D.new()
	on_root.position = Vector3(0, -THICK * 0.5 - 0.001, 0)
	on_root.rotation_degrees = Vector3(180, 0, 0)
	disc.add_child(on_root)
	var on_text := _label("ON", Palette.PIT_BLACK, 0.0004, 22)
	on_text.position = Vector3(0, 0, -0.022)
	on_text.rotation_degrees = Vector3(-90, 0, 0)
	on_root.add_child(on_text)
	number_label = _label("", Palette.PIT_BLACK, 0.0009, 48)
	number_label.rotation_degrees = Vector3(-90, 0, 0)
	number_label.position = Vector3(0, 0, 0.006)
	on_root.add_child(number_label)
	glow = OmniLight3D.new()
	glow.light_color = Palette.BRASS_HI
	glow.light_energy = 0.0
	glow.omni_range = 0.18
	glow.position = Vector3(0, 0.03, 0)
	add_child(glow)


func _label(text: String, color: Color, px: float, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Palette.display_font() if text != "" else Palette.number_font()
	l.font_size = size
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 0
	l.double_sided = false
	l.shaded = false
	return l


func _process(delta: float) -> void:
	_t += delta
	if is_on:
		glow.light_energy = 0.35 + 0.1 * sin(_t * TAU / 1.4)
	_danger = maxf(_danger - delta * 2.0, 0.0)
	_side_mat.set_shader_parameter("emission_color", Palette.DANGER if _danger > 0.0 else Palette.BRASS_HI)
	_side_mat.set_shader_parameter("emission_energy", maxf(_danger * 1.5, 0.3 if is_on else 0.0))


## Point set: lift 0.06 m, move to the box with an overshoot, flip, land.
func turn_on(n: int, to: Vector3, t: TuningData, reduced: bool) -> void:
	point = n
	number_label.text = str(n)
	is_on = true
	var dur := t.puck_move_time
	if reduced:
		position = to
		disc.rotation_degrees = Vector3(180, 0, 0)
		return
	var from := position
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(_arc.bind(from, to, 0.06), 0.0, 1.0, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(disc, "rotation_degrees:x", 180.0, dur * 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(disc, "scale", Vector3(1.05, 0.7, 1.05), 0.03)
	tw.chain().tween_property(disc, "scale", Vector3.ONE, 0.06)


## Back to OFF (reverse flip, 0.30 s).
func turn_off(to: Vector3, t: TuningData, reduced: bool) -> void:
	is_on = false
	point = 0
	glow.light_energy = 0.0
	if reduced:
		position = to
		disc.rotation_degrees = Vector3.ZERO
		return
	var from := position
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(_arc.bind(from, to, 0.05), 0.0, 1.0, t.puck_return_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(disc, "rotation_degrees:x", 0.0, t.puck_return_time)


func flash_danger() -> void:
	_danger = 1.0


func flash_glow() -> void:
	glow.light_energy = 1.2


func _arc(p: float, from: Vector3, to: Vector3, lift: float) -> void:
	position = from.lerp(to, p) + Vector3(0, lift * sin(PI * clampf(p, 0.0, 1.0)), 0)
