## Nonstandard dice scoring (design/nonstandard_dice.md):
##   §3 faces count at their printed value; faces above 6 light as singles
##      ((5 + face) x 1), runs and sets work past 6, a 0 face never lights,
##   §4 a FULL throw that lights nothing is thrown again for free,
##   §5 Wild / Step reach above 6 only up to the tray's highest face,
##   §10 Caltrop (+2 mult on a run), Knucklebone (a set scores one Seal level
##      higher), Ferryman's Coin (Heads copies the highest, Tails the lowest,
##      alone Heads 5 / Tails Blank). (Mister Wick etc.: PR #99.)
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
	_caltrop_knucklebone()
	_ferryman()
	_bust_risk()
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
	# PM ruling 4: a face of value 0 OR LESS never scores.
	check(not sc([d(-1)])["valid"] and not sc([d(-2), d(-2)])["valid"] and not sc([d(0), d(0), d(0)])["valid"], "a face below 1 never scores (alone, as a pair, as trips)")
	check(not sc([d(0), d(5)])["valid"] and BonfireScoring.plain_values([d(-3), d(2)]) == ([2] as Array[int]), "a 0 / negative face can't ride along in a pot or a bounty")


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

func _caltrop_knucklebone() -> void:
	var plain_run := sc([d(1), d(2), d(3)])
	var cal_run := sc([d(1, null, &"caltrop"), d(2), d(3)])
	check(cal_run["mult"] == plain_run["mult"] + t.caltrop_run_mult and t.caltrop_run_mult == 2, "Caltrop: a run containing it gets +2 mult")
	check(sc([d(4, null, &"caltrop"), d(4)])["mult"] == sc([d(4), d(4)])["mult"], "Caltrop: no bonus on a set")
	check(sc([d(1, null, &"caltrop")])["mult"] == 1, "Caltrop: no bonus on a single")
	var pair := sc([d(3), d(3)])
	var kpair := sc([d(3, null, &"knucklebone"), d(3)])
	var rd := load("res://resources/map/bonfire_run.tres") as RunData
	var step := Vector2i(rd.seal_base_step[&"pair"], rd.seal_mult_step[&"pair"])
	check(kpair["seal_up"] and kpair["base"] == pair["base"] + step.x and kpair["mult"] == pair["mult"] + step.y, "Knucklebone: a Pair scores one Seal level higher (+5 base, +1 mult)")
	check(kpair["points"] == (pair["base"] + 5 + 6) * (pair["mult"] + 1), "Knucklebone: Pair 3-3 points")
	var two := sc([d(3, null, &"knucklebone"), d(3, null, &"knucklebone")])
	check(two["points"] == kpair["points"], "Knucklebone: two in one pot is still one level")
	var trips := sc([d(6, null, &"knucklebone"), d(6), d(6)])
	check(trips["combo"] == &"trips" and trips["mult"] == sc([d(6), d(6), d(6)])["mult"] + 1 and trips["base"] == sc([d(6), d(6), d(6)])["base"] + 15, "Knucklebone: Trips +15 base +1 mult")
	check(not sc([d(1, null, &"knucklebone"), d(2), d(3)])["seal_up"], "Knucklebone: no level on a run")
	check(not sc([d(1, null, &"knucklebone")])["seal_up"], "Knucklebone: no level on a single")
	var custom := sc([d(3, null, &"knucklebone"), d(3)], {"seal_steps": {&"pair": Vector2i(1, 2)}})
	check(custom["base"] == pair["base"] + 1 and custom["mult"] == pair["mult"] + 2, "Knucklebone: the run can pass its own Seal steps")
	# PM ruling 3: Pair / Trips / Four / Five of a kind only; never Two Pair or Full House.
	var tp := sc([d(3, null, &"knucklebone"), d(3), d(5), d(5)])
	check(tp["combo"] == &"two_pair" and not tp["seal_up"], "Knucklebone: no level on Two Pair")
	var fh := sc([d(3, null, &"knucklebone"), d(3), d(5), d(5), d(5)])
	check(fh["combo"] == &"full_house" and not fh["seal_up"], "Knucklebone: no level on a Full House")
	# The steps are the run's RunData Seal steps, passed through rule_ctx.
	check(NonStdDice.seal_steps(rd) == NonStdDice.default_seal_steps() and NonStdDice.default_seal_steps()[&"quads"] == Vector2i(rd.seal_base_step[&"quads"], rd.seal_mult_step[&"quads"]),
		"Knucklebone: steps = RunData seal_base_step / seal_mult_step")
	var kr := run_with([], [], 2)
	kr.seal_steps = {&"pair": Vector2i(7, 3)}
	check(kr.rule_ctx()["seal_steps"] == {&"pair": Vector2i(7, 3)}, "Knucklebone: rule_ctx passes the run's seal_steps")


