## Layer 3 of the Bonfire table: camera, screen fit and where things sit.
## Phone / landscape felt fitting, the pot row, the hand spot, and turning a
## screen point into a die.
@abstract
class_name BonfireTableLayout
extends BonfireTableLook

## The 3D Soul Reliquary that replaces the flat Soul bar (#167).
var reliquary: SoulReliquaryHookup
## Windows shorter than this (real pixels) use the phone Reliquary.
const SHORT_WINDOW_PX := 720
## Pretend window size for tests (zero = use the real window).
var window_px_override := Vector2i.ZERO


## HUD numbers before a pot is committed (shown until its count-up lands).
func _display_snapshot(sel: Dictionary) -> Dictionary:
	return {"embers": run.embers, "points": run.points, "pot_from": run.pot, "pot_add": int(sel.get("points", 0)), "f": 0.0}


## Holds the HUD numbers while the count-up plays (not under Instant); the
## count-up landing, a fast-forward or a new hand releases them.
func _hold_display(hold: Dictionary) -> void:
	if speed_mode == 2 or not bhud.countup.is_playing():
		_release_display()
		return
	bhud.display_hold = hold
	_refresh_hud()


func _release_display() -> void:
	if bhud.display_hold.is_empty():
		return
	bhud.display_hold = {}
	_refresh_hud()


func die_at_screen(p: Vector2) -> int:
	var best := -1
	var best_d := PICK_RADIUS_PX
	for i in throw_dice.size():
		var sp := camera.cam.unproject_position(throw_dice[i].global_position)
		var dist := sp.distance_to(p)
		if dist < best_d:
			best_d = dist
			best = i
	return best


# --- Table3D hooks ----------------------------------------------------------------

## Phone portrait (the screen is taller than wide) shows the goal readout at
## the top; PC and phone landscape hide it (the plaque and cards are in view).
func _update_portrait_hud() -> void:
	if bhud == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var portrait := vs.y > vs.x
	_place_reliquary()
	bhud.set_portrait(portrait)
	var phone_land := not portrait and phone_screen.y > 0.0 and phone_screen.x >= phone_screen.y
	bhud.set_ui_scale(ui_pt_px(portrait), BonfireHud.PHONE_LANDSCAPE_CARDS if phone_land else 1.0)
	if felt_combos != null:
		felt_combos.set_portrait(portrait, portrait and portrait_felt_flipped())
		if not portrait:
			_fit_landscape_felt()


## Portrait: the Art Director drew the portrait combo block for a camera
## with the felt's +X end at the TOP of the screen (the near-rail end, -X,
## at the bottom). True if this camera shows it the other way round, so the
## print must turn 180 deg.
func portrait_felt_flipped() -> bool:
	if camera == null or camera.cam == null:
		return false
	var top := camera.cam.unproject_position(Vector3(0.9, 0, 0))
	var bottom := camera.cam.unproject_position(Vector3(-0.9, 0, 0))
	return top.y > bottom.y


## Design px per pt for the 2D art (bounty cards, banner): the Art
## Director's UI scale 2.0 on PC; on a phone, whatever keeps a pt a pt
## (390 pt wide portrait: 1920 / 390; 390 pt tall landscape: 1080 / 390).
func ui_pt_px(portrait: bool) -> float:
	if portrait:
		return 1920.0 / (phone_screen.x if phone_screen.x > 0.0 and phone_screen.x < phone_screen.y else 390.0)
	if phone_screen.y > 0.0 and phone_screen.x >= phone_screen.y:
		return maxf(2.0, 1080.0 / phone_screen.y)
	return 2.0


## True if a press at screen point p would grab the dice waiting in the hand.
func hand_grab_at(p: Vector2) -> bool:
	return phase == Phase.BET and can_throw() == "" and _hand_contains(p)


