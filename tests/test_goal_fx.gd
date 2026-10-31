## GoalFx (#229 goal signals): reached -> Ember plate flare that fades back;
## missed(soul_loss) -> plate dims and an Ember "-N Soul" tag shows the number
## sent (not recomputed); reduced motion holds still; table_started clears;
## no dice touched; Ember only (no red / cyan / violet).
##   godot --headless --path . --script res://tests/test_goal_fx.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


class StubHud:
	extends Control
	var target_plate := TargetPlate.new()


class StubTable:
	extends Node
	var events := TableEvents.new()
	var bhud := StubHud.new()
	var reduced := false
	func is_reduced_motion() -> bool:
		return reduced


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _ember_only(c: Color) -> bool:
	# warm: red >= green >= blue (no cyan / violet); not the DANGER red.
	return c.r >= c.g and c.g >= c.b and not c.is_equal_approx(Palette.DANGER)


func _run() -> void:
	var tb := StubTable.new()
	root.add_child(tb)
	tb.add_child(tb.events)
	tb.add_child(tb.bhud)
	tb.bhud.add_child(tb.bhud.target_plate)
	var plate: TargetPlate = tb.bhud.target_plate
	plate.position = Vector2(20, 30)
	plate.size = Vector2(300, 80)
	var fx := GoalFx.new()
	fx.hold = true
	tb.add_child(fx)
	await process_frame
	await process_frame
	check(fx.table == tb and fx.events == tb.events, "binds to the parent's events")
	check(fx.find_plate() == plate, "finds bhud.target_plate")
	check(GoalFx.new().bind(Node.new(), tb) == false, "no #229 signals: binds to nothing")

	# Reached: Ember flare, fades to white.
	tb.events.goal_reached.emit()
	check(fx.calls == ["reached"], "goal_reached plays")
	check(fx.flare != null, "flare made")
	if fx.flare == null:  # reached() returned early: stop here, exit non-zero
		_finish()
		return
	var sb := fx.flare.get_theme_stylebox(&"panel") as StyleBoxFlat
	check(sb != null and sb.border_color == Palette.EMBER and _ember_only(sb.bg_color), "flare: Ember border + wash")
	check(fx.flare.get_parent() == tb.bhud and fx.flare.size.is_equal_approx(plate.size) and fx.flare.position.is_equal_approx(plate.position), "flare covers the plate")
	check(is_equal_approx(fx.flare.modulate.a, 1.0), "flare at full on reach")
	check(_ember_only(GoalFx.EMBER) and GoalFx.EMBER == Palette.EMBER, "Ember is #E8622A")
	fx.advance(GoalFx.FLARE_TIME * 0.5)
	check(fx.flare.modulate.a < 1.0 and fx.flare.modulate.a > 0.0, "flare fading at mid")
	fx.advance(GoalFx.FLARE_TIME)
	check(fx.flare == null and plate.modulate.is_equal_approx(Color.WHITE), "flare gone, plate normal")
	check(GoalFx.FLARE_TIME <= 0.5, "flare is short")

	# Missed: dims, shows the sent number.
	tb.events.goal_missed.emit(10)
	check(fx.calls[-1] == "missed:10", "goal_missed plays with the soul_loss")
	check(fx.soul_tag != null and fx.soul_tag.text == "-10 Soul", "tag shows the number #229 sent")
	if fx.soul_tag == null:
		_finish()
		return
	check(fx.soul_tag.get_parent() == tb.bhud, "tag is a sibling, not dimmed with the plate")
	check(_ember_only(fx.soul_tag.label_settings.font_color), "tag is Ember, not red/cyan/violet")
	check(fx.soul_tag.label_settings.font_size >= 24, "tag reads at small sizes")
	var y0 := fx.soul_tag.position.y
	fx.advance(GoalFx.DIM_TIME)
	check(plate.modulate.is_equal_approx(GoalFx.DIM), "plate dims")
	check(fx.soul_tag.position.y > y0 and is_equal_approx(fx.soul_tag.modulate.a, 1.0), "tag drops in")
	check(is_equal_approx(fx.soul_tag.position.y, plate.position.y + plate.size.y + 4.0), "tag lands under the plate")
	fx.advance(GoalFx.MISS_HOLD + 0.1)
	check(fx.soul_tag == null and plate.modulate.is_equal_approx(Color.WHITE), "miss ends clean")

	# A different number is shown as given (Bloodletter x2 etc. done upstream).
	tb.events.goal_missed.emit(3)
	check(fx.soul_tag.text == "-3 Soul", "any soul_loss shown as given")
	tb.events.table_started.emit()
	check(fx.soul_tag == null and plate.modulate.is_equal_approx(Color.WHITE), "table_started clears")

	# Reduced motion: no movement; static flare / dim, tag in place at once.
	tb.reduced = true
	tb.events.goal_reached.emit()
	check(fx.flare != null and is_equal_approx(fx.flare.modulate.a, 1.0), "reduced: static flare")
	fx.advance(GoalFx.FLARE_TIME * 0.5)
	check(fx.flare != null and is_equal_approx(fx.flare.modulate.a, 1.0), "reduced: no fade animation")
	fx.advance(GoalFx.FLARE_TIME)
	check(fx.flare == null, "reduced: snaps off")
	tb.events.goal_missed.emit(5)
	var yr := fx.soul_tag.position.y
	check(plate.modulate.is_equal_approx(GoalFx.DIM) and is_equal_approx(fx.soul_tag.modulate.a, 1.0), "reduced: static dim + tag")
	fx.advance(GoalFx.DIM_TIME)
	check(is_equal_approx(fx.soul_tag.position.y, yr), "reduced: no drop")
	fx.clear()

	# Never slows a pot: tweens ignore time scale and nothing awaits.
	fx.hold = false
	tb.reduced = false
	Engine.time_scale = 0.25
	tb.events.goal_reached.emit()
	await create_timer(GoalFx.FLARE_TIME + 0.15, true, false, true).timeout
	check(fx.flare == null, "flare runs in real time")
	Engine.time_scale = 1.0
	check(fx.get_child_count() == 0, "no nodes on the table (dice untouched)")

	tb.queue_free()
	await _real_build()
	_finish()


