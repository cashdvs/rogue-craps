## A small number next to a d4 that always turns to face the camera (PM
## #198). A d4 has no face pointing up, so its printed marks lean away from
## the camera and are hard to read at 1x: this tag shows the value the die
## is reading (DieVisual.shown_value) straight on. Glow-only wording: just
## the warm number with a dark outline, no panel behind it.
## AD #198: it must never cover HUD text (the seal row "Lv1 120x12" etc.):
## each frame it tries below, right of, left of and above the die (then
## slid and corner spots, see candidates()) and takes
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
## Extra px kept between the tag and any other die (QA #198: on phone the
## tag sat on the next d6 and read as that die's value).
const DIE_MARGIN := 6.0

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


## Screen rects (grown by DIE_MARGIN) of every other visible die on the
## table (Table3D.all_dice), so the tag never sits on a neighbour's pips.
func other_dice_rects(cam: Camera3D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var t: Node = die.get_parent()
	while t != null and not "all_dice" in t:
		t = t.get_parent()
	if t == null:
		return out
	for d in t.get("all_dice"):
		if d is DieVisual and d != die and is_instance_valid(d) and (d as DieVisual).is_visible_in_tree() \
				and not cam.is_position_behind((d as DieVisual).global_position):
			out.append(RulesPlaqueDodge.die_rect(cam, d).grow(DIE_MARGIN))
	return out


## Moves the tag next to the die where it covers no HUD text and no other
## die, or hides it. Try order (first clear spot wins): below, right, left,
## above; then (QA #198, a crowded phone table) the same sides slid along
## the die edge, then the 4 diagonal corners. See candidates().
func place(cam: Camera3D) -> void:
	var dr := RulesPlaqueDodge.die_rect(cam, die)
	var view := get_viewport().get_visible_rect()
	var hud := hud_rects().duplicate()
	hud.append_array(other_dice_rects(cam))  # never on another die either
	for p in candidates(dr, rect_at(cam, Vector2.ZERO).size * 0.5):
		var r := rect_at(cam, p)
		if view.encloses(r) and not hud.any(func(q: Rect2) -> bool: return q.intersects(r)):
			_put(cam, p)
			visible = true
			return
	visible = false


## Tag centres to try around die rect [param dr], best first. [param half]
## is half the tag size. The 4 plain sides come first, then each side slid
## by SLIDES (shares of the tag's height for left/right, of its width for
## below/above), then the corners: always hugging the die.
const SLIDES: Array[float] = [0.5, -0.5, 1.0, -1.0]
static func candidates(dr: Rect2, half: Vector2) -> Array[Vector2]:
	var c := dr.get_center()
	var below := dr.end.y + GAP + half.y
	var above := dr.position.y - GAP - half.y
	var right := dr.end.x + GAP + half.x
	var left := dr.position.x - GAP - half.x
	var out: Array[Vector2] = [Vector2(c.x, below), Vector2(right, c.y), Vector2(left, c.y), Vector2(c.x, above)]
	for k in SLIDES:
		var dy := k * half.y * 2.0
		var dx := k * half.x * 2.0
		out.append_array([Vector2(c.x + dx, below), Vector2(right, c.y + dy), Vector2(left, c.y + dy), Vector2(c.x + dx, above)])
	out.append_array([Vector2(right, below), Vector2(left, below), Vector2(right, above), Vector2(left, above)])
	return out


## Puts the tag's centre on screen point [param p], at the die's depth.
func _put(cam: Camera3D, p: Vector2) -> void:
	var depth := -(cam.global_transform.affine_inverse() * die.global_position).z  # along the view
	global_position = cam.project_position(p, depth)
