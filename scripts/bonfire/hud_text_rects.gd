## Screen rects of all the text a player reads on the table screen: 2D HUD
## labels / buttons / rich text, and the felt's own 3D labels (the combo
## strip "Five of a Kind" and the seal row "Lv1 120x12" are Label3D on the
## felt). Things that float over the table (the Nerve pip, the d4 value tag)
## use these as blockers so they never cover text (QA / AD #198).
class_name HudTextRects
extends RefCounted


## Text rects in [param vp] as [param cam] sees them. Nodes under any of
## [param skip] (the caller's own labels) are left out, and so are the d4
## value tags (D4ValueTag) themselves.
static func collect(vp: Viewport, cam: Camera3D, skip: Array[Node] = []) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for n in vp.find_children("*", "Control", true, false):
		if (n is Label or n is Button or n is RichTextLabel) and not _under(n, skip) and shows_text(n):
			out.append((n as Control).get_global_rect())
	if cam == null:
		return out
	for n in vp.find_children("*", "Label3D", true, false):
		var l := n as Label3D
		if l is D4ValueTag or _under(l, skip) or not l.is_visible_in_tree() or l.text.strip_edges() == "":
			continue
		if not cam.is_position_behind(l.global_position):
			out.append(label3d_rect(cam, l))
	return out


## True when [param c] is on screen with some text (an empty or faded-out
## label, like the hidden count-up, is not in the way).
static func shows_text(c: Control) -> bool:
	if not c.is_visible_in_tree() or not c.get_global_rect().has_area() or str(c.get("text")).strip_edges() == "":
		return false
	var n: Node = c
	while n is CanvasItem:
		if (n as CanvasItem).modulate.a < 0.05 or (n as CanvasItem).self_modulate.a < 0.05:
			return false
		n = n.get_parent()
	return true


## Screen rect of a 3D label: the bounds of its box's 8 corners.
static func label3d_rect(cam: Camera3D, l: Label3D) -> Rect2:
	var ab := l.get_aabb()
	var r := Rect2(cam.unproject_position(l.global_transform * ab.position), Vector2.ZERO)
	for i in 8:
		r = r.expand(cam.unproject_position(l.global_transform * ab.get_endpoint(i)))
	return r


static func _under(n: Node, skip: Array[Node]) -> bool:
	for s in skip:
		if is_instance_valid(s) and (n == s or s.is_ancestor_of(n)):
			return true
	return false
