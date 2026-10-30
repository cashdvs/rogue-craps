## A small glowing number that floats over a d4's top point and always turns
## to face the camera (PM #198). A d4 has no face pointing up, so its printed
## marks lean away from the camera and are hard to read at 1x: this tag shows
## the value the die is reading (DieVisual.shown_value) straight on.
## Glow-only: just the ember number with a dark outline, no panel behind it.
class_name D4ValueTag
extends Label3D

## Ember text colour (the same warm orange as the lit hull outline).
const TAG_COLOR := Color("#F2B36B")
## Height above the die centre, in metres (just over the d4's 0.065 m cap).
const LIFT := 0.09
## Text size on screen. fixed_size keeps it this big at any camera distance,
## so it stays readable on the small phone framing too.
const FONT_PX := 40
const PIXEL := 0.0011

var die: DieVisual
## The d4's own glow colour (PolyBody sets it: a lighter body colour).
var glow_color := Color.WHITE


## Adds a tag to [param d] (a dressed d4) and returns it.
static func attach(d: DieVisual) -> D4ValueTag:
	var t := D4ValueTag.new()
	t.name = "D4ValueTag"
	t.die = d
	d.add_child(t)
	return t


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED  # always faces the camera
	fixed_size = true
	pixel_size = PIXEL
	font_size = FONT_PX
	outline_size = 12
	modulate = TAG_COLOR
	outline_modulate = Color(0.05, 0.02, 0.02, 0.9)
	shaded = false  # unlit: the table lamp's shadows never dim it
	no_depth_test = true  # drawn over the felt rim / other dice
	render_priority = 10


func _process(_delta: float) -> void:
	if die == null or not is_instance_valid(die):
		return
	# Stay above the die in world space, whichever way the die body tumbles.
	global_position = die.global_position + Vector3.UP * LIFT
	global_rotation = Vector3.ZERO
	text = str(die.shown_value())
	_keep_glow()


## DieGlow.clear (scripts/fx) zeroes emission when a die stops scoring, which
## would drop the d4 back to near black. While the die is not glowing for a
## score, put its own base glow (DieVisual.base_emission) back.
func _keep_glow() -> void:
	var m := die.body_material
	if m == null or die.has_meta("glow_rim_color"):
		return  # scoring glow is on: DieGlow owns the emission right now
	var want := die.base_emission + 0.12 * die.highlight
	if float(m.get_shader_parameter("emission_energy")) < want:
		m.set_shader_parameter("emission_energy", want)
		m.set_shader_parameter("emission_color", glow_color)
