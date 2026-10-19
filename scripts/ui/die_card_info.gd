## What a die card shows (DieCard): the die's name, its ability line, shape,
## every face (value, mod id, mod name) and, in pick mode, the next mod's
## price. Plain data: from_run() fills one from the run's bag; the table
## (Godot Dev) fills one from a TableDie.
class_name DieCardInfo
extends RefCounted

## strings_v1 bag_bone_line: the ability line of a plain die.
const BONE_LINE := "Bone die: plain faces 1 to 6."

var display_name: String = ""
var ability: String = ""
var shape: StringName = &"d6"
## One per face: {value: int, mod: StringName (&"" = plain), mod_name: String}.
var faces: Array[Dictionary] = []
## Pick mode: the next face mod's price on this die; -1 = don't show it.
var next_mod_price: int = -1


## Card info for die `die_index` in `progress`'s bag: its name, ability
## (special die description, or BONE_LINE), shape and faces with mod names.
static func from_run(progress: RunProgress, die_index: int) -> DieCardInfo:
	var info := DieCardInfo.new()
	var def := progress.die_def(die_index)
	var die := progress.dice[die_index]
	info.display_name = progress.die_name(die_index)
	info.ability = def.description if def != null else BONE_LINE
	info.shape = die.shape
	for f in die.faces.size():
		var mod: StringName = die.faces[f]
		var value: int = def.faces[f] if def != null and f < def.faces.size() else f + 1
		info.faces.append({"value": value, "mod": mod, "mod_name": mod_name(progress, mod)})
	return info


## A face mod's short display name ("Wild", "Blank"); the id capitalized if
## the run doesn't know it.
static func mod_name(progress: RunProgress, mod: StringName) -> String:
	if mod == RunDie.BLANK:
		return "Blank"
	for m in progress.data.face_mods:
		if m.id == mod:
			return m.display_name.trim_suffix(" Face")
	return String(mod).capitalize()