## A Tithe d10 as the run sends it (faces 1-10).
func d10() -> TableDie:
	return TableDie.new(&"tithe", "Tithe", &"d10")


## A d4 whose faces are all 0 (never light, §2): a non-d6 that makes a full
## throw able to light nothing (with §3, 3d6 + 2d10 never can).
func blank_d4() -> TableDie:
	var td := TableDie.new(&"blank_d4", "Blank d4", &"d4")
	td.faces = [0, 0, 0, 0] as Array[int]
	return td


func _bust_risk() -> void:
	# 3d6 + 2 blank d4s can light nothing (the d6s show e.g. 2, 3, 6); as a
	# full throw that's a free rethrow, so the prompt's burn chance is 0.
	var mixed: Array = [null, null, null, blank_d4(), blank_d4()]
	var raw: float = BustRisk.chance(mixed, t)["burn"]
	check(raw > 0.0, "3d6 + 2 blank d4s alone can light nothing (raw %.4f)" % raw)
	var r := run_with([], [], 5)
	var full := r.next_throw_risk(mixed)
	check(full["burn"] == 0.0 and full["free_rethrow"], "full throw with a non-d6: burn 0 (free rethrow)")
	r.free_rethrows_in_a_row = NonStdDice.MAX_FREE_RETHROWS - 1
	check(r.next_throw_risk(mixed)["burn"] == 0.0, "full throw, %d free rethrows so far: still free" % (NonStdDice.MAX_FREE_RETHROWS - 1))
	r.free_rethrows_in_a_row = NonStdDice.MAX_FREE_RETHROWS
	var last := r.next_throw_risk(mixed)
	check(is_equal_approx(float(last["burn"]), raw) and not last["free_rethrow"], "after %d free rethrows in a row the next no-light busts: real chance %.4f" % [NonStdDice.MAX_FREE_RETHROWS, raw])
	# A d6-only full throw: unchanged (a Cold Sixes table really can burn).
	var plain5: Array = [null, null, null, null, null]
	var cs := run_with([{"id": &"cold_sixes", "params": {"face": 6}}], [], 5)
	var cs_risk := cs.next_throw_risk(plain5)
	check(not cs_risk["free_rethrow"] and is_equal_approx(float(cs_risk["burn"]), float(BustRisk.chance(plain5, t, cs.next_throw_ctx(5), cs.throw_effects())["burn"])) and float(cs_risk["burn"]) > 0.0,
		"d6-only full throw: unchanged (Cold Sixes %.4f)" % float(cs_risk["burn"]))
	# A partial throw (2 dice left after potting 3), even with a non-d6: unchanged.
	var p := run_with([], [], 5)
	p.cold = 2
	var two: Array = [null, d10()]
	var part := p.next_throw_risk(two)
	check(not part["free_rethrow"] and is_equal_approx(float(part["burn"]), float(BustRisk.chance(two, t, p.next_throw_ctx(2), p.throw_effects())["burn"])) and float(part["burn"]) > 0.0,
		"partial throw with a d10: unchanged (%.4f)" % float(part["burn"]))


