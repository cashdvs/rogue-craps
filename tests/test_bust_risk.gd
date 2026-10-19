## Rethrow bust risk (how_bonfire_plays.md section 4: "Throw 2 cold dice:
## 1 in 3 burns"). BustRisk tries every way the dice can land, so these are
## exact fractions worked out by hand:
##   1 plain die burns on 2, 3, 4, 6          = 4/6  = 2 in 3
##   2 dice burn with no 1/5 and no pair      = 12/36 = 1 in 3
##   3 dice burn on {2,3,6} {2,4,6} {3,4,6}   = 18/216 = 1 in 12
##   4+ dice always light (4 values without 1/5 always pair or run)
## Then weights, face mods, specials and table rules (Cold Sixes, Straight
## Man, Greedy Pot, Madame Shuffle, Kindling), and a cross-check against
## the real BonfireRun throw path with random throws.
##   godot --headless --path . --script res://tests/test_bust_risk.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var t: BonfireTuning
var M: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.000001


func plain(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(null)
	return out


func risk(dice: Array, rules: Array = [], kindling: bool = false) -> Dictionary:
	var r := BonfireRun.new(t, null, -1, maxi(dice.size(), 1))
	var list: Array = []
	for id in rules:
		list.append({"id": id, "params": {}})
	r.set_rules(TableRules.build(list), 3)
	return r.next_throw_risk(dice, kindling)


func _run() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	for id in ["blank", "wild", "kindling"]:
		M[id] = load("res://resources/mods/%s.tres" % id) as FaceModData
	_plain()
	_text()
	_weights_and_mods()
	_rules()
	_monte_carlo()
	print("test_bust_risk: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _plain() -> void:
	check(near(risk(plain(1))["burn"], 2.0 / 3.0), "1 die: 2 in 3 burns")
	check(near(risk(plain(2))["burn"], 1.0 / 3.0), "2 dice: 1 in 3 burns")
	check(near(risk(plain(3))["burn"], 1.0 / 12.0), "3 dice: 1 in 12 (8%) burns")
	check(near(risk(plain(4))["burn"], 0.0), "4 dice can't burn")
	check(near(risk(plain(5))["burn"], 0.0), "5 dice can't burn")
	check(near(risk([])["burn"], 0.0), "no dice: nothing to burn")
	var bone := TableDie.new()
	check(near(risk([bone, bone])["burn"], 1.0 / 3.0), "plain TableDie = null die")


func _text() -> void:
	check(BustRisk.odds_text(2.0 / 3.0) == "2 in 3", "2/3 reads '2 in 3'")
	check(BustRisk.odds_text(1.0 / 3.0) == "1 in 3", "1/3 reads '1 in 3'")
	check(BustRisk.odds_text(1.0 / 12.0) == "1 in 12", "1/12 reads '1 in 12'")
	check(BustRisk.odds_text(7.0 / 54.0) == "13%", "7/54 reads '13%'")
	check(BustRisk.odds_text(0.0) == "no", "0 reads 'no' (chance)")
	check(BustRisk.odds_text(0.004) == "<1%", "tiny reads '<1%'")
	check(BustRisk.prompt(2, risk(plain(2))) == "2 cold dice: 1 in 3 chance nothing lights", "the TH5 wording")
	check(BustRisk.prompt(1, risk(plain(1))) == "1 cold die: 2 in 3 chance nothing lights", "1 die: singular")
	check(BustRisk.prompt(5, risk(plain(5)), true) == "Hot Hand, all 5 dice: they can't bust", "Hot Hand prompt")


func _weights_and_mods() -> void:
	var heavy1 := TableDie.new()
	heavy1.weights = [5.0, 1.0, 1.0, 1.0, 1.0, 1.0]
	check(near(risk([heavy1])["burn"], 4.0 / 10.0), "weights count: a die loaded 5:1 toward the 1 burns 2 in 5")
	var only2 := TableDie.new()
	only2.weights = [0.0, 1.0, 0.0, 0.0, 0.0, 0.0]
	check(near(risk([only2])["burn"], 1.0), "a die that only rolls 2 always burns alone")
	var blanks := TableDie.new()
	blanks.mods = [M["blank"], null, null, null, M["blank"], null]
	check(near(risk([blanks])["burn"], 1.0), "Blank on the 1 and the 5: always burns alone")
	var wild := TableDie.new()
	wild.mods = [null, M["wild"], null, null, null, null]
	check(near(risk([wild])["burn"], 3.0 / 6.0), "a Wild face lights (as a 1 or 5): 1 in 2")
	var faces := TableDie.new()
	faces.faces = [1, 1, 1, 5, 5, 5]
	check(near(risk([faces])["burn"], 0.0), "a die of only 1s and 5s can't burn")
	check(near(risk(plain(2), [], true)["burn"], 0.0), "Kindling armed: can't burn")


func _rules() -> void:
	# Cold Sixes: 6s never light. 2 dice: of the 16 non-1/5 throws only the
	# 2-2, 3-3, 4-4 pairs light -> 13/36. 3 dice: 28/216 = 7/54.
	check(near(risk(plain(1), [&"cold_sixes"])["burn"], 4.0 / 6.0), "Cold Sixes, 1 die: 2 in 3")
	check(near(risk(plain(2), [&"cold_sixes"])["burn"], 13.0 / 36.0), "Cold Sixes, 2 dice: 13/36")
	check(near(risk(plain(3), [&"cold_sixes"])["burn"], 7.0 / 54.0), "Cold Sixes, 3 dice: 7/54")
	# The Straight Man: runs under 5 don't count, so 2-3-4 burns too: 24/216.
	check(near(risk(plain(3), [&"straight_man"])["burn"], 24.0 / 216.0), "Straight Man, 3 dice: 1 in 9")
	# Greedy Pot: a pot needs 2 dice, so 2 dice light only on a pair: 30/36.
	check(near(risk(plain(2), [&"greedy_pot"])["burn"], 30.0 / 36.0), "Greedy Pot, 2 dice: 5 in 6")
	check(near(risk(plain(1), [&"greedy_pot"])["burn"], 2.0 / 3.0), "Greedy Pot, 1 die: a 1 or 5 alone still pots")
	# Madame Shuffle on a single die: if it lights (1 or 5, 1 in 3) she
	# rerolls it, and the reroll burns 2 in 3: 2/3 + 1/3 * 2/3 = 8/9.
	check(near(risk(plain(1), [&"madame_shuffle"])["burn"], 8.0 / 9.0), "Madame Shuffle, 1 die: 8 in 9")


## The exact numbers match what really happens when BonfireRun lands random
## throws (same rules, same ctx).
func _monte_carlo() -> void:
	for case: Array in [[2, []], [3, [&"cold_sixes"]], [2, [&"madame_shuffle"]], [3, [&"madame_shuffle"]]]:
		var n: int = case[0]
		var rules: Array = case[1]
		var want := float(risk(plain(n), rules)["burn"])
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var trials := 6000
		var burns := 0
		for k in trials:
			var r := BonfireRun.new(t, null, 50, n)
			var list: Array = []
			for id in rules:
				list.append({"id": id, "params": {}})
			r.set_rules(TableRules.build(list), k + 1)
			var faces: Array[int] = []
			for i in n:
				faces.append(rng.randi_range(1, 6))
			if not r.set_throw(faces) and not r.kindling_saved:
				burns += 1
		var got := float(burns) / float(trials)
		check(absf(got - want) < 0.025, "%d dice %s: exact %.3f vs %d random throws %.3f" % [n, str(rules), want, trials, got])
