## One die in the player's handful for this run: an optional special-die id
## and one face-mod id per face (&"" = plain face, &"blank" = never lights).
## Bonfire's table still throws plain d6s; these are carried for when face
## mods and special dice get rules (build content v0.3).
class_name RunDie
extends RefCounted

const BLANK: StringName = &"blank"

## &"" = a plain Bone die, else e.g. &"coven" (build content: special dice).
var special_id: StringName = &""
var faces: Array[StringName] = [&"", &"", &"", &"", &"", &""]


func _init(special: StringName = &"") -> void:
	special_id = special


func free_faces() -> Array[int]:
	var out: Array[int] = []
	for i in faces.size():
		if faces[i] == &"":
			out.append(i)
	return out


func modded_faces() -> Array[int]:
	var out: Array[int] = []
	for i in faces.size():
		if faces[i] != &"":
			out.append(i)
	return out
