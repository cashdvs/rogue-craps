## After a throw settles, slides any die whose screen box sits under a HUD
## button or the Soul lantern plate (the "35/35" counter) out onto open
## felt. The buttons stay where the layout put them. Only the position
## changes, so the face on top stays the face that was rolled, and the
## slide is the same every time for the same pose (no random numbers).
## Phone landscape still uses PhoneFrame.clamp_rest first (#204): that
## pulls dice into the rows between the goal plate and the bottom bar.
class_name HudRestClear
extends RefCounted

## Screen-px gap kept between a resting die and the control hiding it.
const GAP_PX := 8.0
## How far (metres) one step of the slide moves the die along the felt.
const STEP_M := 0.012
## Steps along one direction before trying the next (about 0.77 m).
const MAX_STEPS := 64
## Compass slides tried after "away from the button" and "toward centre".
const COMPASS: Array[Vector3] = [
	Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1),
	Vector3(0.7071, 0, -0.7071), Vector3(-0.7071, 0, -0.7071),
	Vector3(0.7071, 0, 0.7071), Vector3(-0.7071, 0, 0.7071),
]


## Phone-landscape row clamp, then the HUD slide. True if a die moved.
static func apply(t: BonfireTableLayout) -> bool:
	var moved := false
	if t.phone_screen.y > 0.0 and t.phone_screen.x >= t.phone_screen.y:
		moved = PhoneFrame.clamp_rest(t.throw_dice, t.tuning.die_size)
	if t.camera == null or t.camera.cam == null:
		return moved
	return clear(t.camera.cam, t.throw_dice, blockers(t), t.tuning.die_size) or moved


## Screen rects that hide a resting die: every visible HUD button, the
## phone bottom bar, and the Soul lantern's digit plate. Clipped to the
## viewport, then grown by GAP_PX. Off-screen controls are left out.
static func blockers(t: BonfireTableLayout) -> Array[Rect2]:
	var view := Rect2(Vector2.ZERO, t.get_viewport().get_visible_rect().size)
	var out: Array[Rect2] = []
	var hud := t.bhud
	if hud != null:
		for n: Node in hud.find_children("*", "Button", true, false):
			var b := n as Button
			if b.is_visible_in_tree() and str(b.text).strip_edges() != "":
				_add(out, b.get_global_rect(), view)
		var bar := hud.bottom_bar
		if bar != null and bar.visible and bar.is_visible_in_tree():
			_add(out, bar.get_global_rect(), view)
	if t.reliquary != null:
		_add(out, t.reliquary_rect(), view)
	return out


## Slides [param dice] until each one's screen box misses [param blockers].
## [param die_size] is the cube edge in metres. True if a die moved.
static func clear(cam: Camera3D, dice: Array[DieVisual], blockers: Array[Rect2], die_size: float) -> bool:
	if blockers.is_empty():
		return false
	var lim := Vector2(Table3DBuilder.FELT_HALF.x, Table3DBuilder.FELT_HALF.y) - Vector2.ONE * die_size * 0.55
	var moved := false
	# Two passes: the first die can stop where the next one needs to be.
	for _pass in 2:
		for d in dice:
			if _slide(d, dice, cam, blockers, die_size, lim):
				moved = true
	return moved


static func _add(out: Array[Rect2], r: Rect2, view: Rect2) -> void:
	var clipped := r.intersection(view)
	if clipped.has_area():
		out.append(clipped.grow(GAP_PX))


## One die. Restores the basis so the up face cannot change. The first
## direction that finds a clear spot wins (that list is fixed).
static func _slide(d: DieVisual, dice: Array[DieVisual], cam: Camera3D, blockers: Array[Rect2], die_size: float, lim: Vector2) -> bool:
	if not _hits(d, cam, blockers):
		return false
	var origin := d.global_position
	var kept := d.global_transform.basis
	var best := origin
	var found := false
	for dir in _dirs(d, cam, blockers):
		var p := origin
		for _step in MAX_STEPS:
			p += dir * STEP_M
			if absf(p.x) > lim.x or absf(p.z) > lim.y:
				# Still walking in from outside the felt; stop if we leave it.
				if absf(p.x) > absf(origin.x) + 0.001 or absf(p.z) > absf(origin.z) + 0.001:
					break
				continue
			_put(d, p, kept)
			if _hits(d, cam, blockers) or _crowded(d, dice, die_size):
				continue
			best = p
			found = true
			break
		_put(d, origin, kept)
		if found:
			break
	_put(d, best, kept)
	return found and not best.is_equal_approx(origin)


static func _put(d: DieVisual, p: Vector3, kept: Basis) -> void:
	d.global_transform = Transform3D(kept, p)


## True when the die's screen box overlaps a blocker (or it is behind the camera).
static func _hits(d: DieVisual, cam: Camera3D, blockers: Array[Rect2]) -> bool:
	if cam.is_position_behind(d.global_position):
		return false
	var r := RulesPlaqueDodge.die_rect(cam, d)
	for b in blockers:
		if r.intersects(b):
			return true
	return false


## Another resting die is too close to share this spot.
static func _crowded(d: DieVisual, dice: Array[DieVisual], die_size: float) -> bool:
	for o in dice:
		if o == d:
			continue
		var gap := Vector2(o.global_position.x - d.global_position.x, o.global_position.z - d.global_position.z)
		if gap.length() < die_size * 1.15:
			return true
	return false


## Slide directions, best first: away from the blocker that covers the
## most of the die, then toward the middle of the felt, then the compass.
static func _dirs(d: DieVisual, cam: Camera3D, blockers: Array[Rect2]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var away := _away(d, cam, blockers)
	if away.length_squared() > 0.01:
		out.append(away)
	var to_c := Vector3(-d.global_position.x, 0.0, -d.global_position.z)
	if to_c.length_squared() > 0.0001:
		out.append(to_c.normalized())
	out.append_array(COMPASS)
	return out


## Felt direction that walks the die off the blocker covering it most.
static func _away(d: DieVisual, cam: Camera3D, blockers: Array[Rect2]) -> Vector3:
	var box := RulesPlaqueDodge.die_rect(cam, d)
	var hit := Rect2()
	var most := 0.0
	for b in blockers:
		if not box.intersects(b):
			continue
		var area := box.intersection(b).get_area()
		if area > most:
			most = area
			hit = b
	if most <= 0.0:
		return Vector3.ZERO
	var sp := cam.unproject_position(d.global_position)
	var delta := sp - hit.get_center()
	# The centre sits on the control: step right and up the screen.
	if delta.length() < 1.0:
		delta = Vector2(1, -1)
	return _felt_dir(cam, d.global_position, delta.normalized() * 48.0)


## A screen-pixel step, turned into a direction along the felt (y stays).
static func _felt_dir(cam: Camera3D, origin: Vector3, screen_delta: Vector2) -> Vector3:
	if cam.is_position_behind(origin):
		return Vector3.ZERO
	var sp := cam.unproject_position(origin)
	var depth := -(cam.global_transform.affine_inverse() * origin).z
	if depth <= 0.05:
		return Vector3.ZERO
	var world := cam.project_position(sp + screen_delta, depth)
	var flat := world - origin
	flat.y = 0.0
	return flat.normalized() if flat.length() > 0.0001 else Vector3.ZERO
