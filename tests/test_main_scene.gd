## Smoke test for the greybox scene: loads main.tscn, presses Roll many times,
## and checks the labels always agree with the rules state.
##
## Run:
##   godot --headless --path /workspace/dice/game --script res://tests/test_main_scene.gd
extends SceneTree

var _failed: int = 0


func _initialize() -> void:
	# The root isn't fully running during _initialize, so _ready() wouldn't
	# fire yet. Defer the real work until the main loop has started.
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)  # Triggers _ready() so @onready vars are set.

	var decisions := 0
	for i in range(200):
		var result: RollResult = main.roll()
		if result.is_decision():
			decisions += 1
		var point_label: Label = main.get_node("%PointLabel")
		var expected_point := ("Point: %d" % result.point_after) if result.point_after != 0 else "Point: OFF"
		if point_label.text != expected_point or (main.get_node("%ResultLabel") as Label).text != result.message:
			_failed += 1
			print("FAIL  roll %d: labels out of sync (%s)" % [i, str(result)])

	print("Main scene: 200 rolls, %d decisions, last result: %s" % [decisions, (main.get_node("%ResultLabel") as Label).text])
	print("=== main scene smoke: %s ===" % ("PASS" if _failed == 0 else "FAIL (%d)" % _failed))
	main.queue_free()
	quit(1 if _failed > 0 else 0)
