## Face looks (QA #50 review: Ferryman's Tails scored 0 but showed one pip):
##   - a face printed 0 is blank (no pips),
##   - 1-6 are pips, 7+ a printed numeral (never clamped to a 6),
##   - the coin has its own Heads (+Y: ring + boss) and Tails (-Y: ring +
##     bar) looks and no pips, even with faces [5, 0],
##   - the Bonfire table's apply_die_look keeps those values.
##   godot --headless --path . --script res://tests/test_die_face_looks.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	_run.call_deferred()


## Children of the die's "Pips" node with this name prefix.
func _named(dv: DieVisual, prefix: String) -> int:
	var n := 0
	for c in dv.faces.get_node("Pips").get_children():
		if String(c.name).begins_with(prefix):
			n += 1
	return n


func _run() -> void:
	# Labels per slot (slot k is drawn on cube face axis k).
	var dv := DieVisual.new()
	dv.set_look(Palette.BONE, Palette.PIT_BLACK, [0, 1, 2, 3, 4, 8] as Array[int])
	check(dv.labels == [0, 1, 2, 3, 4, 8], "labels keep 0 and 8")
	check(dv.pip_count(1) == 0, "face 0 renders no pips (blank)")
	check(dv.pip_count(2) == 1 and dv.pip_count(4) == 3 and dv.pip_count(5) == 4, "faces 1-4 render their pips")
	check(dv.pip_count(6) == 0 and _named(dv, "Numeral8") == 1, "face 8 is a printed 8, not 6 pips")
	dv.free()
	var plain := DieVisual.new()
	plain.set_look(Palette.BONE, Palette.PIT_BLACK, [1, 2, 3, 4, 5, 6] as Array[int])
	var total := 0
	for axis in range(1, 7):
		total += plain.pip_count(axis)
	check(plain.pip_count(1) == 1 and plain.pip_count(6) == 6 and total == 21, "a plain d6 still has 21 pips")
	plain.free()

	# The coin: own heads / tails looks, never pips.
	var coin := DieVisual.new()
	coin.set_look(Palette.BONE, Palette.PIT_BLACK, [5, 0] as Array[int])
	coin.make_coin()
	check(_named(coin, "HeadsRing") == 1 and _named(coin, "HeadsBoss") == 1, "coin heads look: ring + boss")
	check(_named(coin, "TailsRing") == 1 and _named(coin, "TailsBar") == 1, "coin tails look: ring + bar")
	var heads := coin.faces.get_node("Pips/HeadsBoss") as Node3D
	var tails := coin.faces.get_node("Pips/TailsBar") as Node3D
	check(heads.position.y > 0.0 and tails.position.y < 0.0, "heads on +Y, tails on -Y")
	check(coin.faces.get_node("Pips").get_child_count() == 4, "coin: no pip discs (only its 4 marks)")
	coin.free()

	# Through the Bonfire table (bonfire_3d.apply_die_look): Ferryman [5, 0]
	# and a d8-style die with a 7 and 8 printed.
	var scene := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var dice: Array = scene.dice
	var fer := TableDie.new(&"ferryman", "Ferryman's Coin", &"coin")
	fer.special = &"ferryman"
	fer.faces = [5, 0] as Array[int]
	scene.apply_die_look(dice[0], fer)
	check(dice[0].shape == &"coin" and _named(dice[0], "TailsBar") == 1 and _named(dice[0], "HeadsBoss") == 1, "table: Ferryman [5, 0] gets the coin's heads / tails looks")
	var wide := TableDie.new(&"lantern", "Lantern", &"d6")
	wide.faces = [0, 2, 3, 4, 7, 8] as Array[int]
	scene.apply_die_look(dice[1], wide)
	check(dice[1].labels == [0, 2, 3, 4, 7, 8], "table: face values above 6 are not clamped")
	check(dice[1].pip_count(1) == 0, "table: a 0 face renders no pips")
	check(_named(dice[1], "Numeral7") == 1 and _named(dice[1], "Numeral8") == 1, "table: 7 and 8 printed as numerals")
	scene.queue_free()
	await process_frame
	print("test_die_face_looks: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
