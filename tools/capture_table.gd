## Renders POC table screenshots to /workspace/dice/captures/ (needs a display:
## run under xvfb-run with --rendering-driver opengl3).
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --resolution 1280x720 --script res://tools/capture_table.gd
extends SceneTree

const OUT := "/workspace/dice/captures/"
var scene: TableScene


func _initialize() -> void:
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(OUT + name + ".png")
	print("saved ", OUT + name + ".png")


func wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	scene = (load("res://scenes/table.tscn") as PackedScene).instantiate() as TableScene
	scene.rng_seed = 31
	root.add_child(scene)
	await wait(0.6)
	scene.place()
	await wait(0.15)
	scene.place()
	await wait(0.5)
	await shot("poc_01_idle_bets")

	# Held dice (simulate a grab at a point over the rim).
	scene.phase = TableScene.Phase.HELD
	scene.gesture.press(TableScene.HAND, 0.0)
	var held_at := Vector2(1560, 760)
	scene.hold_point_override = held_at
	await wait(0.35)
	await shot("poc_02_grab")
	scene.phase = TableScene.Phase.BET
	scene.hold_point_override = Vector2.INF

	# Natural: mid-tumble, flash, chips collecting.
	scene.rig_next_roll(5, 6)
	scene.throw(Vector2(-2600, -1500), held_at)
	await wait(0.42)
	await shot("poc_03_mid_tumble")
	await scene.outcome_shown
	await wait(0.09)
	await shot("poc_04_natural_flash")
	await wait(0.42)
	await shot("poc_05_chips_collecting")
	await scene.sequence_finished
	await wait(0.4)

	# Point set.
	scene.place()
	scene.rig_next_roll(4, 2)
	scene.throw(Vector2(-1500, -1700))
	await scene.outcome_shown
	await wait(0.5)
	await shot("poc_06_point_set")
	await scene.sequence_finished
	await wait(0.3)

	# Seven-out fizzle with Soul burn.
	scene.rig_next_roll(5, 2)
	scene.throw(Vector2(-3000, -900))
	await scene.outcome_shown
	await wait(0.32)
	await shot("poc_07_seven_out")
	await wait(0.35)
	await shot("poc_08_soul_burn_taunt")
	await scene.sequence_finished
	await wait(0.6)

	# Low soul + end screen: burn Soul quickly with seven-outs.
	while not scene.poc.is_over():
		if not scene.poc.table.craps.has_point() and scene.poc.table.stake_on(&"pass") == 0:
			if scene.place() != "":
				break
		if scene.poc.table.craps.has_point():
			scene.rig_next_roll(3, 4)
		else:
			scene.rig_next_roll(3, 5)
		scene.test_speed = 3.0
		if not scene.quick_throw():
			break
		await scene.sequence_finished
	await wait(0.6)
	await shot("poc_09_end_screen")
	quit()
