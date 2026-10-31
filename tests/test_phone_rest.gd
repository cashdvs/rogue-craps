## #204 (AD): on a phone in landscape (844x390) resting dice never sit under
## the goal plate or the bottom bar. After the dice settle, the table nudges
## them into the inner rows (PhoneFrame.clamp_rest). This throws 200 seeded
## throws (aim and power vary) through the real Bonfire throw flow with a
## Gallows d4 in the hand, and at every landing checks each die's screen
## box (its body mesh corners) against the plate and the bar. A die that
## would have rested outside the rows must actually have been nudged.
##   godot --headless --path . --script res://tests/test_phone_rest.gd
extends SceneTree

var THROWS := int(OS.get_environment("THROWS")) if OS.has_environment("THROWS") else 200

var _passed: int = 0
var _failed: int = 0
var _hits: Array[String] = []
var _nudged := 0
var _landed := 0
var _d4_seen := 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 204
	var m: Array = await _make()
	for k in THROWS:
		var s: Bonfire3D = m[1]
		await _ready_to_throw(s)
		# After a throw the run asks to pot or bank: start a fresh table.
		if s.can_throw() != "":
			(m[0] as Node).queue_free()
			await process_frame
			m = await _make()
			s = m[1]
			await _ready_to_throw(s)
		var v := Table3D.QUICK_THROW.rotated(rng.randf_range(-0.35, 0.35)) * rng.randf_range(0.6, 1.4)
		s.dice_landed.connect(func(_v: Array[int]) -> void: _on_landed(s, k), CONNECT_ONE_SHOT)
		var why := s.can_throw()
		var ok := s.throw(v)
		check(ok, "throw %d starts (%s, %s)" % [k, why, v])
		if ok:
			await s.sequence_finished
	check(_landed == THROWS, "every throw landed (%d / %d)" % [_landed, THROWS])
	check(_hits.is_empty(), "no resting die under the goal plate or bottom bar over %d throws (%d hits: %s)" % [THROWS, _hits.size(), ", ".join(_hits.slice(0, 5))])
	check(_d4_seen == THROWS, "the Gallows d4 was in every throw (%d)" % _d4_seen)
	# Without the nudge the outer rows fall under the HUD: some throws must
	# have needed it, or this test proves nothing.
	check(_nudged > 0, "the nudge moved dice on %d throws" % _nudged)
	print("test_phone_rest: %d ms" % (Time.get_ticks_msec() - t0))
	print("test_phone_rest: %d throws, %d nudged" % [THROWS, _nudged])
	print("test_phone_rest: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The real scene at the 844x390 canvas; the last of 5 dice is a Gallows d4.
func _make() -> Array:
	var sv := SubViewport.new()
	sv.size = Vector2i(2337, 1080)
	root.add_child(sv)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var st := TableSetup.sandbox(t, 5)
	st.dice[4] = TableDie.new(DiceIds.DIE_GALLOWS, "Gallows", DiceIds.shape_of(DiceIds.DIE_GALLOWS))
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.tutorial_override = 0
	s.bonfire_seed = 204
	s.test_speed = 20.0
	sv.add_child(s)
	await process_frame
	await process_frame
	s.camera.cam.current = true
	s.fit_phone(Vector2(844, 390))
	s.camera.snap_home()
	s._refresh_hud()
	await process_frame
	return [sv, s]


func _ready_to_throw(s: Bonfire3D) -> void:
	for i in 600:
		if s.phase == Table3D.Phase.BET and not s.hand_moving() and not s.bhud.countup.is_playing():
			return
		await process_frame


## At the landing (camera still home): every die's box vs the plate and bar.
func _on_landed(s: Bonfire3D, k: int) -> void:
	_landed += 1
	var cam := s.camera.cam
	var plate := s.bhud.target_plate.get_global_rect()
	var bar := s.bhud.bottom_bar.get_global_rect()
	var lim := PhoneFrame.REST_Z - s.tuning.die_size * 0.5 + 0.001
	for d: DieVisual in s.throw_dice:
		if d.shape == &"d4":
			_d4_seen += 1
		var p := d.global_position
		if absf(p.z) > lim or absf(p.x) > PhoneFrame.REST_X + 0.001:
			_hits.append("#%d die out of the rows %s" % [k, p])
		var r := _die_rect(cam, d)
		if r.intersects(plate) or r.intersects(bar):
			_hits.append("#%d %s %s at %s cam %s" % [k, d.shape, r, p, cam.global_position])
	if s.last_nudge:
		_nudged += 1


## Screen box of a die's body mesh (its 8 corners), worked out here.
func _die_rect(cam: Camera3D, d: DieVisual) -> Rect2:
	var body := d.faces.get_node("Body") as MeshInstance3D
	var ab := body.get_aabb()
	var r := Rect2(cam.unproject_position(body.global_transform * ab.position), Vector2.ZERO)
	for i in 8:
		r = r.expand(cam.unproject_position(body.global_transform * ab.get_endpoint(i)))
	return r
