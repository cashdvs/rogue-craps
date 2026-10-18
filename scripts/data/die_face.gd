## One face of a die.
##
## A face is its own Resource (not just an int) so that, later, a run can
## modify individual faces: e.g. turn a 1 into a "Loaded 6", or attach an
## effect like "gain 2 chips when rolled". The craps rules only care about
## [member value]; everything else is optional flavor/effects for later.
class_name DieFace
extends Resource

## The number this face contributes to the dice total (usually 1-6).
@export var value: int = 1

## Optional effect identifier, e.g. "bonus_chips" or "reroll". Empty = none.
## Effects are looked up by id elsewhere so this data file stays simple.
@export var effect_id: StringName = &""

## Free-form tags for systems to query, e.g. ["loaded", "gold"].
@export var tags: PackedStringArray = PackedStringArray()


## Convenience constructor used by code (e.g. tests, generators).
## Usage: DieFace.make(6, &"bonus_chips")
static func make(face_value: int, face_effect_id: StringName = &"") -> DieFace:
	var face := DieFace.new()
	face.value = face_value
	face.effect_id = face_effect_id
	return face


func has_effect() -> bool:
	return effect_id != &""


func _to_string() -> String:
	return "DieFace(%d%s)" % [value, "" if not has_effect() else ", " + String(effect_id)]
