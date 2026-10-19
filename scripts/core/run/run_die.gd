## One die in the player's handful for this run: an optional special-die id
## and one face-mod id per face (&"" = plain face, &"blank" = never lights).
## RunProgress.table_dice() turns these into Bonfire TableDie (values from
## the special die's faces, per-face FaceModData).
class_name RunDie
extends RefCounted

const BLANK: StringName = &"blank"

## Unique within the run (e.g. &"cracked_6"), set by RunProgress; how the
## table names this die back (TableOutcome.shattered_dice).
var id: StringName = &""
## &"" = a plain Bone die, else e.g. &"coven" (build content: special dice).
var special_id: StringName = &""
## One face-mod id per face; sized to the shape's face count (d6: 6).
var faces: Array[StringName] = [&"", &"", &"", &"", &"", &""]
## Die shape id (DieShape.id): &"d6", &"powder_keg", &"coin" (Ferryman's Coin), ...
## Special dice are d6.
var shape: StringName = &"d6"


func _init(special: StringName = &"", shape_id: StringName = &"d6", face_count: int = 6) -> void:
	shape = shape_id
	faces.resize(face_count)
	faces.fill(&"")
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
