## Bonfire scoring + rules (pure):
##   godot --headless --path . --script res://tests/test_bonfire_scoring.gd
## Point values are read from the shipped tuning where the rule is generic, so
## the Game Designer's numbers can land data-only; the potting examples use
## the placeholder table (1 = 10, 5 = 5, triple = face x 10).
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var t: BonfireTuning


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func sc(faces: Array) -> Dictionary:
	return BonfireScoring.score_selection(faces, t)


func _initialize() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	check(t != null, "bonfire_tuning.tres loads")
	# Singles, sets, runs.
	check(sc([1])["points"] == t.single_one and sc([1])["valid"], "single 1")
	check(sc([5])["points"] == t.single_five, "single 5")
	check(sc([1, 5])["points"] == t.single_one + t.single_five, "1 + 5")
	check(sc([4, 4, 4])["points"] == 4 * t.triple_per_face, "three 4s = face x triple_per_face")
	check(sc([1, 1, 1])["points"] == t.triple_ones, "three 1s")
	check(sc([3, 3, 3, 3])["points"] == 3 * t.triple_per_face * t.of_a_kind_multiplier[1], "four of a kind = x2 triple")
	check(sc([6, 6, 6, 6, 6])["points"] == 6 * t.triple_per_face * t.of_a_kind_multiplier[2], "five of a kind = x3 triple")
	check(sc([1, 2, 3, 4, 5])["points"] == t.run_low, "run 1-5")
	check(sc([6, 4, 2, 5, 3])["points"] == t.run_high, "run 2-6 in any order")
	# Every potted die must score.
	check(not sc([4, 4])["valid"] and not sc([4, 4])["all_used"], "2 of 4-4-4 is invalid")
	check(not sc([1, 2])["valid"], "a dead 2 makes it invalid")
	check(not sc([])["valid"], "empty selection is invalid")
	check(not sc([2, 3, 4, 6])["valid"], "nothing scoring is invalid")
	# The Game Designer's examples (placeholder numbers).
	check(sc([1])["points"] == 10, "1 of 1-1-1 = 10")
	check(sc([4, 4, 4, 5])["points"] == 45 and sc([4, 4, 4, 5])["valid"], "4-4-4 + 5 = 45")
	# Lit dice / groups in a throw.
	check(BonfireScoring.lit_indices([2, 3, 4, 6, 6], t).is_empty(), "no scorers = nothing lit (bust)")
	check(BonfireScoring.lit_indices([4, 1, 4, 2, 4], t) == [0, 1, 2, 4], "4-4-4 and the 1 light, the 2 stays cold")
	var g := BonfireScoring.groups([4, 1, 4, 2, 4], t)
	check(g.size() == 2 and (g[0] as Array).size() == 1 and (g[1] as Array) == [0, 2, 4], "4-4-4 is one group, the 1 is single")
	check(BonfireScoring.groups([1, 1, 1, 3, 2], t).size() == 3, "1s pot as singles")
	check(BonfireScoring.groups([3, 1, 2, 5, 4], t).size() == 1, "a run is one group of five")
	check(BonfireScoring.best_points([5, 5, 2, 3, 6], t) == 2 * t.single_five, "best points")

	# --- Run rules ---
	var r := BonfireRun.new(t)
	check(r.state == BonfireRun.State.AIM and r.cold == 5 and r.soul == t.starting_soul and r.hands_left == t.hands, "fresh run")
	check(r.set_throw([4, 1, 4, 2, 4] as Array[int]), "throw with scorers")
	check(not r.can_continue(), "must pot something before bank/rethrow")
	check(r.toggle(0) and r.potted.size() == 3, "clicking one 4 pots the whole 4-4-4")
	check(r.toggle(1) and r.throw_points() == 50, "4-4-4 + 1 = 50")
	check(not r.toggle(3), "a cold die can't be potted")
	check(r.toggle(2) and r.potted == [1], "clicking a 4 again unpots the whole group")
	r.toggle(0)
	var rt := r.rethrow()
	check(not rt.is_empty() and rt["cold"] == 1 and r.pot == 50 and not rt["hot"], "rethrow keeps 50 in the pot, 1 die left")
	check(r.set_throw([5] as Array[int]) and r.toggle(0), "last die is a 5")
	check(r.is_hot(), "every die potted = hot hand")
	rt = r.rethrow()
	check(rt["hot"] and r.cold == 5 and r.multiplier == t.hot_hand_multiplier and r.pot == 55, "hot hand: all 5 back, x2")
	r.set_throw([1, 2, 3, 3, 6] as Array[int])
	r.toggle(0)
	check(r.throw_points() == 20 and r.hand_pot() == 75, "x2 on further scoring")
	var res := r.bank()
	check(res["kind"] == &"bank" and r.coin == 75 and r.hands_left == t.hands - 1 and r.state == BonfireRun.State.AIM, "bank moves the pot to coin")
	r.set_throw([5, 5, 2, 3, 6] as Array[int])
	r.toggle(0)
	r.rethrow()
	var soul := r.soul
	check(not r.set_throw([2, 3, 6, 4] as Array[int]), "nothing lit = bust")
	check(r.soul == soul - t.bust_soul_loss and r.coin == 75 and r.last_result["lost_pot"] == 5, "bust loses the pot and Soul")
	# Clear / fail / run over.
	r.coin = t.coin_target - 10
	r.set_throw([1, 2, 3, 3, 6] as Array[int])
	r.toggle(0)
	check(r.bank()["state"] == BonfireRun.State.CLEARED and r.is_over(), "coin >= target clears the table")
	var f := BonfireRun.new(t)
	for i in t.hands:
		f.set_throw([2, 2, 3, 4, 6] as Array[int])
	check(f.state == BonfireRun.State.FAILED and f.hands_left == 0, "out of hands = table failed")
	var o := BonfireRun.new(t)
	o.soul = 2
	o.set_throw([2, 2, 3, 4, 6] as Array[int])
	check(o.state == BonfireRun.State.RUN_OVER, "Soul 0 = run over")
	print("test_bonfire_scoring: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
