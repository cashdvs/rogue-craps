## QA-only statistical check. Not part of run_tests.sh.
## Run: godot --headless --path . --script res://tests/qa_/qa_craps_stats.gd
extends SceneTree
var fails := 0
func check(name: String, obs: float, exp: float, n: int) -> void:
	var se := sqrt(exp * (1.0 - exp) / n)
	var z := (obs - exp) / se
	var ok := absf(z) <= 3.0
	if not ok: fails += 1
	print("%s  %-28s obs=%.5f exp=%.5f z=%+.2f (n=%d)" % ["PASS" if ok else "FAIL", name, obs, exp, z, n])
func _init() -> void:
	var die: DieData = load("res://resources/dice/standard_d6.tres")
	var dice: Array[DieData] = [die.make_run_copy(), die.make_run_copy()]
	var roller := DiceRoller.new(12345)
	var r := CrapsRound.new()
	var GAMES := 100000
	var wins := 0; var nat := 0; var crp := 0; var pts := 0
	var sums := {}; var rolls := 0
	var pt_games := {}; var pt_wins := {}
	for g in GAMES:
		while true:
			var v := DiceRoller.face_values(roller.roll_dice(dice))
			var res := r.resolve_dice(v)
			rolls += 1
			sums[res.total] = sums.get(res.total, 0) + 1
			match res.outcome:
				RollResult.Outcome.NATURAL_WIN: nat += 1
				RollResult.Outcome.CRAPS_LOSS: crp += 1
				RollResult.Outcome.POINT_SET:
					pts += 1; pt_games[res.total] = pt_games.get(res.total, 0) + 1
				RollResult.Outcome.POINT_HIT:
					pt_wins[res.total] = pt_wins.get(res.total, 0) + 1
			if res.is_decision():
				if res.is_win(): wins += 1
				break
	check("pass-line win rate", float(wins)/GAMES, 244.0/495.0, GAMES)
	check("come-out natural", float(nat)/GAMES, 8.0/36.0, GAMES)
	check("come-out craps", float(crp)/GAMES, 4.0/36.0, GAMES)
	check("point established", float(pts)/GAMES, 24.0/36.0, GAMES)
	for s in range(2, 13):
		check("sum %d" % s, float(sums.get(s, 0))/rolls, (6 - absi(s - 7)) / 36.0, rolls)
	var ways := {4:3,5:4,6:5,8:5,9:4,10:3}
	for p in ways:
		var n: int = pt_games.get(p, 0)
		check("P(make point %d)" % p, float(pt_wins.get(p, 0))/n, ways[p]/(ways[p]+6.0), n)
	# determinism
	var a := DiceRoller.new(777); var b := DiceRoller.new(777)
	var same := true
	for i in 10000:
		if DiceRoller.face_values(a.roll_dice(dice)) != DiceRoller.face_values(b.roll_dice(dice)): same = false
	print("%s  determinism seed 777 x10000" % ("PASS" if same else "FAIL"))
	if not same: fails += 1
	# edge: seed 0 and negative seeds
	var z1 := DiceRoller.new(0); var z2 := DiceRoller.new(0)
	print("INFO  seed 0 reproducible: %s" % str(DiceRoller.face_values(z1.roll_dice(dice)) == DiceRoller.face_values(z2.roll_dice(dice))))
	print("=== QA stats: %d failed, rolls=%d ===" % [fails, rolls])
	quit(1 if fails > 0 else 0)
