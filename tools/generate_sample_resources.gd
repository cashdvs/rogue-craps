## Regenerates the .tres data files in res://resources/ from the design doc
## (/workspace/dice/design/gamblers-descent.md, v0.1 numbers).
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
	_make_chips()
	quit(0 if _ok else 1)


# --- Dice (doc section 6; first playable uses the first 4) --------------------

func _make_dice() -> void:
	_save(DieData.make_standard_d6("Standard Die"), "res://resources/dice/standard_d6.tres")
	_die("ember", "Ember Die", "After a Natural, your next bet pays +1 Coin per pip shown. (Not implemented yet.)")
	_die("weighted_bone", "Weighted Bone", "Once per table, reroll this die. (Not implemented yet.)")
	_die("mirror", "Mirror Die", "1 in 6 chance to copy the other die's face. (Not implemented yet.)")
	_die("lucky_knuckle", "Lucky Knuckle", "The first Seven-out each table refunds 50% of your Pass bet. (Not implemented yet.)")


func _die(id: String, die_name: String, ability: String) -> void:
	var die := DieData.make_standard_d6(die_name)
	die.ability_id = StringName(id)
	die.ability_description = ability
	_save(die, "res://resources/dice/%s.tres" % id)


# --- Bets (doc section 5): Pass, Field, Hard 8 for the proof of concept --------

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

	# One prop bet for the proof of concept (doc: Hard 8, 9:1, unlock 45).
	var hard_8 := _bet(&"hard_8", "Hard 8", BetType.Rule.HARD_WAY, 9, 1, 45,
		"Stays up until resolved: wins on 4-4 before a 7 or an easy 8. Pays 9:1.")
	hard_8.hard_number = 8
	catalog.bets.append(hard_8)

	# Odds, Any Craps and Hard 6 are paused until the shop/table-run work resumes.

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


# --- Chips (relics; doc section 8, first-playable five) -----------------------

func _make_chips() -> void:
	_chip(&"devils_marker", "Devil's Marker", "Your first Natural each table pays 3:1.", [&"on_natural"])
	_chip(&"house_comp", "House Comp", "+1 Coin of interest per roll you finish under the limit (doubles interest).", [&"on_table_won"])
	_chip(&"hot_streak", "Hot Streak", "Each consecutive winning roll adds +10% to payouts; resets on a loss.", [&"on_bet_won", &"on_bet_lost"])
	_chip(&"seventh_seal", "Seventh Seal", "The first Seven-out each floor counts as a push instead of a loss.", [&"on_seven_out"])
	_chip(&"twin_fangs", "Twin Fangs", "Pairs pay +5 Coin each time, and hard-way bets pay +2.", [&"on_roll", &"on_bet_won"])


func _chip(id: StringName, chip_name: String, text: String, hooks: Array[StringName]) -> void:
	var chip := ChipData.new()
	chip.id = id
	chip.display_name = chip_name
	chip.description = text + " (Not implemented yet.)"
	chip.hook_ids = hooks
	_save(chip, "res://resources/chips/%s.tres" % id)


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s (error %d)" % [path, err])
		_ok = false
	else:
		print("Saved ", path)
