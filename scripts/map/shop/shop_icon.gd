## The picture of one counter item (HANDOFF_SPEC §5).
## - Dice: the real 3D model, looked at 3/4 from above in a small
##   SubViewport. The model file is picked by the offer's art key, so a new
##   die needs no code here, only its .glb.
## - Everything else is a token: a bone disc with a brass ring and a carved
##   glyph, chosen by art key from the GLYPHS table below.
class_name ShopIcon
extends Control

const BONE := Color("#E8DCC0")
const BRASS := Color("#C9A24A")
const INK := Color("#1E1712")
## Icon rig lights (see _add_lights).
const KEY_COLOR := Color("#FFEAD0")
const KEY_ENERGY := 2.1
const FILL_COLOR := Color("#E6E0D6")
const FILL_ENERGY := 0.45
const AMBIENT_COLOR := Color("#A89A88")
const AMBIENT_ENERGY := 0.6

## Which glyph each art key carves. Keys not listed get their first letter.
## Seals ("seal_<combo>") draw an inner ring plus the combo's pips instead.
const GLYPHS := {
	&"mod_wild": "spark", &"mod_twin": "twin", &"mod_gilded": "coin",
	&"mod_ember_pip": "ring_dot", &"soul": "bottle",
}
## Pips shown inside a Seal token, by combo. Unlisted combos show a bar.
const SEAL_PIPS := {&"pair": 2, &"trips": 3, &"two_pair": 4, &"quads": 4, &"full_house": 5}

var offer: ShopOffer
## The 3D view for dice (null for tokens). Tests read it.
var die_view: SubViewport


## Size the icon and build its contents for `o`.
func setup(o: ShopOffer, px: float) -> void:
	offer = o
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if o.kind == ShopOffer.Kind.DIE:
		_build_die(px)
	queue_redraw()


## Path of the model for art key `key` ("" if the file doesn't exist).
static func model_path(key: StringName) -> String:
	var p := "res://art/models/dice/%s.glb" % key
	return p if ResourceLoader.exists(p) else ""


func _build_die(px: float) -> void:
	var path := model_path(offer.art_key)
	if path == "":
		return  # No model yet: _draw shows a plain bone die instead.
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	die_view = SubViewport.new()
	die_view.transparent_bg = true
	die_view.own_world_3d = true
	die_view.size = Vector2i(int(px), int(px))
	box.add_child(die_view)
	var model: Node3D = (load(path) as PackedScene).instantiate()
	die_view.add_child(model)
	# Fit any model size: centre it and scale its widest side to 1 unit.
	var aabb := _bounds(model)
	var s := 1.0 / maxf(aabb.get_longest_axis_size(), 0.001)
	model.scale = Vector3.ONE * s
	model.position = -aabb.get_center() * s
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.75
	die_view.add_child(cam)
	cam.look_at_from_position(Vector3(1.4, 1.6, 1.8), Vector3.ZERO)
	_add_lights()


## The icon rig (AD review): a warm key light from the camera's upper left so
## bone reads cream, a soft neutral fill from the other side so shadow faces
## keep their detail, and a dim warm ambient. Materials are untouched.
func _add_lights() -> void:
	for l: Array in [[KEY_COLOR, KEY_ENERGY, Vector3(0.6, 3.0, 2.4)], [FILL_COLOR, FILL_ENERGY, Vector3(2.6, 0.8, -0.6)]]:
		var light := DirectionalLight3D.new()
		light.light_color = l[0]
		light.light_energy = l[1]
		die_view.add_child(light)
		light.look_at_from_position(l[2], Vector3.ZERO)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = AMBIENT_COLOR
	env.environment.ambient_light_energy = AMBIENT_ENERGY
	die_view.add_child(env)


## The combined box around every mesh under `n` (in n's own space).
static func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var rel := _rel(n, mi)
		var b := rel * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Transform of `child` relative to `root` (works before entering the tree).
static func _rel(root: Node3D, child: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = child
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _draw() -> void:
	if offer == null:
		return
	var px := size.x
	var c := size / 2.0
	if offer.kind == ShopOffer.Kind.DIE:
		if die_view == null:  # Fallback die: a bone tile with one pip.
			draw_rect(Rect2(Vector2.ONE * px * 0.1, Vector2.ONE * px * 0.8), BONE)
			draw_circle(c, px * 0.08, INK)
		return
	var r := px * 0.48
	draw_circle(c, r, BRASS)
	draw_circle(c, r * (0.78 if offer.kind == ShopOffer.Kind.RARE_SEAL else 0.88), BONE)
	if offer.kind == ShopOffer.Kind.SEAL or offer.kind == ShopOffer.Kind.RARE_SEAL:
		_draw_seal(c, r)
	else:
		_draw_glyph(String(GLYPHS.get(offer.art_key, "")), c, r)


func _draw_seal(c: Vector2, r: float) -> void:
	var rare := offer.kind == ShopOffer.Kind.RARE_SEAL
	draw_arc(c, r * 0.62, 0, TAU, 40, BRASS if rare else INK, r * (0.16 if rare else 0.07), true)
	var n: int = SEAL_PIPS.get(offer.id, 0)
	if rare or n == 0:
		draw_rect(Rect2(c - Vector2(r * 0.32, r * 0.08), Vector2(r * 0.64, r * 0.16)), INK)
		return
	for p: Vector2 in DiceIcons.PIPS[n]:
		draw_circle(c + p * r * 0.22, r * 0.12, INK)


func _draw_glyph(g: String, c: Vector2, r: float) -> void:
	match g:
		"spark":  # Wild: a 4-point star.
			var pts := PackedVector2Array()
			for k in 8:
				var a := k * TAU / 8.0 - PI / 2.0
				pts.append(c + Vector2.from_angle(a) * r * (0.55 if k % 2 == 0 else 0.14))
			draw_colored_polygon(pts, INK)
		"twin":  # Twin: two overlapping dice.
			draw_rect(Rect2(c + Vector2(-0.45, -0.45) * r, Vector2.ONE * r * 0.5), INK)
			draw_rect(Rect2(c + Vector2(-0.08, -0.08) * r, Vector2.ONE * r * 0.55), INK, false, r * 0.08)
			draw_circle(c + Vector2(0.2, 0.2) * r, r * 0.08, INK)
		"coin":  # Gilded: a coin with a slot.
			draw_arc(c, r * 0.45, 0, TAU, 40, INK, r * 0.1, true)
			draw_rect(Rect2(c - Vector2(r * 0.07, r * 0.25), Vector2(r * 0.14, r * 0.5)), INK)
		"ring_dot":  # Ember Pip: a dot inside a ring.
			draw_arc(c, r * 0.42, 0, TAU, 40, INK, r * 0.08, true)
			draw_circle(c, r * 0.18, INK)
		"bottle":  # Soul Draught: a bottle.
			draw_rect(Rect2(c + Vector2(-0.12, -0.55) * r, Vector2(0.24, 0.25) * r), INK)
			draw_rect(Rect2(c + Vector2(-0.35, -0.3) * r, Vector2(0.7, 0.8) * r), INK)
		_:  # Any other mod: its first letter, carved.
			var f := RunTheme.title_font
			var t := offer.display_name.left(1).to_upper()
			var fs := int(r)
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, c + Vector2(-w.x / 2.0, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
