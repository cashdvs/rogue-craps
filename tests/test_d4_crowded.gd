## AD #198 / QA: the Gallows d4's value tag in QA's crowded phone case
## (mid-hand, Nerve showing): all 4 plain spots blocked (QA saw combo strip,
## 'Nerve ready', a d6, a card title; the Target HUD and #204 moved those, so
## parked d6s stand in for them). The tag still shows (a slid / corner spot),
## on no text, and >= 4 px clear of every other die. Split out of
## test_d4_readable.gd to keep files under 400 lines.
##   godot --headless --path . --script res://tests/test_d4_crowded.gd
extends "res://tests/d4_readable_base.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var m: Array = await _make(Vector2i(2337, 1080), 1)
	(m[1] as Bonfire3D).fit_phone(Vector2(844, 390))
	await _check_crowded(m[1])
	(m[0] as Node).queue_free()
	await process_frame
	print("test_d4_crowded: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## [param scan]: walks the felt for the first d4 spot (the d6 0.12 m to its
## left) where all 4 plain tag spots are blocked, and parks both there.
## Not [param scan]: just re-checks the spot they are on now.
## Target HUD v2.1: the bounty-card titles are gone, so a 2nd d6 [param up]
## parked above the d4 can stand in for the text that blocked the top spot,
## and (the Target plate moved, #204 drops the felt combo strip) a 3rd d6
## [param dn] below it for the combo strip; [param rt] (null: none) on the
## right when 'Nerve ready' isn't beside it.
func _park_crowded(s: Bonfire3D, d4: DieVisual, nb: DieVisual, up: DieVisual, dn: DieVisual, rt: DieVisual, size: Vector2, scan: bool) -> bool:
	var cam := s.camera.cam
	var view := s.get_viewport().get_visible_rect()
	var texts: Array = _text_rects(s).map(func(t: Array) -> Rect2: return t[0])
	var y := d4.global_position.y
	var h := size * 0.5
	var spot := func(p: Vector2) -> Rect2: return Rect2(p - h, size)
	var z := -0.4 if scan else d4.global_position.z
	while z <= 0.5:
		var x := -0.8 if scan else d4.global_position.x
		while x <= 0.8:
			d4.global_position = Vector3(x, y, z)
			nb.global_position = Vector3(x - 0.12, y, z)
			up.global_position = Vector3(x, y, z - 0.12)
			dn.global_position = Vector3(x, y, z + 0.12)
			if rt != null:
				rt.global_position = Vector3(x + 0.12, y, z)
			var dr := RulesPlaqueDodge.die_rect(cam, d4)  # the die box the tag hugs
			var c := dr.get_center()
			if not texts.any(func(q: Rect2) -> bool: return q.intersects(dr.grow(4))) \
					and _blocked(spot.call(Vector2(c.x, dr.end.y + 4 + h.y)), texts + [RulesPlaqueDodge.die_rect(cam, dn)], view) \
					and _blocked(spot.call(Vector2(dr.end.x + 4 + h.x, c.y)), texts + ([RulesPlaqueDodge.die_rect(cam, rt)] if rt != null else []), view) \
					and _blocked(spot.call(Vector2(dr.position.x - 4 - h.x, c.y)), [RulesPlaqueDodge.die_rect(cam, nb)], view) \
					and _blocked(spot.call(Vector2(c.x, dr.position.y - 4 - h.y)), texts + [RulesPlaqueDodge.die_rect(cam, up)], view):
				return true
			if not scan:
				return false
			x += 0.01
		z += 0.01
	return false


## QA #198 phone layout: mid-hand with Nerve showing, a d6 just left of the
## d4. Scans the felt for a d4 spot where all 4 plain tag spots (below,
## right, left, above; worked out here) are blocked as QA saw (left by the
## d6, the other 3 by HUD text), parks it there and checks the tag.
func _check_crowded(s: Bonfire3D) -> void:
	for k in 600:
		if s.phase == Table3D.Phase.BET and s.run.state == BonfireRun.State.AIM and not s.hand_moving():
			break
		await process_frame
	s.quick_throw()
	await s.sequence_finished
	s.nerve_ui.refresh()
	for k in 20:
		await process_frame
	var d4 := _die(s, &"d4")
	var tag := d4.get_node("D4ValueTag") as Label3D
	var cam := s.camera.cam
	var view := s.get_viewport().get_visible_rect()
	check(s.nerve_ui.pip_box.is_visible_in_tree(), "crowded: Nerve showing mid-hand")
	var nb: DieVisual = null
	var up: DieVisual = null
	var dn: DieVisual = null
	var rt: DieVisual = null
	for d: DieVisual in s.all_dice:
		if d != d4 and nb == null:
			nb = d
		elif d != d4 and d != nb and up == null:
			up = d
		elif d != d4 and d != nb and d != up and dn == null:
			dn = d
		elif d != d4 and d != nb and d != up and d != dn and rt == null:
			rt = d
	var far := Vector3(0.0, d4.global_position.y, -5.0)
	for d: DieVisual in s.all_dice:  # clear the felt but for the d4 + its neighbour
		if d != d4 and d != nb and d != up and d != dn and d != rt:
			d.global_position = far
	var found := false
	for tries in 6:  # the Nerve UI moves off dice, so rescan until it settles
		found = _park_crowded(s, d4, nb, up, dn, rt, _tag_rect(s, tag).size, true)
		for k in 20:  # the tag re-reads the HUD every 15 frames
			await process_frame
		if found and _park_crowded(s, d4, nb, up, dn, rt, _tag_rect(s, tag).size, false):
			break
		found = false
	check(found, "crowded: QA's layout (all 4 plain spots blocked) found on the phone felt")
	if not found:
		return
	print("crowded: d4 at ", d4.global_position)
	check(tag.visible, "crowded: tag still shows with all 4 plain spots blocked")
	if not tag.visible:
		return
	var r := _tag_rect(s, tag)
	var hits := []
	for t in _text_rects(s):
		if (t[0] as Rect2).intersects(r):
			hits.append(t[1])
	check(hits.is_empty(), "crowded: tag %s covers no HUD text %s" % [str(r), str(hits)])
	var nr := RulesPlaqueDodge.die_rect(cam, nb)
	check(not nr.grow(4).intersects(r), "crowded: tag %s >= 4 px clear of the d6 %s" % [str(r), str(nr)])
	var ur := RulesPlaqueDodge.die_rect(cam, up)
	check(not ur.grow(4).intersects(r), "crowded: tag %s >= 4 px clear of the d6 above %s" % [str(r), str(ur)])
	var dnr := RulesPlaqueDodge.die_rect(cam, dn)
	check(not dnr.grow(4).intersects(r), "crowded: tag %s >= 4 px clear of the d6 below %s" % [str(r), str(dnr)])
	if rt != null:
		check(not RulesPlaqueDodge.die_rect(cam, rt).grow(4).intersects(r), "crowded: tag >= 4 px clear of the d6 right")
	check(view.encloses(r), "crowded: tag on screen")
