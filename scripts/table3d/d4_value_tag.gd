## A small number next to a d4 that always turns to face the camera (PM
## #198). A d4 has no face pointing up, so its printed marks lean away from
## the camera and are hard to read at 1x: this tag shows the value the die
## is reading (DieVisual.shown_value) straight on. Glow-only wording: just
## the warm number with a dark outline, no panel behind it.
## AD #198: it must never cover HUD text (the seal row "Lv1 120x12" etc.):
## each frame it tries below, right of, left of and above the die and takes
## the first spot whose screen rect is clear of every HUD text rect
## (HudTextRects: 2D labels and the felt's 3D labels); with none it hides.
class_name D4ValueTag
extends Label3D

## Warm text colour (the lit hull outline's orange, lightened).
const TAG_COLOR := Color("#F2B36B")
## Tag font size; pixel size sets how big it draws (fixed_size: the same on
## screen at any camera distance).
const FONT_PX := 64
const PIXEL := 0.0003
## Tag height on screen at least this share of the viewport height, so it
## its digit (about 0.7 of the font height) stays >= 24 px on a 390 px tall
## phone: 0.09 * 390 = 35 px font, about 25 px digit.
const MIN_VIEW_SHARE := 0.09
## Screen-px gap between the die and the tag.
const GAP := 4.0
## How often (frames) the HUD text controls are re-collected.
const HUD_SCAN_EVERY := 15

var die: DieVisual
var _hud: Array[Rect2] = []
var _scan_in: int = 0


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
	font_size = FONT_PX
	pixel_size = PIXEL
	outline_size = 16
	modulate = TAG_COLOR
	outline_modulate = Color(0.05, 0.02, 0.02, 0.9)
	shaded = false  # unlit: the lamp's shadows never dim it
	no_depth_test = true
	render_priority = 10


func _process(_delta: float) -> void:
	if die == null or not is_instance_valid(die) or not die.is_visible_in_tree():
		return
	text = str(die.shown_value())
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	global_rotation = Vector3.ZERO
	_fit_size(cam)
	_scan_in -= 1
	if _scan_in <= 0:
		_scan_hud()
		_scan_in = HUD_SCAN_EVERY
	place(cam)


## Screen px per world metre at 1 m in front of [param cam] (what one
## fixed_size unit draws as). Measured by projecting, so it is right for any
## fov / keep_aspect / viewport.
func _px_per_unit(cam: Camera3D) -> float:
	var ahead := cam.global_position - cam.global_basis.z
	return absf(cam.unproject_position(ahead + cam.global_basis.y * 0.5).y - cam.unproject_position(ahead - cam.global_basis.y * 0.5).y)


## Grows pixel_size if the tag would be under MIN_VIEW_SHARE of the view.
func _fit_size(cam: Camera3D) -> void:
	var view_h := get_viewport().get_visible_rect().size.y
	pixel_size = maxf(PIXEL, MIN_VIEW_SHARE * view_h / (FONT_PX * _px_per_unit(cam)))


## The tag's font height on screen, px.
func screen_height(cam: Camera3D) -> float:
	return FONT_PX * pixel_size * _px_per_unit(cam)


## The tag's screen rect if its centre were at screen point [param c].
func rect_at(cam: Camera3D, c: Vector2) -> Rect2:
	var h := screen_height(cam)
	var sz := Vector2(h * 0.62 * maxi(text.length(), 1) + 0.25 * h, h)
	return Rect2(c - sz * 0.5, sz)


## Screen rect of the tag where it is now.
func screen_rect(cam: Camera3D) -> Rect2:
	return rect_at(cam, cam.unproject_position(global_position))


## HUD text to keep clear of (HudTextRects), re-read every HUD_SCAN_EVERY frames.
func _scan_hud() -> void:
	_hud = HudTextRects.collect(get_viewport(), get_viewport().get_camera_3d())


## Screen rects of all HUD text showing now (as of the last scan).
func hud_rects() -> Array[Rect2]:
	return _hud


## Moves the tag next to the die where it covers no HUD text, or hides it.
func place(cam: Camera3D) -> void:
	var dr := RulesPlaqueDodge.die_rect(cam, die)
	var view := get_viewport().get_visible_rect()
	var half := rect_at(cam, Vector2.ZERO).size * 0.5
	var c := dr.get_center()
	var hud := hud_rects()
	var spots: Array[Vector2] = [
		Vector2(c.x, dr.end.y + GAP + half.y), Vector2(dr.end.x + GAP + half.x, c.y),
		Vector2(dr.position.x - GAP - half.x, c.y), Vector2(c.x, dr.position.y - GAP - half.y)]
	for p in spots:
		var r := rect_at(cam, p)
		if view.encloses(r) and not hud.any(func(q: Rect2) -> bool: return q.intersects(r)):
			_put(cam, p)
			visible = true
			return
	visible = false


## Puts the tag's centre on screen point [param p], at the die's depth.
func _put(cam: Camera3D, p: Vector2) -> void:
	var depth := -(cam.global_transform.affine_inverse() * die.global_position).z  # along the view
	global_position = cam.project_position(p, depth)
