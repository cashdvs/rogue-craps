## Bonfire scoring, bounties and rules (pure):
##   godot --headless --path . --script res://tests/test_bonfire_scoring.gd
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


func sc(faces: Array, bonus: int = 0) -> Dictionary:
	return BonfireScoring.score_selection(faces, t, bonus)


func pts(faces: Array) -> int:
	return int(sc(faces)["points"])


func _initialize() -> void:
	# The sandbox table_1 is a real F1 target table now; this suite tests bounties.
	var sandbox_tuning := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	sandbox_tuning.table_goal = preload("res://tests/bounty_fixture.gd").goal(self)
	if sandbox_tuning.table_goal == null:
		return  # fixture missing: goal() printed why and quits
	set_meta(&"sandbox_tuning", sandbox_tuning)  # keep it cached so every load sees the fixture
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	check(t != null and t.combos.size() == 10 and t.table_goal != null, "tuning loads with 10 combos and Table 1")
	# Each combo: (base + faces) x mult.
	check(pts([1]) == (5 + 1) * 1 and sc([1])["combo"] == &"single", "single 1 = 6")
	check(pts([5]) == (5 + 5) * 1, "single 5 = 10")
	check(pts([3, 3]) == (10 + 6) * 2 and sc([3, 3])["combo"] == &"pair", "pair of 3s = 32")
	check(pts([2, 3, 4]) == (20 + 9) * 2 and sc([4, 2, 3])["combo"] == &"run3", "run of 3 = 58")
	check(pts([2, 2, 6, 6]) == (20 + 16) * 3 and sc([2, 6, 2, 6])["combo"] == &"two_pair", "two pair = 108")
	check(pts([4, 4, 4]) == 126 and sc([4, 4, 4])["combo"] == &"trips", "trips of 4s = (30+12)x3 = 126")
	check(pts([3, 4, 5, 6]) == (35 + 18) * 4 and sc([3, 4, 5, 6])["combo"] == &"run4", "run of 4 = 212")
	check(pts([2, 2, 2, 5, 5]) == (40 + 16) * 5 and sc([5, 2, 5, 2, 2])["combo"] == &"full_house", "full house = 280")
	check(pts([1, 2, 3, 4, 5]) == (60 + 15) * 6 and sc([5, 3, 1, 4, 2])["combo"] == &"run5", "run of 5 = 450")
	check(pts([6, 6, 6, 6]) == (60 + 24) * 8 and sc([6, 6, 6, 6])["combo"] == &"quads", "quads of 6s = 672")
	check(pts([1, 1, 1, 1, 1]) == (120 + 5) * 12 and sc([1, 1, 1, 1, 1])["combo"] == &"five_kind", "five 1s = 1500")
	check(BonfireScoring.formula(sc([4, 4, 4])) == "Trips  (30 + 12) x 3 = 126", "live formula text")
	# Exact match: every potted die belongs to the ONE combo.
	check(not sc([4, 4, 4, 5])["valid"], "4-4-4 + 5 is not a legal pot")
	check(sc([4, 4])["valid"] and sc([4, 4])["combo"] == &"pair", "2 of 4-4-4 is a pair (legal)")
	check(not sc([1, 5])["valid"], "1 + 5 is two combos: illegal")
	check(not sc([2])["valid"] and not sc([2, 3])["valid"], "a lone 2 / 2-3 isn't a combo")
	check(not sc([1, 2, 3, 4, 6])["valid"], "broken straight isn't a combo")
	check(not sc([])["valid"], "empty pot is illegal")
	check(int(sc([4, 4, 4], 2)["mult"]) == 5 and int(sc([4, 4, 4], 2)["points"]) == 42 * 5, "mult bonus adds to the combo mult")
	# Lit dice: part of ANY combo in the throw.
	check(BonfireScoring.lit_indices([2, 3, 6, 4, 6], t) == [0, 1, 2, 3, 4], "run 2-3-4 and the 6-6 pair all light")
	check(BonfireScoring.lit_indices([2, 4, 6, 6, 3], t) == [0, 1, 2, 3, 4], "2-3-4 run + 6 pair")
	check(BonfireScoring.lit_indices([2, 2, 4, 6, 1], t) == [0, 1, 4], "pair of 2s and the 1 light; 4 and 6 cold")
	check(BonfireScoring.lit_indices([2, 4, 6, 6, 4], t).size() == 4, "a 2 alone stays cold")
	check(BonfireScoring.lit_indices([2, 4, 6, 3, 6], t).size() == 5, "bust check sanity")
	check(BonfireScoring.lit_indices([2, 4, 6], t).is_empty(), "2-4-6 = bust")
	check(BonfireScoring.can_extend([0, 1], [2, 3, 6, 4, 6], t) and not BonfireScoring.can_extend([0, 2], [2, 3, 6, 4, 6], t), "selection must stay extendable to one combo")
	# Bounties.
	var g := t.table_goal
	check(g.hands == 5 and g.required.size() == 3 and g.bonus.size() == 1, "Table 1: 3 required + 1 bonus, 5 hands")
	var fh := BonfireScoring.bounty_ticks(g.required + g.bonus, [3, 3, 3, 5, 5])
	check(fh.has(&"triple") and fh.has(&"two_pairs") and fh.has(&"full_house") and not fh.has(&"run3"), "a Full House pot ticks Triple, Two Pairs and Full House")
	check(BonfireScoring.bounty_ticks(g.required, [1, 2, 3, 4, 5]) == [&"run3"], "a Run of 5 pot ticks Run of 3")
	check(BonfireScoring.bounty_ticks(g.required, [6, 6, 6, 6]).has(&"triple") and not BonfireScoring.bounty_ticks(g.required, [6, 6, 6, 6]).has(&"two_pairs"), "quads contain a triple, not two pairs")

	# --- Run rules ---
	var r := BonfireRun.new(t)
	check(r.state == BonfireRun.State.AIM and r.cold == 5 and r.soul == 35 and r.hands_left == 5, "fresh run")
	check(r.set_throw([4, 4, 4, 5, 2] as Array[int]), "throw with combos")
	check(not r.can_continue(), "must pot a combo before bank/rethrow")
	check(not r.toggle(4), "the cold 2 can't be potted")
	check(r.toggle(0) and r.toggle(1) and r.toggle(2) and r.throw_points() == 126, "pot 4-4-4 = 126")
	check(not r.toggle(3), "adding the 5 to 4-4-4 is refused")
	check(r.toggle(2) and r.selection()["combo"] == &"pair", "unpotting one 4 leaves a legal pair")
	r.toggle(2)
	r.rethrow()
	check(r.pot == 126 and r.cold == 2 and r.pending.has(&"triple"), "rethrow: pot 126, 2 cold dice, Triple pending")
	check(not r.is_ticked(t.table_goal.required[0]) and r.is_pending(t.table_goal.required[0]), "ticks are pending until bank")
	r.set_throw([5, 5] as Array[int])
	r.toggle(0)
	r.toggle(1)
	check(r.is_hot(), "potting the last dice = Hot Hand")
	var rt := r.rethrow()
	check(rt["hot"] and r.cold == 5 and r.mult_bonus() == 1 and r.pot == 126 + 40, "Hot Hand: all 5 back, +1 mult")
	r.set_throw([2, 3, 4, 1, 1] as Array[int])
	r.toggle(0); r.toggle(1); r.toggle(2)
	check(r.throw_points() == (20 + 9) * 3, "run of 3 after a Hot Hand scores x(2+1)")
	var b := r.bank()
	check(b["kind"] == &"bank" and r.points == 126 + 40 + 87 and r.hands_left == 4, "bank adds the pot to points")
	check(r.is_ticked(t.table_goal.required[0]) and r.is_ticked(t.table_goal.required[1]) and not r.is_ticked(t.table_goal.required[2]), "bank ticks Triple and Run of 3")
	check(r.mult_bonus() == 0 and r.pot == 0, "Hot Hand bonus resets on bank")
	# Bust loses pending ticks.
	r.set_throw([2, 2, 6, 6, 1] as Array[int])
	r.toggle(0); r.toggle(1); r.toggle(2); r.toggle(3)
	check(r.selection()["combo"] == &"two_pair", "two pair potted")
	r.rethrow()
	check(r.pending.has(&"two_pairs"), "Two Pairs pending")
	var soul := r.soul
	check(not r.set_throw([2] as Array[int]), "nothing lit = bust")
	check(r.soul == soul - 1 and not r.is_ticked(t.table_goal.required[2]) and r.pending.is_empty() and r.last_result["lost_pot"] == 108, "bust: -1 Soul, pot and pending ticks lost")
	# Clear the moment all required are banked: +10 Embers locked in, the
	# table stays open (points turn into Embers when it ends).
	r.set_throw([3, 3, 3, 5, 5] as Array[int])
	for i in 5:
		r.toggle(i)
	b = r.bank()
	check(r.cleared and not r.is_over() and b["cleared_now"] and b["ticked"].has(&"two_pairs") and b["bonus_embers"] == 5, "Full House pot banks Two Pairs (clear, table stays open) + bonus Full House")
	var total_pts := 126 + 40 + 87 + (40 + 19) * 5
	check(r.points == total_pts and r.embers == 5 + 10, "clear: bonus 5 + clear 10 locked in (%d)" % r.embers)
	check(r.leave() and r.state == BonfireRun.State.CLEARED and r.embers == 5 + 10 + total_pts / 100, "Leave: Embers = bonus 5 + clear 10 + points/100 (%d)" % r.embers)
	# Timeout: -3 Soul per unticked required.
	var f := BonfireRun.new(t)
	for i in 5:
		f.set_throw([2, 4, 6] as Array[int])
	check(f.state == BonfireRun.State.FAILED and f.soul == 35 - 5 - 9 and f.table_summary["timeout_soul"] == 9, "out of hands: -1 per bust and -3 per unticked required")
	var o := BonfireRun.new(t)
	o.soul = 1
	o.set_throw([2, 4, 6] as Array[int])
	check(o.state == BonfireRun.State.RUN_OVER, "Soul 0 = run over")
	print("test_bonfire_scoring: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
