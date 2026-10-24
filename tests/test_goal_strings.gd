## GoalStrings: the strings_v1 table-goal cells word for word (section 5 of
## starting_dice_options_v1.md) and their filled forms, singular / plural.
##   godot --headless --path . --script res://tests/test_goal_strings.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _eq(got: String, want: String, what: String) -> void:
	_check(got == want, "%s: got '%s', want '%s'" % [what, got, want])


func _initialize() -> void:
	var G := GoalStrings
	# Verbatim strings_v1 cells.
	_eq(G.get_text("card_header"), "Clear the table: {left} more bounty/bounties · {h} hands left", "card_header cell")
	_eq(G.get_text("points_label"), "Payout: {pts} points = +{e} Embers", "points_label cell")
	_eq(G.get_text("glossary_bounty"), "A combo card; claim every required one to clear the table.", "glossary bounty")
	_eq(G.get_text("goal_plate_line1"), "CLEAR {req} BOUNTIES", "goal_plate_line1 cell")
	_eq(G.get_text("goal_plate_line2"), "{left} more · {h} hands left", "goal_plate_line2 cell")
	_eq(G.get_text("goal_plate_last"), "Last bounty: {name} · {h} hands left", "goal_plate_last cell")
	_eq(G.get_text("hint_table_goal"), "Clear the table by claiming these bounties; points only turn into Embers.", "hint_table_goal")
	_eq(G.get_text("pot_preview_ticks"), "Ticks: {name}", "pot_preview_ticks cell")
	_eq(G.get_text("chit_pending_tag"), "bank to claim", "chit_pending_tag")
	_eq(G.get_text("nope"), "", "unknown id")
	# Filled.
	_eq(G.card_header(2, 3), "Clear the table: 2 more bounties · 3 hands left", "card_header")
	_eq(G.card_header(1, 3), "Clear the table: 1 more bounty · 3 hands left", "card_header 1 bounty")
	_eq(G.card_header(3, 1), "Clear the table: 3 more bounties · 1 hand left", "card_header 1 hand")
	_eq(G.card_header(0, 2), "Clear the table: 0 more bounties · 2 hands left", "card_header 0")
	_eq(G.points_label(572, 5), "Payout: 572 points = +5 Embers", "points_label")
	var t := BonfireTuning.new()
	_eq(G.points_label(750, BonfireRun.points_to_embers(t, 750)), "Payout: 750 points = +%d Embers" % BonfireRun.points_to_embers(t, 750), "points_label, capped payout")
	_eq(G.goal_plate_line1(3), "CLEAR 3 BOUNTIES", "plate line 1 (Floor 1: 3 required)")
	_eq(G.goal_plate_line1(1), "CLEAR 1 BOUNTY", "plate line 1, one")
	_eq(G.goal_plate_line2(2, 3), "2 more · 3 hands left", "plate line 2")
	_eq(G.goal_plate_line2(2, 1), "2 more · 1 hand left", "plate line 2, 1 hand")
	_eq(G.goal_plate_last("Full House", 3), "Last bounty: Full House · 3 hands left", "plate last")
	_eq(G.goal_plate_status(1, 1, "Trips"), "Last bounty: Trips · 1 hand left", "plate status at 1 left")
	_eq(G.goal_plate_status(3, 5, "Trips"), "3 more · 5 hands left", "plate status at 3 left")
	_eq(G.pot_preview_ticks("Trips"), "Ticks: Trips", "pot preview")
	for id in G.TEXT:
		var s: String = G.TEXT[id]
		for banned in ["chip", "handful", "tray", "burn", "ignit"]:
			_check(not s.to_lower().contains(banned), "%s: no '%s'" % [id, banned])
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