## Prints the tally and exits non-zero on any failure (as the other tests do).
func _finish() -> void:
	print("goal_fx: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## The real Bonfire table: the tag shows goal_missed's own soul_loss, 5 on a
## plain miss and 10 under the Bloodletter (x2), never a number GoalFx makes.
func _real_build() -> void:
	var tu := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var sv := SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	root.add_child(sv)
	for case: Array in [[[] as Array[StringName], 5], [[&"bloodletter"] as Array[StringName], 10]]:
		var g := TableGoal.new()
		g.target = 99999
		g.hands = 1
		g.clear_embers = 14
		g.miss_soul = 5
		var st := TableSetup.sandbox(tu, 3)
		st.goal = g
		st.rules = case[0]
		st.table_seed = 5
		st.nerve_uses = 0
		var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
		s.setup = st
		s.tutorial_override = 0
		s.test_speed = 10.0
		sv.add_child(s)
		await process_frame
		await process_frame
		var fx := s.get_node_or_null("GoalFx") as GoalFx
		check(fx != null, "real table has GoalFx (%s)" % str(case[0]))
		if fx == null:
			s.queue_free()
			continue
		fx.hold = true
		var sent: Array[int] = []
		s.events.goal_missed.connect(func(n: int) -> void:
			sent.append(n)
			if fx.soul_tag != null:
				sent.append(-1 if fx.soul_tag.text != GoalFx.SOUL_TEXT % n else n))
		for k in 600:
			if s.phase == Table3D.Phase.BET:
				break
			await process_frame
		s.rig_faces([5, 5, 1] as Array[int])
		s.quick_throw()
		await s.throw_resolved
		await s.sequence_finished
		for i in 2:
			s.pick_die(i)
		await s.bank()
		for k in 120:
			if not sent.is_empty():
				break
			await process_frame
		print("real build %s: goal_missed sent %s" % [str(case[0]), str(sent)])
		check(sent.size() == 2 and sent[0] == case[1] and sent[1] == sent[0], "tag text is the signal's value (%d): %s" % [case[1], str(sent)])
		check(fx.soul_tag != null and fx.soul_tag.text == "-%d Soul" % case[1], "real tag reads -%d Soul" % case[1])
		s.queue_free()
		await process_frame
