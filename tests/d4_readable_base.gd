## Shared helpers for the Gallows d4 tests (not a test itself:
## test_d4_readable.gd and test_d4_crowded.gd extend it).
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


## The real scene in a SubViewport; the last of 5 sandbox dice is a Gallows d4.
func _make(canvas: Vector2i, nerve: int = 0) -> Array:
	var sv := SubViewport.new()
	sv.size = canvas
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(t, 5)
	st.nerve_uses = nerve
	st.dice[st.dice.size() - 1] = TableDie.new(DiceIds.DIE_GALLOWS, "Gallows", DiceIds.shape_of(DiceIds.DIE_GALLOWS))
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.bonfire_seed = 5
	s.test_speed = 10.0
	sv.add_child(s)
	await process_frame
	await process_frame
	return [sv, s]


func _die(s: Bonfire3D, shape: StringName) -> DieVisual:
	for d: DieVisual in s.all_dice:
		if d.shape == shape:
			return d
	return null


## Every piece of text on screen, worked out here (not with HudTextRects).
func _text_rects(s: Bonfire3D) -> Array:
	var out := []
	var cam := s.camera.cam
	for n in s.get_viewport().find_children("*", "Control", true, false):
		var c := n as Control
		var txt := str(c.get("text")).strip_edges()
		if (c is Label or c is Button) and txt != "" and c.is_visible_in_tree() and _seen(c):
			out.append([c.get_global_rect(), txt])
	for n in s.get_viewport().find_children("*", "Label3D", true, false):
		var l := n as Label3D
		if l.is_visible_in_tree() and l.text.strip_edges() != "" and not l is D4ValueTag:
			var ab := l.get_aabb()
			var r := Rect2(cam.unproject_position(l.global_transform * ab.get_endpoint(0)), Vector2.ZERO)
			for i in 8:
				r = r.expand(cam.unproject_position(l.global_transform * ab.get_endpoint(i)))
			out.append([r, l.text])
	return out


## False when [param c] or a parent is faded out (the hidden count-up "x").
func _seen(c: CanvasItem) -> bool:
	var n: Node = c
	while n is CanvasItem:
		if (n as CanvasItem).modulate.a <= 0.05 or (n as CanvasItem).self_modulate.a <= 0.05:
			return false
		n = n.get_parent()
	return true


## Tag rect from its font, worked out here: font px x pixel size x the
## camera's px per metre at 1 m (KEEP_HEIGHT: view height / 2 tan(fov/2)).
func _tag_rect(s: Bonfire3D, tag: Label3D) -> Rect2:
	var cam := s.camera.cam
	var view_h := s.get_viewport().get_visible_rect().size.y
	var h := tag.font_size * tag.pixel_size * view_h / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	var sz := Vector2(h * 0.62 * maxi(tag.text.length(), 1) + 0.25 * h, h)
	return Rect2(cam.unproject_position(tag.global_position) - sz * 0.5, sz)


func _tag_clear(s: Bonfire3D, tag: Label3D, label: String) -> void:
	for k in 20:  # the tag re-reads the HUD every 15 frames
		await process_frame
	if not tag.visible:
		check(true, "%s: tag hidden (no clear spot)" % label)
		return
	var r := _tag_rect(s, tag)
	var hits := []
	for t in _text_rects(s):
		if (t[0] as Rect2).intersects(r):
			hits.append(t[1])
	check(hits.is_empty(), "%s: tag %s covers no HUD text %s" % [label, str(r), str(hits)])


## Screen rect of a die's body mesh, worked out here (not the game's die_rect).
func _body_rect(cam: Camera3D, d: DieVisual) -> Rect2:
	var body := d.faces.get_node("Body") as MeshInstance3D
	var ab := body.get_aabb()
	var r := Rect2(cam.unproject_position(body.global_transform * ab.position), Vector2.ZERO)
	for i in 8:
		r = r.expand(cam.unproject_position(body.global_transform * ab.get_endpoint(i)))
	return r


## Is screen rect [param r] on screen but on one of [param rects]?
func _blocked(r: Rect2, rects: Array, view: Rect2) -> bool:
	return view.encloses(r) and rects.any(func(q: Rect2) -> bool: return q.intersects(r))
