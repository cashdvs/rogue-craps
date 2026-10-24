## Table-goal text: bounties are the goal, points are only the Ember payout
## (design/starting_dice_options_v1.md section 5, PM-approved Oct 23, 2026).
## TEXT holds the strings_v1 cells verbatim, keyed by their strings_v1 id,
## with {placeholders}; the helpers fill them (plural "bounty/bounties" and
## "hand(s)"). The table HUD, goal plate and hint panel (Godot Dev's) call
## these. Example: GoalStrings.card_header(2, 3)
##   -> "Clear the table: 2 more bounties · 3 hands left"
class_name GoalStrings
extends RefCounted

## strings_v1 id -> text (copied verbatim; check_strings.py owns the source).
const TEXT: Dictionary[String, String] = {
	"card_header": "Clear the table: {left} more bounty/bounties · {h} hands left",
	"points_label": "Payout: {pts} points = +{e} Embers",
	"glossary_bounty": "A combo card; claim every required one to clear the table.",
	"goal_plate_line1": "CLEAR {req} BOUNTIES",
	"goal_plate_line2": "{left} more · {h} hands left",
	"goal_plate_last": "Last bounty: {name} · {h} hands left",
	"hint_table_goal": "Clear the table by claiming these bounties; points only turn into Embers.",
	"pot_preview_ticks": "Ticks: {name}",
	"chit_pending_tag": "bank to claim",
}


## The raw text for strings_v1 id [param id] ("" if unknown).
static func get_text(id: String) -> String:
	return TEXT.get(id, "")


## card_header: "Clear the table: 1 more bounty · 1 hand left" (singular at 1).
static func card_header(left: int, hands_left: int) -> String:
	return _hands(get_text("card_header").replace("bounty/bounties", _plural(left, "bounty", "bounties")), hands_left).format({"left": left, "h": hands_left})


## points_label: "Payout: 572 points = +5 Embers" (`embers` already capped).
static func points_label(points: int, embers: int) -> String:
	return get_text("points_label").format({"pts": points, "e": embers})


## goal_plate_line1: "CLEAR 3 BOUNTIES" (required count; "BOUNTY" at 1).
static func goal_plate_line1(required: int) -> String:
	return get_text("goal_plate_line1").replace("BOUNTIES", _plural(required, "BOUNTY", "BOUNTIES")).format({"req": required})


## goal_plate_line2: "2 more · 3 hands left" (while 2+ required are left).
static func goal_plate_line2(left: int, hands_left: int) -> String:
	return _hands(get_text("goal_plate_line2"), hands_left).format({"left": left, "h": hands_left})


## goal_plate_last: "Last bounty: Full House · 3 hands left" (one left).
static func goal_plate_last(bounty_name: String, hands_left: int) -> String:
	return _hands(get_text("goal_plate_last"), hands_left).format({"name": bounty_name, "h": hands_left})


## The plate's line 2: goal_plate_last when exactly one required bounty is
## left (`last_name` = its name), else goal_plate_line2.
static func goal_plate_status(left: int, hands_left: int, last_name: String) -> String:
	return goal_plate_last(last_name, hands_left) if left == 1 else goal_plate_line2(left, hands_left)


## pot_preview_ticks: "Ticks: Trips" (the bounty this pot would tick).
static func pot_preview_ticks(bounty_name: String) -> String:
	return get_text("pot_preview_ticks").format({"name": bounty_name})


static func _hands(s: String, h: int) -> String:
	return s.replace("{h} hands", "{h} hand") if h == 1 else s


static func _plural(n: int, one: String, many: String) -> String:
	return one if n == 1 else many
