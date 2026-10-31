## Table-goal text: bounties are the goal, points are only the Ember payout
## (design/starting_dice_options_v1.md section 5, PM-approved Oct 23, 2026).
## TEXT holds the strings_v1 cells verbatim, keyed by their strings_v1 id,
## with {placeholders}; the helpers fill them and pick the strings_v1
## singular ids (*_one, *_one_hand) at 1. The table HUD, goal plate and hint panel (Godot Dev's) call
## these. Example: GoalStrings.goal_plate_status(2, 3, "Trips")
##   -> "2 more · 3 hands left"
class_name GoalStrings
extends RefCounted

## strings_v1 id -> text (copied verbatim; check_strings.py owns the source).
const TEXT: Dictionary[String, String] = {
	"glossary_bounty": "A combo card; claim every required one to clear the table.",
	"goal_plate_line1": "CLEAR {req} BOUNTIES",
	"goal_plate_line1_one": "CLEAR 1 BOUNTY",
	"goal_plate_line2": "{left} more · {h} hands left",
	"goal_plate_line2_one_hand": "{left} more · 1 hand left",
	"goal_plate_last": "Last bounty: {name} · {h} hands left",
	"goal_plate_last_one_hand": "Last bounty: {name} · 1 hand left",
	"hint_table_goal": "Clear the table by claiming these bounties; points only turn into Embers.",
	"pot_preview_ticks": "Ticks: {name}",
	"chit_pending_tag": "bank to claim",
}


## The raw text for strings_v1 id [param id] ("" if unknown).
static func get_text(id: String) -> String:
	return TEXT.get(id, "")


## goal_plate_line1: "CLEAR 3 BOUNTIES" (required count; "BOUNTY" at 1).
static func goal_plate_line1(required: int) -> String:
	return get_text("goal_plate_line1_one") if required == 1 else get_text("goal_plate_line1").format({"req": required})


## goal_plate_line2: "2 more · 3 hands left" (while 2+ required are left).
static func goal_plate_line2(left: int, hands_left: int) -> String:
	return get_text(_hand_id("goal_plate_line2", hands_left)).format({"left": left, "h": hands_left})


## goal_plate_last: "Last bounty: Full House · 3 hands left" (one left).
static func goal_plate_last(bounty_name: String, hands_left: int) -> String:
	return get_text(_hand_id("goal_plate_last", hands_left)).format({"name": bounty_name, "h": hands_left})


## The plate's line 2: goal_plate_last when exactly one required bounty is
## left (`last_name` = its name), else goal_plate_line2. At 0 left (table
## cleared) it stays goal_plate_line2, "0 more · {h} hands left", so the
## plate never goes blank in the frame before the end screen.
static func goal_plate_status(left: int, hands_left: int, last_name: String) -> String:
	return goal_plate_last(last_name, hands_left) if left == 1 else goal_plate_line2(left, hands_left)


## pot_preview_ticks: "Ticks: Trips" (the bounty this pot would tick).
static func pot_preview_ticks(bounty_name: String) -> String:
	return get_text("pot_preview_ticks").format({"name": bounty_name})


static func _hand_id(id: String, hands_left: int) -> String:
	return id + "_one_hand" if hands_left == 1 else id
