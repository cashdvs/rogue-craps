## Throw momentum through the REAL game input path: a mouse grab-and-flick
## fed to the window with Input.parse_input_event (window pixels, the
## canvas_items stretch, the real frame clock, ThrowGesture, Options
## sensitivity, launch_k curve, physics), at soft / medium / hard speeds.
## Prints, per flick: window px/s, the flick the game measured (canvas px/s),
## k, launch m/s, travel (path length) and the landing distance from the hand.
## The mouse moves on the real clock, like a hand: flicks are timed on the
## real clock too (Table3D.flick_time), so this is right at any frame rate
## (the box renders at ~5 fps). Don't pass --fixed-fps.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1280x720 --script res://tools/measure_throw_momentum.gd
extends SceneTree

## Window px/s: a soft lob, a medium flick, a hard flick, and a harder one
## still under the curve's cap (at 1280x720 the game reads 1.5x).
const SPEEDS := {"soft": 550.0, "medium": 1400.0, "hard": 2800.0, "harder": 3600.0, "hard_diag": 2800.0}
## Flick direction on screen (up-left, toward the backboard). "hard_diag"
## flicks flatter, along the table, where the far end is farther away.
const DIR := Vector2(-0.55, -0.83)
const DIR_DIAG := Vector2(-0.85, -0.53)
const FLICK_TIME: float = 0.25
const TRIALS: int = 3


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = TableSetup.sandbox(t, 5)
	s.tutorial_override = 0
	root.add_child(s)
	await create_timer(0.8).timeout
	var win := Vector2(root.get_window().size)
	var canvas := root.get_visible_rect().size
	var to_win := win / canvas
	print("window %s  canvas %s  sensitivity %.2f  curve %.0f..%.0f px/s -> %.2f..%.2f m/s, exp %.2f  min_throw_speed %.0f" % [
		str(win), str(canvas), s.sensitivity(), t.flick_speed_min, t.flick_speed_max, t.launch_speed_min_mps, t.launch_speed_max_mps, t.launch_exponent, s.tuning.min_throw_speed])
	for name in SPEEDS:
		var sp: float = SPEEDS[name]
		for trial in TRIALS:
			s.new_run(100 + trial)
			await create_timer(0.6).timeout
			while s.phase != Table3D.Phase.BET or s.hand_moving():
				await process_frame
			var hand := s.camera.cam.unproject_position(Table3D.HAND) * to_win
			var dir := (DIR_DIAG if name == "hard_diag" else DIR).normalized()
			# Every event is parsed at the same point of a frame and handled
			# (timestamped) one frame later, like OS input: the lag is equal for
			# all of them, so the hand's speed is what the game measures.
			await process_frame
			var t0 := Time.get_ticks_usec()
			_mouse_button(hand, true)
			var pos := hand
			var frames := 0
			while (Time.get_ticks_usec() - t0) / 1000000.0 < FLICK_TIME:
				await process_frame
				frames += 1
				pos = hand + dir * sp * (Time.get_ticks_usec() - t0) / 1000000.0
				var mm := InputEventMouseMotion.new()
				mm.position = pos
				mm.global_position = pos
				mm.button_mask = MOUSE_BUTTON_MASK_LEFT
				Input.parse_input_event(mm)
			_mouse_button(pos, false)
			await process_frame
			await process_frame
			if s.phase == Table3D.Phase.BET or s.phase == Table3D.Phase.HELD:
				print("  %-6s %4.0f win px/s -> did not throw (phase %d, %d motion frames)" % [name, sp, s.phase, frames])
				continue
			var res: Array = await s.throw_resolved
			var L := s.last_launch
			var rec := s.last_recording
			var path := 0.0
			var dist := 0.0
			var far := 0.0
			var n := s.throw_dice.size()
			for i in rec.count():
				var fr := rec.frames[i] as Array
				for f in range(1, fr.size()):
					path += ((fr[f] as Transform3D).origin - (fr[f - 1] as Transform3D).origin).length() / n
				var p := s.throw_dice[i].global_position
				var dd := Vector2(p.x - Table3D.HAND.x, p.z - Table3D.HAND.z).length()
				dist += dd / n
				far = maxf(far, dd)
			var walls := 0
			for c: Dictionary in rec.contacts:
				if String(c["kind"]) == "backboard" and float(c["speed"]) > 0.5:
					walls += 1
			print("  %-6s %4.0f win px/s -> measured %5.0f canvas px/s  k %.2f  launch %.2f m/s  travel %.2f m  landing %.2f m avg (%.2f max)  backboard hits %d" % [
				name, sp, float(L["flick"]), float(L["k"]), float(L["speed"]), path, dist, far, walls])
			# Contact speeds (m/s) the impact SFX would get: each die's first
			# felt hit (the landing), every rail and backboard hit. Only the
			# audible ones (>= impact_min_speed), like _on_contact.
			var floor_v: Array[float] = []
			var seen := {}
			var rail_v: Array[float] = []
			var back_v: Array[float] = []
			for c: Dictionary in rec.contacts:
				var v := float(c["speed"])
				var kind := String(c["kind"])
				if kind == "felt" and not seen.has(int(c["die"])):
					seen[int(c["die"])] = true
					floor_v.append(v)
				if v < s.tuning.impact_min_speed:
					continue
				if kind == "rail":
					rail_v.append(v)
				elif kind == "backboard":
					back_v.append(v)
			print("         contacts m/s: first floor %s | rail %s | backboard %s" % [_speeds(floor_v), _speeds(rail_v), _speeds(back_v)])
			await s.sequence_finished
	s.queue_free()
	await create_timer(0.2).timeout
	quit()


## "avg / max (n)" over a list of speeds, or "-" when empty.
func _speeds(v: Array[float]) -> String:
	if v.is_empty():
		return "-"
	var sum := 0.0
	var top := 0.0
	for x in v:
		sum += x
		top = maxf(top, x)
	return "%.2f avg / %.2f max (%d)" % [sum / v.size(), top, v.size()]


func _mouse_button(p: Vector2, down: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = down
	mb.position = p
	mb.global_position = p
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(mb)
