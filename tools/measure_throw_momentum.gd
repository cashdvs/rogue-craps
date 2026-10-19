## Throw momentum through the REAL game input path: a mouse grab-and-flick
## fed to the window with Input.parse_input_event (window pixels, the
## canvas_items stretch, the real frame clock, ThrowGesture, Options
## sensitivity, launch_k curve, physics), at soft / medium / hard speeds.
## Prints, per flick: window px/s, the flick the game measured (canvas px/s),
## k, launch m/s, travel (path length) and the landing distance from the hand.
## Run with --fixed-fps 60 so the game clock is a steady 60 fps player's
## (the box renders at ~5 fps; below ~7.5 fps Godot caps a frame's delta at
## 8 physics steps, which would read every flick ~2.7x too fast).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1280x720 --fixed-fps 60 --script res://tools/measure_throw_momentum.gd
extends SceneTree

## Window px/s: a soft lob, a medium flick, a hard flick (at 1280x720).
const SPEEDS := {"soft": 550.0, "medium": 1400.0, "hard": 2800.0}
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
			var dir := Vector2(-0.55, -0.83).normalized()
			_mouse_button(hand, true)
			await process_frame
			var clock0: float = s._input_clock
			var pos := hand
			var frames := 0
			var dt := 1.0 / maxf(float(Engine.max_fps if Engine.max_fps > 0 else 60), 1.0)
			while frames * dt < 0.25:
				await process_frame
				frames += 1
				pos = hand + dir * sp * frames * dt
				var mm := InputEventMouseMotion.new()
				mm.position = pos
				mm.global_position = pos
				mm.button_mask = MOUSE_BUTTON_MASK_LEFT
				Input.parse_input_event(mm)
			print("    clock: input_clock advanced %.3f s for %d frames" % [s._input_clock - clock0, frames])
			_mouse_button(pos, false)
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
			await s.sequence_finished
	s.queue_free()
	await create_timer(0.2).timeout
	quit()


func _mouse_button(p: Vector2, down: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = down
	mb.position = p
	mb.global_position = p
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(mb)
