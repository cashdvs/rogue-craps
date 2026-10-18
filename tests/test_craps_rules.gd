## Headless tests for the craps rules and seeded dice rolling.
##
## Run:
##   godot --headless --path /workspace/dice/game --script res://tests/test_craps_rules.gd
##
## Prints PASS/FAIL per case and exits with code 1 if anything fails, so it
## can be used in CI. No test framework needed: just tiny helper functions.
extends SceneTree

const POINT_NUMBERS: Array[int] = [4, 5, 6, 8, 9, 10]

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== The Gambler's Descent: craps rules tests ===")
	_test_come_out_every_total()
	_test_point_phase_for_every_point()
	_test_reset_after_decisions()
	_test_rigged_rules()
	_test_seeded_rolls_from_die_data()
	_test_sample_resources_load()

	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- Tiny assertion helpers ---------------------------------------------------

func _check(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS  ", name)
	else:
		_failed += 1
		print("FAIL  ", name, ("  -> " + detail) if detail != "" else "")


func _check_eq(actual: Variant, expected: Variant, name: String) -> void:
	_check(actual == expected, name, "expected %s, got %s" % [str(expected), str(actual)])


func _outcome_str(o: int) -> String:
	return RollResult.outcome_name(o)


# --- Come-out phase -----------------------------------------------------------

func _test_come_out_every_total() -> void:
	for total in range(2, 13):
		var craps := CrapsRound.new()
		var result := craps.resolve_total(total)
		var expected: RollResult.Outcome
		if total == 7 or total == 11:
			expected = RollResult.Outcome.NATURAL_WIN
		elif total == 2 or total == 3 or total == 12:
			expected = RollResult.Outcome.CRAPS_LOSS
		else:
			expected = RollResult.Outcome.POINT_SET
		var label := "come-out %d -> %s" % [total, _outcome_str(expected)]
		_check_eq(_outcome_str(result.outcome), _outcome_str(expected), label)

		if expected == RollResult.Outcome.POINT_SET:
			_check(craps.phase == CrapsRound.Phase.POINT and craps.point == total,
				"come-out %d sets Point to %d" % [total, total],
				"phase=%d point=%d" % [craps.phase, craps.point])
		else:
			_check(craps.phase == CrapsRound.Phase.COME_OUT and craps.point == 0,
				"come-out %d stays in come-out with no Point" % total,
				"phase=%d point=%d" % [craps.phase, craps.point])
		_check(result.message != "", "come-out %d has a message" % total)


# --- Point phase --------------------------------------------------------------

func _test_point_phase_for_every_point() -> void:
	for point in POINT_NUMBERS:
		# Point hit.
		var craps := CrapsRound.new()
		craps.resolve_total(point)
		var hit := craps.resolve_total(point)
		_check_eq(_outcome_str(hit.outcome), "POINT_HIT", "point %d: rolling %d hits the Point" % [point, point])
		_check(hit.is_win() and hit.is_decision(), "point %d: Point hit counts as a win" % point)

		# Seven-out.
		craps = CrapsRound.new()
		craps.resolve_total(point)
		var seven := craps.resolve_total(7)
		_check_eq(_outcome_str(seven.outcome), "SEVEN_OUT", "point %d: rolling 7 is a seven-out" % point)
		_check(seven.is_loss() and seven.is_decision(), "point %d: seven-out counts as a loss" % point)

		# No decision for every other total (including 2, 3, 11, 12 which only
		# matter on the come-out).
		var all_ok := true
		var bad := ""
		for total in range(2, 13):
			if total == point or total == 7:
				continue
			craps = CrapsRound.new()
			craps.resolve_total(point)
			var r := craps.resolve_total(total)
			if r.outcome != RollResult.Outcome.NO_DECISION or craps.point != point \
					or craps.phase != CrapsRound.Phase.POINT or r.is_decision():
				all_ok = false
				bad += " %d->%s" % [total, _outcome_str(r.outcome)]
		_check(all_ok, "point %d: all other totals are no-decision and keep the Point" % point, bad)

		# Several no-decisions in a row, then the hit, still works.
		craps = CrapsRound.new()
		craps.resolve_total(point)
		for filler in [2, 3, 11, 12]:
			if filler != point:
				craps.resolve_total(filler)
		_check_eq(_outcome_str(craps.resolve_total(point).outcome), "POINT_HIT",
			"point %d: still hit after several no-decisions" % point)


# --- State reset after a decision ---------------------------------------------

func _test_reset_after_decisions() -> void:
	var craps := CrapsRound.new()

	craps.resolve_total(6)   # Point = 6
	var hit := craps.resolve_total(6)
	_check(craps.phase == CrapsRound.Phase.COME_OUT and craps.point == 0,
		"reset: after Point hit, back to come-out with no Point")
	_check(hit.point_before == 6 and hit.point_after == 0, "reset: Point hit result records 6 -> 0",
		"%d -> %d" % [hit.point_before, hit.point_after])

	# Now a 7 on the come-out must be a natural, NOT a seven-out.
	_check_eq(_outcome_str(craps.resolve_total(7).outcome), "NATURAL_WIN",
		"reset: 7 after a Point hit is a natural")

	craps.resolve_total(9)   # Point = 9
	craps.resolve_total(7)   # seven-out
	_check(craps.phase == CrapsRound.Phase.COME_OUT and craps.point == 0,
		"reset: after seven-out, back to come-out with no Point")
	# And 9 on the next come-out sets a fresh Point instead of "hitting" it.
	_check_eq(_outcome_str(craps.resolve_total(9).outcome), "POINT_SET",
		"reset: old Point is forgotten after seven-out")

	craps.reset()
	_check(craps.phase == CrapsRound.Phase.COME_OUT and craps.point == 0, "reset(): clears the Point")

	# resolve_dice sums values and remembers them.
	craps = CrapsRound.new()
	var dice: Array[int] = [5, 6]
	var r := craps.resolve_dice(dice)
	_check(r.total == 11 and r.die_values == dice and r.outcome == RollResult.Outcome.NATURAL_WIN,
		"resolve_dice([5, 6]) totals 11 and is a natural", str(r))

	# Signal fires once per roll.
	var counter := [0]
	craps.roll_resolved.connect(func(_res: RollResult) -> void: counter[0] += 1)
	craps.resolve_total(4)
	craps.resolve_total(8)
	_check_eq(counter[0], 2, "roll_resolved signal fires once per roll")


# --- Boss "rigging" hooks -----------------------------------------------------

func _test_rigged_rules() -> void:
	var craps := CrapsRound.new()
	var rigged_naturals: Array[int] = [7]
	craps.natural_totals = rigged_naturals       # Dealer removes 11 as a natural.
	craps.craps_totals.append(11)                # ...and makes it craps instead.
	_check_eq(_outcome_str(craps.resolve_total(11).outcome), "CRAPS_LOSS",
		"rigged: Dealer can turn 11 into craps")


# --- Deterministic dice rolling -----------------------------------------------

func _test_seeded_rolls_from_die_data() -> void:
	var d6 := load("res://resources/dice/standard_d6.tres") as DieData
	_check(d6 != null, "seeded: standard_d6.tres loads as DieData")
	if d6 == null:
		return
	var dice: Array[DieData] = [d6, d6]

	var roller_a := DiceRoller.new(12345)
	var roller_b := DiceRoller.new(12345)
	var seq_a: Array = []
	var seq_b: Array = []
	var in_range := true
	for i in range(50):
		var va := DiceRoller.face_values(roller_a.roll_dice(dice))
		var vb := DiceRoller.face_values(roller_b.roll_dice(dice))
		seq_a.append(va)
		seq_b.append(vb)
		for v in va:
			if v < 1 or v > 6:
				in_range = false
	_check(seq_a == seq_b, "seeded: same seed gives the same 50 rolls")
	_check(in_range, "seeded: all d6 values are within 1-6")

	var roller_c := DiceRoller.new(999)
	var seq_c: Array = []
	for i in range(50):
		seq_c.append(DiceRoller.face_values(roller_c.roll_dice(dice)))
	_check(seq_a != seq_c, "seeded: a different seed gives a different sequence")

	# Full pipeline: seeded roll -> rules, reproducible end to end.
	var r1 := CrapsRound.new().resolve_dice(DiceRoller.face_values(DiceRoller.new(42).roll_dice(dice)))
	var r2 := CrapsRound.new().resolve_dice(DiceRoller.face_values(DiceRoller.new(42).roll_dice(dice)))
	_check(r1.die_values == r2.die_values and r1.outcome == r2.outcome,
		"seeded: roll + resolve is reproducible (seed 42 -> %s, %s)" % [str(r1.die_values), _outcome_str(r1.outcome)])

	# A die whose faces were modified (all 6s) always rolls 6: face mods work.
	var loaded := d6.make_run_copy()
	for face in loaded.faces:
		face.value = 6
	var loaded_pair: Array[DieData] = [loaded, loaded]
	var lv := DiceRoller.face_values(DiceRoller.new(7).roll_dice(loaded_pair))
	var all_sixes: Array[int] = [6, 6]
	_check(lv == all_sixes, "face mods: an all-6 die always rolls 6", str(lv))
	_check_eq(d6.faces[0].value, 1, "face mods: run copy does not alter the shared .tres")


# --- Sample data --------------------------------------------------------------

func _test_sample_resources_load() -> void:
	var d6 := load("res://resources/dice/standard_d6.tres") as DieData
	var values: Array[int] = []
	for face in d6.faces:
		values.append(face.value)
	var one_to_six: Array[int] = [1, 2, 3, 4, 5, 6]
	_check(values == one_to_six, "data: standard d6 has faces 1-6", str(values))

	var bet := load("res://resources/bets/pass_line.tres") as BetType
	_check(bet != null and bet.id == &"pass_line" and bet.is_starter(), "data: Pass Line bet loads and is a starter")
	if bet != null:
		_check_eq(bet.profit_for(10), 10, "data: Pass Line pays even money")

	var relic := load("res://resources/relics/rabbits_foot.tres") as RelicData
	_check(relic != null and relic.listens_to(&"on_seven_out"), "data: Rabbit's Foot relic loads with its hook")
