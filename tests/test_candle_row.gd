## Headless test: the hand candle row prop (art/models/props/candle_row, AD sign-off Oct 22 v4). Checks, PC + mobile:
##   layout   two tiers of 4: sockets 1-4 front, 5-8 back (behind, offset half a pitch so no candle hides another)
##   snuff    spends go from the back tier's right end first; 4 or fewer lit = one clean front row, back bar hidden
##   rings    Bodkin's ringed extra candle on the next free socket; the >8 cue ring stays on candle 8
##   gutter   last hand dims to ~half; restores when a hand is added
##
## Run:
##   godot --headless --path . --script res://tests/test_candle_row.gd
extends SceneTree

const ROW := "res://art/models/props/candle_row/scenes/candle_row%s.tscn"
const LIT := 1  # CandleRowCandle.State.LIT

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Dice of the Damned: candle row tests ===")
	_run.call_deferred()


func _run() -> void:
	for lod in ["", "_mobile"]:
		await _check_row(lod)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _lit(row: Node) -> Array:
	var out := []
	for i in 8:
		if int(row.call("candle", i).state) == LIT:
			out.append(i)
	return out


func _check_row(lod: String) -> void:
	var label := "candle_row%s" % lod
	var ps := load(ROW % lod) as PackedScene
	_check(ps != null, label + ": loads")
	if ps == null:
		return
	var row := ps.instantiate() as Node3D
	row.set("reduced_motion", true)
	root.add_child(row)
	await process_frame
	var sk := []
	for i in 8:
		sk.append((row.get_node("Sockets/Socket%d" % (i + 1)) as Node3D).position)
	var pitch: float = sk[1].x - sk[0].x
	var tiers_ok := true
	for i in 4:
		tiers_ok = tiers_ok and is_equal_approx(sk[i].z, sk[0].z) and is_equal_approx(sk[i + 4].z, sk[4].z)
		tiers_ok = tiers_ok and absf(sk[i + 4].x - (sk[i].x + pitch * 0.5)) < 1e-4
	_check(tiers_ok and sk[4].z < sk[0].z - 0.02, label + ": two tiers of 4, back tier behind and offset half a pitch")
	var min_dx := INF
	for b in range(4, 8):
		for f in 4:
			min_dx = minf(min_dx, absf(sk[b].x - sk[f].x))
	_check(min_dx >= pitch * 0.45, label + ": no back candle sits straight behind a front one (min dx %.3f m)" % min_dx)
	# snuff order
	row.call("table_start", 8, 0)
	_check(_lit(row) == [0, 1, 2, 3, 4, 5, 6, 7], label + ": 8 hands, 8 lit")
	row.call("spend", false)
	_check(_lit(row) == [0, 1, 2, 3, 4, 5, 6], label + ": first spend snuffs the back tier's right end (candle 8)")
	for i in 3:
		row.call("spend", true)
	_check(_lit(row) == [0, 1, 2, 3], label + ": 4 left = the front tier only")
	row.call("table_start", 4, 0)
	_check(_lit(row) == [0, 1, 2, 3] and not (row.get_node("HolderBack") as Node3D).visible, label + ": 4 hands = one clean front row, back bar hidden")
	row.call("table_start", 5, 0)
	_check((row.get_node("HolderBack") as Node3D).visible, label + ": 5 hands shows the back bar")
	# Bodkin: 4 + 1 ringed on the next free socket (5)
	row.call("table_start", 5, 1)
	var r1 := row.get_node("GiftRing1") as Node3D
	_check(r1.visible and absf(r1.position.x - sk[4].x) < 1e-4 and absf(r1.position.z - sk[4].z) < 1e-4, label + ": Bodkin ring on the next free socket (5)")
	row.call("table_start", 3, 1)
	_check(r1.visible and absf(r1.position.x - sk[2].x) < 1e-4, label + ": Bodkin ring on socket 3 with 2 + 1 hands")
	# >8 cue
	row.call("table_start", 10, 0)
	_check(_lit(row).size() == 8 and bool(row.call("over_cap")) and r1.visible and absf(r1.position.x - sk[7].x) < 1e-4 and absf(r1.position.z - sk[7].z) < 1e-4, label + ": >8 cue ring on candle 8, all 8 lit")
	row.call("spend", false)
	row.call("spend", false)
	_check(not r1.visible and _lit(row).size() == 8, label + ": cue ring leaves at 8 left")
	# gutter
	row.call("table_start", 2, 0)
	row.call("spend", false)
	var c0 = row.call("candle", 0)
	_check(float(c0.get("gutter")) > 0.3, label + ": last hand gutters")
	row.call("add_hands", 1)
	_check(float(c0.get("gutter")) < 0.3 and _lit(row) == [0, 1], label + ": gutter restores when a hand is added")
	row.queue_free()
	await process_frame


func _check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  ok   ", name)
	else:
		_failed += 1
		print("  FAIL ", name)