func _ferryman() -> void:
	check(TableRules.build([], [&"ferryman"])[0] is DieFerryman, "ferryman special -> DieFerryman handler")
	# Heads (landed 5 = slot 1) copies the highest non-copy die.
	var r := run_with([], [&"ferryman"], 3)
	var th := TableThrow.make([5, 2, 4] as Array[int], [], [coin(), plain(), plain()])
	r.land_throw(th)
	check(r.throw_faces == ([4, 2, 4] as Array[int]) and th.changes[0]["by"] == &"ferryman", "Heads copies the highest die (4)")
	check(th.slots[0] == 1, "Heads keeps its landed slot (1)")
	# Tails (landed 0 = slot 2) copies the lowest.
	r = run_with([], [&"ferryman"], 3)
	th = TableThrow.make([0, 2, 4] as Array[int], [], [coin(), plain(), plain()])
	r.land_throw(th)
	check(r.throw_faces == ([2, 2, 4] as Array[int]) and th.slots[0] == 2, "Tails copies the lowest die (2), keeps slot 2")
	r.toggle(0)
	r.toggle(1)
	check(r.selection()["combo"] == &"pair", "the copy is a natural face (2-2 Pair)")
	# Other copy dice are never targets.
	r = run_with([], [&"mirror", &"ferryman"], 3)
	th = TableThrow.make([5, 6, 2] as Array[int], [], [coin(), special_die(&"mirror"), plain()])
	th.positions = [Vector3.ZERO, Vector3(0.1, 0, 0), Vector3(0.3, 0, 0)] as Array[Vector3]
	r.land_throw(th)
	check(r.throw_faces == ([2, 2, 2] as Array[int]), "Heads skips the Mirror's 6 (copies 2); the Mirror skips the coin")
	r = run_with([], [&"ferryman"], 4)
	th = TableThrow.make([5, 0, 3, 6] as Array[int], [], [coin(), coin(), plain(), plain()])
	r.land_throw(th)
	check(r.throw_faces == ([6, 3, 3, 6] as Array[int]), "two coins: Heads -> 6, Tails -> 3 (never each other)")
	# The copy keeps the coin's own face mod.
	var hot := coin()
	hot.mods[0] = M.hellfire
	r = run_with([], [&"ferryman"], 2)
	th = TableThrow.make([5, 3] as Array[int], [hot.mod_at(1), null], [hot, plain()])
	r.land_throw(th)
	check(r.throw_faces == ([3, 3] as Array[int]) and r.throw_mods[0] == M.hellfire, "the copy keeps the coin's carved mod (Hellfire 3)")
	# Thrown alone (here: a 1-die rethrow out of a 3-die hand).
	r = run_with([], [&"ferryman"], 3)
	th = TableThrow.make([5] as Array[int], [], [coin()])
	check(r.land_throw(th) and r.throw_faces == ([5] as Array[int]), "alone: Heads = 5 and lights")
	r = run_with([], [&"ferryman"], 3)
	var hands := r.hands_left
	th = TableThrow.make([0] as Array[int], [], [coin()])
	check(not r.land_throw(th) and r.hands_left == hands - 1, "alone: Tails = Blank, a bust")
	check((th.mods[0] as FaceModData).effect == FaceModData.Effect.BLANK, "alone: Tails face turned Blank")
	# A full 1-die handful of just the coin: Tails is a full throw -> free.
	r = run_with([], [&"ferryman"], 1)
	th = TableThrow.make([0] as Array[int], [], [coin()])
	check(not r.land_throw(th) and r.free_rethrow, "a lone coin as the whole handful: Tails is a free rethrow")
	# Order: the copy happens before the boss's lit check (Cold Sixes).
	r = run_with([{"id": &"cold_sixes", "params": {}}], [&"ferryman"], 5)
	th = TableThrow.make([5, 6, 1] as Array[int], [], [coin(), plain(), plain()])
	r.land_throw(th)
	check(r.throw_faces.size() == 3 and r.throw_faces[0] == 6 and r.lit() == ([2] as Array[int]), "Heads copies the 6, then Cold Sixes keeps it from lighting")
