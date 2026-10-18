## Regenerates the sample .tres files in res://resources/.
##
## Run:  godot --headless --path . --script res://tools/generate_sample_resources.gd
##
## Why a script instead of hand-writing .tres? Godot's text format for nested
## typed arrays is fiddly; letting ResourceSaver write it guarantees the files
## are valid. After generating, edit them freely in the Godot inspector.
extends SceneTree


func _initialize() -> void:
	var ok := true

	# --- Dice ---------------------------------------------------------------
	var standard := DieData.make_standard_d6("Standard Die")
	standard.ability_description = "No ability. Honest as they come."
	ok = _save(standard, "res://resources/dice/standard_d6.tres") and ok

	# A second starter die showing off face effects + an ability id.
	var lucky := DieData.new()
	lucky.display_name = "Lucky Die"
	lucky.ability_id = &"lucky_reroll"
	lucky.ability_description = "Once per round, may reroll a craps loss. (Not implemented yet.)"
	for v in [1, 2, 3, 4, 5, 6]:
		var face := DieFace.make(v)
		if v == 6:
			face.effect_id = &"bonus_chips"
			face.tags = PackedStringArray(["gold"])
		lucky.faces.append(face)
	ok = _save(lucky, "res://resources/dice/lucky_d6.tres") and ok

	# --- Bets ---------------------------------------------------------------
	var pass_line := BetType.new()
	pass_line.id = &"pass_line"
	pass_line.display_name = "Pass Line"
	pass_line.payout = 1.0
	pass_line.unlock_cost = 0
	pass_line.description = "Wins on a come-out 7 or 11, or when the Point is hit. Loses on 2, 3, 12, or a seven-out."
	ok = _save(pass_line, "res://resources/bets/pass_line.tres") and ok

	var field := BetType.new()
	field.id = &"field"
	field.display_name = "Field"
	field.payout = 1.0
	field.unlock_cost = 50
	field.description = "One-roll bet: wins on 2, 3, 4, 9, 10, 11, 12. (Shop unlock; logic not implemented yet.)"
	ok = _save(field, "res://resources/bets/field.tres") and ok

	# --- Relics -------------------------------------------------------------
	var rabbit := RelicData.new()
	rabbit.id = &"rabbits_foot"
	rabbit.display_name = "Rabbit's Foot"
	rabbit.description = "The first seven-out each floor is ignored. (Logic not implemented yet.)"
	rabbit.hook_ids = [&"on_seven_out"] as Array[StringName]
	ok = _save(rabbit, "res://resources/relics/rabbits_foot.tres") and ok

	quit(0 if ok else 1)


func _save(res: Resource, path: String) -> bool:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s (error %d)" % [path, err])
		return false
	print("Saved ", path)
	return true