## True if a press at screen point p lands on a thrown die while picking
## (it pots the die, or shakes it if it can't score).
func die_pick_at(p: Vector2) -> bool:
	return phase == Phase.BET and run != null and run.state == BonfireRun.State.PICK and die_at_screen(p) >= 0


## A handful in the hand: a tight ring around HAND (a 5-wide row would
## start the outer dice in the rail).
func hand_spot(i: int) -> Vector3:
	var n := maxi(dice.size(), 1)
	if n == 1:
		return HAND + Vector3(0, tuning.die_size * 0.5, 0)
	var r := tuning.die_size * 0.6 / sin(PI / float(n))
	r = maxf(r, tuning.die_size * 0.65)
	# Big handfuls: keep the whole ring on the felt.
	var margin := tuning.die_size * 0.75
	var c := HAND
	c.x = minf(c.x, Table3DBuilder.FELT_HALF.x - r - margin)
	c.z = minf(c.z, Table3DBuilder.FELT_HALF.y - r * 0.9 - margin)
	var a := TAU * float(i) / float(n) + 0.3
	return c + Vector3(cos(a) * r, tuning.die_size * 0.5, sin(a) * r * 0.9)


## Potted dice of this throw slide to the pot (after earlier throws' dice);
## the rest sit where they landed.
func _layout_throw() -> void:
	var slot := pot_dice.size()
	for i in throw_dice.size():
		var d := throw_dice[i]
		var to := _felt_pos[i]
		if run.potted.has(i):
			to = pot_slot(slot)
			_clear_slot(to, d)
			slot += 1
		var tw := d.create_tween()
		tw.tween_property(d, "global_position", to, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func pot_slot(k: int) -> Vector3:
	return POT_ORIGIN + Vector3(k * POT_GAP, tuning.die_size * 0.5, 0)


## Bonfire's own home framing (BonfireTuning "Game camera") over the shared
## TuningData (a copy, so the PoC table keeps the spec camera).
func _apply_camera_tuning() -> void:
	if tuning == null or bonfire_tuning == null:
		return
	tuning = tuning.duplicate() as TuningData
	tuning.cam_pitch_deg = bonfire_tuning.cam_pitch_deg
	tuning.cam_distance = bonfire_tuning.cam_distance
	tuning.cam_pivot = bonfire_tuning.cam_pivot
	tuning.cam_look_up_deg = bonfire_tuning.cam_look_up_deg


func fit_phone(size: Vector2) -> float:
	phone_screen = size
	if size.x >= size.y:
		return _fit_phone_landscape()
	var px := super(size)
	var n := maxi(setup.dice.size() if setup != null else 5, 1)
	var must: Array[Vector3] = [pot_slot(0) + Vector3(0, PILLAR_HEIGHT, 0), pot_slot(n - 1) + Vector3(0, tuning.die_size, 0),
		pot_slot(0) + Vector3(0, tuning.die_size, 0), hand_spot(0), hand_spot(1)]
	var with_dial := must.duplicate()
	with_dial.append(NEAR_DIAL_TOP)
	var base := camera.home_pivot
	var r := _slide_for(base, with_dial)
	phone_dial_visible = r[1] >= 0.0
	if not phone_dial_visible:
		r = _slide_for(base, must)
	# Still hugging an edge (under the HUD bar)? Dolly out a little while
	# the dice stay >= min_die_px.
	for step in 40:
		if r[1] >= PHONE_EDGE_PX:
			break
		var d := camera.home_distance
		camera.home_distance = d * 1.03
		camera.distance = camera.home_distance
		var r2 := _slide_for(base, with_dial if phone_dial_visible else must)
		var die_px := _smallest_die_px(must)
		if r2[1] <= r[1] or die_px < tuning.min_die_px:
			camera.home_distance = d
			camera.distance = d
			break
		r = r2
		px = minf(px, die_px)
	camera.home_pivot = base + Vector3(0, 0, r[0])
	camera.position = camera.home_pivot
	camera._apply()
	if felt_combos != null:
		# The felt combo block, shrunk into this framing (8 pt margins).
		var view := get_viewport().get_visible_rect().size
		felt_combos.set_portrait(true, portrait_felt_flipped())
		felt_combos.fit_portrait_view(camera.cam, view, 8.0 * view.x / maxf(size.x, 1.0))
	return px


## Landscape: keep the felt combo band clear of the Soul meter on the left
## and the screen's right edge (8 pt margins) for this camera framing.
func _fit_landscape_felt() -> void:
	if felt_combos == null or camera == null:
		return
	var vs := get_viewport().get_visible_rect().size
	# 16:9 and narrower keep the band exactly as the Art Director drew it.
	if vs.x <= vs.y * 16.0 / 9.0 + 1.0:
		felt_combos.set_land_fit(1.0, 0.0)
		return
	var margin := 8.0 * ui_pt_px(false)
	var left := margin
	var plate := reliquary_rect()
	if plate.size.x > 0.0:
		left = plate.end.x + margin
	# The band must fit every pose the camera takes in play: home, and the
	# reveal glide (closer in, pivot slid up to cam_follow_clamp each way).
	# Home must fit both edges; in the glide only the left end (under the
	# Soul meter) counts, since the right end just runs off the screen.
	var c := tuning.cam_follow_clamp
	var close := minf(tuning.cam_reveal_distance, camera.home_distance)
	var hp := camera.home_pivot
	var poses: Array = [[hp, camera.home_distance]]
	for px: float in [-c, 0.0, c]:
		for pz: float in [-c, 0.0, c]:
			poses.append([Vector3(px, 0.0, pz + hp.z), close])
	# ok[i] is true while size/slide candidate i fits every pose so far.
	# Candidates: size 100% down to 70%, slide -0.30..+0.30 m in 5 mm steps.
	var ok: Array[bool] = []
	ok.resize(31 * 121)
	ok.fill(true)
	var was_pos := camera.position
	var was_dist := camera.distance
	var was_tilt := camera.tilt_deg
	for pose: Array in poses:
		camera.position = pose[0]
		camera.distance = pose[1]
		camera.tilt_deg = 0.0
		camera._apply()
		for i in ok.size():
			if ok[i]:
				var right := vs.x - margin if pose == poses[0] else INF
				ok[i] = felt_combos.land_fits(camera.cam, (100 - i / 121) / 100.0, (i % 121 - 60) * 0.005, left, right)
	camera.position = was_pos
	camera.distance = was_dist
	camera.tilt_deg = was_tilt
	camera._apply()
	# Biggest size that fits; for that size, the smallest slide.
	var k := 0.70
	var sx := 0.0
	var found := false
	for ki in 31:
		for si in 121:
			var shift := (si - 60) * 0.005
			if ok[ki * 121 + si] and (not found or absf(shift) < absf(sx)):
				sx = shift
				found = true
		if found:
			k = (100 - ki) / 100.0
			break
	felt_combos.set_land_fit(k, sx)


## Phone landscape: the home framing's pitch and tilt, closer in and
## centred (BonfireTuning cam_phone_landscape_*), so the whole felt, the
## near rail and the TotalPlate are in frame with dice as big as the old
## hand-centred phone framing. Dollies out a little if a must-see point
## (or the pot row) still touches an edge. Returns the smallest die (px).
func _fit_phone_landscape() -> float:
	camera.fit_viewport(Vector2(get_viewport().get_visible_rect().size))
	camera.home_distance = bonfire_tuning.cam_phone_landscape_distance
	camera.distance = camera.home_distance
	camera.home_pivot = bonfire_tuning.cam_phone_landscape_pivot
	camera.position = camera.home_pivot
	camera._apply()
	var n := maxi(setup.dice.size() if setup != null else 5, 1)
	var pts := CameraFraming.must_points()
	pts.append_array([pot_slot(0) + Vector3(0, PILLAR_HEIGHT, 0), pot_slot(n - 1) + Vector3(0, tuning.die_size, 0)])
	for step in 20:
		if CameraFraming.margin(camera.cam, pts) >= bonfire_tuning.cam_edge_margin_px:
			break
		camera.home_distance *= 1.02
		camera.distance = camera.home_distance
		camera._apply()
	phone_dial_visible = true
	_fit_landscape_felt()
	return _smallest_die_px(CameraFraming.rest_spots(tuning.die_size))


## Smallest on-screen die (px) at the given points, current camera.
func _smallest_die_px(pts: Array[Vector3]) -> float:
	camera._apply()
	var smallest := INF
	for p in pts:
		var at := Vector3(p.x, tuning.die_size * 0.5, p.z)
		var sz := DieVisual.projected_size(camera.cam, Transform3D(Basis.IDENTITY, at), tuning.die_size)
		smallest = minf(smallest, minf(sz.x, sz.y))
	return smallest


## Best z offset of the pivot (within +-0.3 m) for the points: [offset, the
## smallest distance (px) of any point inside the viewport edge].
func _slide_for(base: Vector3, pts: Array[Vector3]) -> Array[float]:
	# unproject_position works in the viewport's (stretched) coordinates.
	var vs := get_viewport().get_visible_rect().size
	var best := 0.0
	var best_margin := -INF
	for k in range(-30, 31):
		var off := k * 0.01
		camera.home_pivot = base + Vector3(0, 0, off)
		camera.position = camera.home_pivot
		camera._apply()
		var margin := INF
		for p in pts:
			var sp := camera.cam.unproject_position(p)
			margin = minf(margin, minf(minf(sp.x, vs.x - sp.x), minf(sp.y, vs.y - sp.y)))
		if margin > best_margin + 0.5 or (absf(margin - best_margin) <= 0.5 and absf(off) < absf(best)):
			best_margin = margin
			best = off
	return [best, best_margin]


## Which Reliquary layout this screen uses: portrait, phone (landscape
## phone, or a short window: narrow screens get the phone prop, a shrunk
## PC plate is unreadable), or PC. The canvas is always scaled to 1080 tall,
## so "short" looks at the real window size in pixels.
func reliquary_kind() -> StringName:
	var vs := get_viewport().get_visible_rect().size
	if vs.y > vs.x:
		return SoulReliquaryHookup.PORTRAIT
	if (phone_screen.y > 0.0 and phone_screen.x >= phone_screen.y) or window_px().y < SHORT_WINDOW_PX:
		return SoulReliquaryHookup.PHONE
	return SoulReliquaryHookup.PC


## The real window size in pixels (tests can set window_px_override).
func window_px() -> Vector2i:
	if window_px_override != Vector2i.ZERO:
		return window_px_override
	return get_window().size


## Makes / moves the Reliquary and hides the old 2D Soul bar for good.
func _place_reliquary() -> void:
	if reliquary == null:
		reliquary = SoulReliquaryHookup.new()
		reliquary.name = "SoulReliquary"
		add_child(reliquary)
	if soul_meter != null:
		soul_meter.visible = false
	reliquary.reduced_motion = reduced_motion
	reliquary.layout(reliquary_kind())
	# Portrait: the stacked plate must not sit under Throw / Bank.
	if reliquary.layout_kind == SoulReliquaryHookup.PORTRAIT and camera != null and bhud != null:
		reliquary.clear_of(button_column_rect().grow(16.0), camera.cam)


## The Reliquary's plate on screen (empty before it exists).
func reliquary_rect() -> Rect2:
	if reliquary == null or camera == null:
		return Rect2()
	return reliquary.plate_rect(camera.cam)


## The Throw / Bank / Leave column on screen (HUD canvas px).
func button_column_rect() -> Rect2:
	var col := bhud.throw_button.get_parent() as Control
	return col.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, col.size)
