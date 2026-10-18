## The Dealer's taunts: event id -> list of lines, loaded from a JSON file
## so writers can edit them without touching code.
##
## pick(event) returns a random line for that event, never the same line
## twice in a row (per event). Uses its own seeded RNG for repeatable tests.
class_name DealerLines
extends RefCounted

## Every event the table can fire. The test checks each one has lines.
const EVENTS: Array[StringName] = [
	&"natural", &"craps", &"point_set", &"point_hit", &"seven_out",
	&"big_bet", &"low_soul", &"table_win", &"table_fail",
]

var lines: Dictionary[StringName, PackedStringArray] = {}
var rng := RandomNumberGenerator.new()
var _last: Dictionary[StringName, int] = {}


## Loads lines from a JSON file like res://resources/dealer/dealer_lines.json.
## Keys starting with "_" (comments) are ignored. Returns null on error.
static func from_json_file(path: String, seed_value: int = DiceRoller.RANDOM_SEED) -> DealerLines:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("DealerLines: could not read %s" % path)
		return null
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		push_error("DealerLines: %s is not a JSON object." % path)
		return null
	var out := DealerLines.new()
	if seed_value == DiceRoller.RANDOM_SEED:
		out.rng.randomize()
	else:
		out.rng.seed = seed_value
	for key: String in (data as Dictionary).keys():
		if key.begins_with("_"):
			continue
		var list := PackedStringArray()
		var raw: Variant = data[key]
		if raw is Array:
			for item: Variant in raw:
				list.append(str(item))
		out.lines[StringName(key)] = list
	return out


func has_event(event: StringName) -> bool:
	return lines.has(event) and not lines[event].is_empty()


## A random line for the event ("" if there are none).
func pick(event: StringName) -> String:
	if not has_event(event):
		return ""
	var list := lines[event]
	if list.size() == 1:
		return list[0]
	var last: int = _last.get(event, -1)
	var index := rng.randi_range(0, list.size() - 2)
	if index >= last and last >= 0:
		index += 1  # Skip over the previous line without biasing the rest.
	_last[event] = index
	return list[index]
