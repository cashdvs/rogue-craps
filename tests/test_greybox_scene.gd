## Smoke test for the greybox scene: loads greybox.tscn, bets and rolls many
## times, and checks the labels always agree with the logic.
##
## Run:
##   godot --headless --path /workspace/dice/game --script res://tests/test_greybox_scene.gd
extends SceneTree

var _failed: int = 0


func _initialize() -> void:
	# The root isn't fully running during _initialize, so _ready() wouldn't
	# fire yet. Defer the real work until the main loop has started.
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/greybox.tscn") as PackedScene
	var scene := packed.instantiate()
	scene.set("rng_seed", 2026)
	scene.set("starting_coin", 1000)
	root.add_child(scene)

	var decisions := 0
	for i in range(200):
		if not scene.table.craps.has_point() and scene.table.stake_on(&"pass") == 0:
			scene.press_bet(&"pass")
		if i % 3 == 0:
			scene.press_bet(&"field")
		var report: TableReport = scene.roll()
		if report == null or report.rejected:
			_failed += 1
			print("FAIL  roll %d was rejected" % i)
			continue
		if report.roll.is_decision():
			decisions += 1
		var coin_label: Label = scene.get_node("%CoinLabel")
		var point_label: Label = scene.get_node("%PointLabel")
		var expected_point := ("Point: %d" % report.roll.point_after) if report.roll.point_after != 0 else "Point: OFF"
		if coin_label.text != "Coin: %d" % scene.bankroll.coin or point_label.text != expected_point:
			_failed += 1
			print("FAIL  roll %d: labels out of sync" % i)
	var die_count: int = scene.get_node("%DiceRow").get_child_count()
	if die_count != 2:
		_failed += 1
		print("FAIL  expected 2 die views, got %d" % die_count)
	print("Greybox: 200 rolls, %d decisions, Coin %d" % [decisions, scene.bankroll.coin])
	print("=== greybox scene smoke: %s ===" % ("PASS" if _failed == 0 else "FAIL (%d)" % _failed))
	scene.queue_free()
	quit(1 if _failed > 0 else 0)
