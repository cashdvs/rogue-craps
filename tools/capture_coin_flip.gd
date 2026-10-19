## Ten Ferryman's Coin flips (movie + a still of each result), for PM / QA.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \
##       --resolution 1280x720 --fixed-fps 30 --write-movie /tmp/coin_flip.avi \
##       --script res://tools/capture_coin_flip.gd -- /tmp/coin_stills
## The coin is thrown alone at mixed flick speeds (seeded, not rigged); each
## result is flashed as HEADS / TAILS and saved as flip_NN.png in the stills
## folder (last argument). Tooling only; not part of the game or tests.
extends SceneTree

const SPEEDS: Array[float] = [900.0, 1800.0, 2600.0, 3400.0, 4200.0, 1200.0, 2200.0, 3000.0, 5000.0, 1500.0]

var s: Bonfire3D


func _initialize() -> void:
	_run.call_deferred()


func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[args.size() - 1] if not args.is_empty() else "/tmp/coin_stills"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var st := TableSetup.new()
	var coin := TableDie.new(&"ferryman", "Ferryman's Coin", &"coin")
	coin.special = &"ferryman"
	coin.weights = [1.0, 1.0] as Array[float]
	st.dice.append(coin)
	st.run_mode = false
	st.table_seed = 31
	s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	root.add_child(s)
	await wait(0.8)
	var log := []
	for k in SPEEDS.size():
		while s.phase != Table3D.Phase.BET:
			await process_frame
		await wait(0.4)
		s.bhud.flash("FLIP %d  (%d px/s)" % [k + 1, int(SPEEDS[k])], Palette.BONE)
		s.throw(Vector2(-0.35 + 0.07 * k, -1.0).normalized() * SPEEDS[k])
		await s.sequence_finished
		var c: DieVisual = s.all_dice[0]
		var face := "HEADS" if c.up_slot() == 1 else "TAILS"
		log.append(face)
		s.bhud.flash(face, Palette.BRASS_HI if c.up_slot() == 1 else Palette.BURGUNDY)
		await wait(0.35)
		root.get_viewport().get_texture().get_image().save_png("%s/flip_%02d.png" % [out_dir, k + 1])
		print("flip %d: %s (%.0f px/s, %d half-turns in the air+felt)" % [k + 1, face, SPEEDS[k], _half_turns()])
		await wait(0.6)
		s.new_run(31 + k + 1)
	print("COIN FLIPS: ", " ".join(log))
	await wait(0.4)
	quit()


func _half_turns() -> int:
	var fr := s.last_recording.frames[0] as Array
	var t := 0.0
	for f in range(1, fr.size()):
		t += (fr[f - 1] as Transform3D).basis.y.normalized().angle_to((fr[f] as Transform3D).basis.y.normalized())
	return int(round(t / PI))
