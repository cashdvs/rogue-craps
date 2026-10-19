## Nonstandard dice scoring (design/nonstandard_dice.md):
##   §3 faces count at their printed value; faces above 6 light as singles
##      ((5 + face) x 1), runs and sets work past 6, a 0 face never lights,
##   §4 a FULL throw that lights nothing is thrown again for free,
##   §5 Wild / Step reach above 6 only up to the tray's highest face,
##   godot --headless --path . --script res://tests/test_nonstd_scoring.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var t: BonfireTuning
var M: Dictionary = {}


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func d(v: int, m: FaceModData = null, sp: StringName = &"") -> Dictionary:
	return BonfireScoring.make_die(v, m, sp)


func sc(dice: Array, ctx: Dictionary = {}) -> Dictionary:
	return BonfireScoring.score_selection(dice, t, 0, ctx)


func run_with(rules: Array, specials: Array = [], dice: int = 5) -> BonfireRun:
	var r := BonfireRun.new(t, null, -1, dice)
	r.set_rules(TableRules.build(rules, specials), 7)
	return r


## Ferryman's Coin as the run sends it: faces [5, 0] (slot 1 heads, 2 tails).
func coin() -> TableDie:
	var c := TableDie.new(&"ferryman", "Ferryman's Coin", &"coin")
	c.special = &"ferryman"
	c.faces = [5, 0] as Array[int]
	c.weights = [1.0, 1.0] as Array[float]
	return c


func plain() -> TableDie:
	return TableDie.new()


func special_die(id: StringName) -> TableDie:
	var x := TableDie.new(id)
	x.special = id
	return x


func _initialize() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	for id in ["hellfire", "blank", "wild", "step"]:
		M[id] = load("res://resources/mods/%s.tres" % id) as FaceModData
	_faces_past_six()
	_free_rethrow()
	_wild_cap()
	print("test_nonstd_scoring: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _faces_past_six() -> void:
	var s := sc([d(8)])
	check(s["valid"] and s["combo"] == &"single" and s["points"] == 13, "an 8 lights as a single: (5 + 8) x 1 = 13")
	check(sc([d(20)])["points"] == 25, "a 20 single scores 25")
	check(not sc([d(6)])["valid"] and not sc([d(4)])["valid"], "plain 6 / 4 still don't score alone")
	s = sc([d(6), d(7), d(8)])
	check(s["valid"] and s["combo"] == &"run3", "6-7-8 is a Run of 3 (runs extend past 6)")
	check(sc([d(9), d(10), d(11), d(12), d(13)])["combo"] == &"run5", "9..13 is a Run of 5")
	check(sc([d(8), d(8)])["combo"] == &"pair", "8-8 is a Pair")
	check(not sc([d(0)])["valid"], "a 0 face never scores")
	check(BonfireScoring.lit_indices([d(0), d(2), d(4)], t) == ([] as Array[int]), "a 0 face never lights")
	check(BonfireScoring.lit_indices([d(0), d(7), d(3)], t) == ([1] as Array[int]), "a 7 lights next to a 0")
	check(BonfireScoring.plain_values([d(0), d(9)]) == ([9] as Array[int]), "plain_values skips a 0 face")


func _free_rethrow() -> void:
	# 2-die handful of d8s: [2, 4] lights nothing.
	var wide: Array = [TableDie.new(&"x", "X", &"d8"), TableDie.new(&"y", "Y", &"d8")]
	var r := run_with([], [], 2)
	var hands := r.hands_left
	var soul := r.soul
	check(not r.set_throw([2, 4] as Array[int], [], wide), "full throw lighting nothing: not lit")
	check(r.free_rethrow and r.state == BonfireRun.State.AIM, "full throw lighting nothing: free rethrow, back to aiming")
	check(r.hands_left == hands and r.soul == soul and r.throws_this_hand == 0, "free rethrow: no bust, no Soul lost, still the hand's first throw")
	check(r.set_throw([1, 4] as Array[int], [], wide) and not r.free_rethrow, "the free rethrow then plays normally")
	# Plain d6 dice only: unchanged, a full throw that lights nothing busts.
	r = run_with([], [], 2)
	check(not r.set_throw([2, 4] as Array[int], [], [plain(), plain()]) and not r.free_rethrow and r.hands_left == hands - 1, "plain d6s only: a full throw lighting nothing still busts")
	# A partial rethrow that lights nothing is still a bust.
	r = run_with([], [], 2)
	r.set_throw([1, 4] as Array[int], [], wide)
	r.toggle(0)
	r.rethrow()
	check(not r.set_throw([4] as Array[int], [], [wide[1]]) and not r.free_rethrow and r.hands_left == hands - 1, "a partial rethrow lighting nothing busts")
	# A handful that can never light busts after MAX_FREE_RETHROWS.
	r = run_with([], [], 2)
	var blanks := [M.blank, M.blank]
	for i in BonfireRun.MAX_FREE_RETHROWS:
		r.set_throw([5, 5] as Array[int], blanks, wide)
	check(r.free_rethrows_in_a_row == BonfireRun.MAX_FREE_RETHROWS and r.hands_left == hands, "all-Blank handful: free rethrows up to the cap")
	r.set_throw([5, 5] as Array[int], blanks, wide)
	check(not r.free_rethrow and r.hands_left == hands - 1, "then it busts (no endless loop)")


func _wild_cap() -> void:
	# A Wild next to a 9 and 10: 8 only if a die in the tray can show 8+.
	var dice := [d(9), d(10), d(1, M.wild)]
	check(not sc(dice)["valid"], "Wild capped at 6 by default: 9-10-Wild is no run")
	var s := sc(dice, {"wild_max": 10})
	check(s["valid"] and s["combo"] == &"run3" and s["values"].has(8), "wild_max 10: Wild becomes 8 (8-9-10)")
	check(sc([d(5, M.wild), d(5, M.wild)])["combo"] == &"pair", "two Wilds still pair up within 1-6")
	# Step: an 8 steps to 9 only if the tray reaches 9+.
	var steps := [d(8, M.step), d(10), d(11)]
	check(not sc(steps)["valid"], "Step capped: 8 can't step to 9 without a 9+ die in the tray")
	check(sc(steps, {"wild_max": 11})["combo"] == &"run3", "wild_max 11: 8 steps to 9 (9-10-11)")
	# The run's cap = the highest face any die of this throw can show.
	var r := run_with([], [], 3)
	var lantern := TableDie.new(&"lantern", "Lantern", &"d8")
	r.set_throw([9, 10, 1] as Array[int], [null, null, M.wild], [plain(), plain(), plain()])
	check(r.wild_max() == 6, "run wild_max: 6 with plain dice")
	r = run_with([], [], 3)
	r.set_throw([2, 3, 1] as Array[int], [], [lantern, plain(), plain()])
	check(r.wild_max() == 8 and int(r.rule_ctx()["wild_max"]) == 8, "run wild_max: 8 with a d8 in the tray")
	check((r.rule_ctx()["cold_values"] as Array).is_empty(), "no cold values without rules")

