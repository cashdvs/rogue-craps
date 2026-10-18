## One die as the Bonfire table throws it (run dice or the sandbox Bone):
## six faces, each with a value, a roll weight and an optional face mod.
## Physical face slot k (1..6) shows faces[k-1].
class_name TableDie
extends RefCounted

var id: StringName = &"bone"
var display_name: String = "Bone"
## Value on each face slot (slot k = faces[k-1]).
var faces: Array[int] = [1, 2, 3, 4, 5, 6]
## Roll weight per face slot (empty = uniform).
var weights: Array[float] = []
## Face mod per face slot (FaceModData or null), same length as faces.
var mods: Array = [null, null, null, null, null, null]


func _init(die_id: StringName = &"bone", name: String = "Bone") -> void:
	id = die_id
	display_name = name


## A face slot 1..6, weighted.
func roll_slot(rng: RandomNumberGenerator) -> int:
	if weights.size() == faces.size():
		var w := PackedFloat32Array(weights)
		return rng.rand_weighted(w) + 1
	return rng.randi_range(1, faces.size())


func value_at(slot: int) -> int:
	return faces[clampi(slot - 1, 0, faces.size() - 1)]


func mod_at(slot: int) -> FaceModData:
	var i := slot - 1
	return mods[i] if i >= 0 and i < mods.size() else null


## The first slot showing `value` (1..6), or -1.
func slot_for_value(value: int) -> int:
	var i := faces.find(value)
	return i + 1 if i >= 0 else -1


## A plain Bone die with face mods by id per face (RunDie.faces style:
## &"" = plain), looked up in `library` (e.g. RunData.face_mods).
static func from_mod_ids(mod_ids: Array, library: Array, die_id: StringName = &"bone", name: String = "Bone") -> TableDie:
	var d := TableDie.new(die_id, name)
	for i in mini(mod_ids.size(), 6):
		var want := StringName(mod_ids[i])
		if want == &"":
			continue
		for m in library:
			if m != null and (m as FaceModData).id == want:
				d.mods[i] = m
				break
	return d
