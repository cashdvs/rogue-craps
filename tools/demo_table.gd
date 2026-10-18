## Scripted demo of the POC table for movie captures (simulated grab + flick).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1920x1080 --fixed-fps 30 --write-movie /workspace/dice/captures/table_poc.avi \
##     --script res://tools/demo_table.gd
extends SceneTree

var scene: TableScene


func _initialize() -> void:
	_run.call_deferred()


func wait(s: float) -> void:
	await create_timer(s).timeout


## Simulates a drag from the hand along `to`, then a flick with velocity v.
func flick(to: Vector2, v: Vector2) -> void:
	scene.phase = TableScene.Phase.HELD
	scene.sfx.play(&"dice_grab")
	var from := TableScene.HAND
	var steps := 18
	for i in steps:
		scene.hold_point_override = from.lerp(to, float(i) / steps) + Vector2(0, -sin(PI * i / steps) * 30.0)
		await process_frame
	await wait(0.15)
	scene.phase = TableScene.Phase.BET
	scene.hold_point_override = Vector2.INF
	scene.throw(v, to)


func _run() -> void:
	scene = (load("res://scenes/table.tscn") as PackedScene).instantiate() as TableScene
	scene.rng_seed = 31
	root.add_child(scene)
	await wait(0.8)
	for i in 2:
		scene.place()
		await wait(0.25)
	await wait(0.4)
	# A weak flick drops back.
	await flick(Vector2(1700, 820), Vector2(-150, -80))
	await wait(0.9)
	scene.rig_next_roll(5, 6)
	await flick(Vector2(1580, 760), Vector2(-2600, -1400))
	await scene.sequence_finished
	await wait(0.4)
	scene.place()
	await wait(0.3)
	scene.rig_next_roll(4, 2)
	await flick(Vector2(1560, 720), Vector2(-1700, -1900))
	await scene.sequence_finished
	await wait(0.3)
	scene.rig_next_roll(5, 3)
	await flick(Vector2(1600, 740), Vector2(-2200, -800))
	await scene.sequence_finished
	await wait(0.3)
	scene.rig_next_roll(5, 2)
	await flick(Vector2(1540, 700), Vector2(-3200, -1000))
	await scene.sequence_finished
	await wait(0.5)
	scene.place()
	scene.place()
	scene.place()
	scene.place()
	await wait(0.5)
	scene.rig_next_roll(1, 1)
	await flick(Vector2(1580, 760), Vector2(-2400, -1600))
	await scene.sequence_finished
	await wait(1.2)
	quit()
