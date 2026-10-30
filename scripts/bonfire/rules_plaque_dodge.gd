## Keeps the table-rules plaque (Powder Barrel row) off the thrown dice:
## at 844x390 a die near the right edge can land under it. The plaque moves
## left of, below or above the dice it covers, whichever first fits on
## screen clear of them; with no clear spot it keeps the least overlap.
class_name RulesPlaqueDodge
extends RefCounted

## Screen-px gap kept between the plaque and a die.
const GAP := 6.0


## Screen rect of [param d] as [param cam] sees it: the bounds of a cube
## 1.5 die edges wide around it (covers any tumble and the hull outline).
static func die_rect(cam: Camera3D, d: DieVisual) -> Rect2:
	var c := d.global_position
	var h := d.edge * 0.75
	var r := Rect2(cam.unproject_position(c), Vector2.ZERO)
	for x in [-h, h]:
		for y in [-h, h]:
			for z in [-h, h]:
				r = r.expand(cam.unproject_position(c + Vector3(x, y, z)))
	return r


## Where the plaque [param r] should go (top-left, screen px) so it covers
## none of [param dice] and stays inside [param view].
static func place(r: Rect2, dice: Array[Rect2], view: Rect2) -> Vector2:
	var hit := dice.filter(func(d: Rect2) -> bool: return d.intersects(r))
	if hit.is_empty():
		return r.position
	var box: Rect2 = hit[0]
	for d: Rect2 in hit:
		box = box.merge(d)
	var tries: Array[Vector2] = [
		Vector2(box.position.x - GAP - r.size.x, r.position.y),
		Vector2(r.position.x, box.end.y + GAP),
		Vector2(r.position.x, box.position.y - GAP - r.size.y),
		Vector2(box.end.x + GAP, r.position.y),
	]
	var best := _clamp(r.position, r.size, view)
	var least := _overlap(Rect2(best, r.size), dice)
	for p in tries:
		var q := _clamp(p, r.size, view)
		var o := _overlap(Rect2(q, r.size), dice)
		if o <= 0.0:
			return q
		if o < least:
			best = q
			least = o
	return best


static func _clamp(p: Vector2, sz: Vector2, view: Rect2) -> Vector2:
	return Vector2(clampf(p.x, view.position.x, maxf(view.position.x, view.end.x - sz.x)),
			clampf(p.y, view.position.y, maxf(view.position.y, view.end.y - sz.y)))


static func _overlap(r: Rect2, dice: Array[Rect2]) -> float:
	var a := 0.0
	for d in dice:
		a += r.intersection(d).get_area()
	return a
