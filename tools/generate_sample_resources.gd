## Regenerates the .tres data files in res://resources/ from the design doc
## (/workspace/dice/design/gamblers-descent.md, v0.3 numbers).
##
## Run:  godot --headless --path . --script res://tools/generate_sample_resources.gd
##
## Why a script instead of hand-writing .tres? Godot's text format for nested
## typed arrays/dictionaries is fiddly; letting ResourceSaver write it
## guarantees valid files. After generating, tweak them in the inspector
## (but re-running this script overwrites your tweaks!).
extends SceneTree

var _ok: bool = true


func _initialize() -> void:
	_make_dice()
	var catalog := _make_bets()
	_save(catalog, "res://resources/bets/bet_catalog.tres")
	_make_tuning()
	quit(0 if _ok else 1)


# --- Dice: the POC uses 2 plain six-sided dice ---------------------------------

func _make_dice() -> void:
	_save(DieData.make_standard_d6("Bone Die"), "res://resources/dice/standard_d6.tres")


# --- Bets (doc section 5): Pass, Field, Any Craps for the proof of concept -----

func _make_bets() -> BetCatalog:
	var catalog := BetCatalog.new()

	var pass_bet := _bet(&"pass", "Natural (Pass)", BetType.Rule.PASS, 1, 1, 0,
		"Wins on a come-out 7 or 11, or when the Point is hit. Loses on 2, 3, 12, or a Seven-out. Pays 1:1.")
	catalog.bets.append(pass_bet)

	var field := _bet(&"field", "Field", BetType.Rule.ONE_ROLL, 1, 1, 20,
		"One roll: wins on 2, 3, 4, 9, 10, 11, 12. Pays 1:1, but 2 pays 2:1 and 12 pays 3:1.")
	field.winning_totals = [2, 3, 4, 9, 10, 11, 12]
	field.payout_overrides = {2: Vector2i(2, 1), 12: Vector2i(3, 1)}
	catalog.bets.append(field)

	# The one prop bet for the POC (doc v0.3 section 5: Any Craps 7:1, unlock 25).
	var any_craps := _bet(&"any_craps", "Any Craps", BetType.Rule.ONE_ROLL, 7, 1, 25,
		"One roll: wins on 2, 3, or 12. Pays 7:1.")
	any_craps.winning_totals = [2, 3, 12]
	catalog.bets.append(any_craps)

	for bet in catalog.bets:
		_save(bet, "res://resources/bets/%s.tres" % bet.id)
	# Re-load so the catalog references the saved files instead of embedding copies.
	var linked := BetCatalog.new()
	for bet in catalog.bets:
		linked.bets.append(load("res://resources/bets/%s.tres" % bet.id) as BetType)
	return linked


func _bet(id: StringName, bet_name: String, rule: BetType.Rule, num: int, den: int, cost: int, text: String) -> BetType:
	var bet := BetType.new()
	bet.id = id
	bet.display_name = bet_name
	bet.rule = rule
	bet.payout_numerator = num
	bet.payout_denominator = den
	bet.unlock_cost = cost
	bet.description = text
	return bet


# --- Tuning: every POC number in one file (doc v0.3 sections 2, 3, 6, 12) ------

func _make_tuning() -> void:
	var hot := TableRuleData.new()
	hot.id = &"hot_seven"
	hot.display_name = "Hot Seven"
	hot.description = "Seven-outs deal double Soul damage."
	hot.seven_out_soul_multiplier = 2
	var t := TuningData.new()  # Defaults in tuning_data.gd are the doc numbers.
	t.table_rule = hot          # Saved inline, so the rule's numbers live in this file too.
	_save(t, "res://resources/tuning/poc_tuning.tres")


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s (error %d)" % [path, err])
		_ok = false
	else:
		print("Saved ", path)
