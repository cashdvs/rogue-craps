## One die as the Bonfire table throws it (run dice or the sandbox Bone):
## a shape (d6 by default; coin, d3, d4, d8, d10, d12, d20 for the
## nonstandard dice in design/nonstandard_dice.md) and one value, roll weight
## and optional face mod per face.
## Face slot k (1..face_count()) shows faces[k-1]. For a d6 that is also the
## physical face of the mesh; other shapes map their mesh faces onto these
## slots in the table (e.g. a d3 is a d6 mesh printed 1-1-2-2-3-3, and a coin
## is slot 1 = heads, slot 2 = tails).
class_name TableDie
extends RefCounted

## Every shape the table knows, with its face count: DiceIds.SHAPES (#107).
## talus = the Knucklebone's astragalus: 4 resting faces (1, 3, 4, 6), not a
## d4. The Powder Keg is a d6 printed [1, 1, 2, 2, 3, 3] (never a d3 body).
const SHAPE_FACES := DiceIds.SHAPES

var id: StringName = &"bone"
var display_name: String = "Bone"
## Die shape id (one of SHAPE_FACES; RunDie.shape). Assigning it (e.g. the
## run's `td.set("shape", ...)` after copying its faces in) validates it and
## sizes faces / weights / mods to the shape, keeping the values already
## there. Use set_shape() to reset faces to the shape's defaults instead.
var shape: StringName = &"d6":
	set(value):
		_shape = value
		normalize()
	get:
		return _shape
var _shape: StringName = &"d6"
## Value on each face slot (slot k = faces[k-1]).
var faces: Array[int] = [1, 2, 3, 4, 5, 6]
## Roll weight per face slot (empty = uniform).
var weights: Array[float] = []
## Face mod per face slot (FaceModData or null), same length as faces.
var mods: Array = [null, null, null, null, null, null]
## Special die kind (RunDie.special_id: &"mirror", &"cracked", ...; &"" =
## a plain die). Scoring specials live in BonfireScoring, table-side ones in
## TableRules.DIE_SCRIPTS.
var special: StringName = &""
## Unique per run die (e.g. &"cracked_5"; set by the run). `id` stays the
## die type. TableOutcome.shattered_dice lists this (id if empty).
var run_die_id: StringName = &""


## The id the run knows this die by: run_die_id, else id.
func key() -> StringName:
	return run_die_id if run_die_id != &"" else id


func _init(die_id: StringName = &"bone", name: String = "Bone", shape_id: StringName = &"d6") -> void:
	id = die_id
	display_name = name
	if shape_id != &"d6":
		set_shape(shape_id)


## True for a shape id the table can throw.
static func is_valid_shape(shape_id: StringName) -> bool:
	return SHAPE_FACES.has(shape_id)


## Faces on a shape (6 for an unknown id, which plays as a d6).
static func faces_for_shape(shape_id: StringName) -> int:
	return SHAPE_FACES.get(shape_id, 6)


## Default printed values for a shape (PR #50 convention): coin [1, 5],
## d3 [1, 2, 3], dN 1..N.
static func default_values(shape_id: StringName) -> Array[int]:
	var out: Array[int] = []
	if shape_id == &"coin":
		out.assign([1, 5])
		return out
	if shape_id == &"talus":
		# The classical astragalus values (opposite faces sum to 7).
		out.assign([1, 3, 4, 6])
		return out
	for v in faces_for_shape(shape_id):
		out.append(v + 1)
	return out


## Number of face slots on this die.
func face_count() -> int:
	return faces.size()


## Switches the die to `shape_id` and resets faces to that shape's default
## values (no weights, no mods). An unknown id warns and falls back to d6,
## so a typo can never leave the table with a broken die.
func set_shape(shape_id: StringName) -> void:
	if not is_valid_shape(shape_id):
		push_warning("TableDie: unknown shape '%s', using d6" % shape_id)
		shape_id = &"d6"
	_shape = shape_id
	faces = default_values(shape_id)
	weights = []
	mods = []
	mods.resize(faces.size())


## Makes faces / weights / mods agree with the shape's face count after
## someone assigned them directly (e.g. the run copies its own arrays in):
## short arrays are padded (default value, no mod), long ones trimmed, and
## weights that don't match become uniform. An unknown shape becomes d6.
func normalize() -> void:
	if not is_valid_shape(_shape):
		push_warning("TableDie: unknown shape '%s', using d6" % _shape)
		_shape = &"d6"
	var n := faces_for_shape(_shape)
	if faces.size() != n or mods.size() != n:
		push_warning("TableDie %s: %d faces / %d mods for shape %s (%d); padding / trimming" % [id, faces.size(), mods.size(), _shape, n])
	if faces.size() != n:
		var defaults := default_values(shape)
		var old := faces.duplicate()
		faces = defaults
		for i in mini(old.size(), n):
			faces[i] = old[i]
	if not weights.is_empty() and weights.size() != n:
		weights = []
	mods.resize(n)


## A face slot 1..face_count(), weighted.
func roll_slot(rng: RandomNumberGenerator) -> int:
	if weights.size() == faces.size():
		var w := PackedFloat32Array(weights)
		return rng.rand_weighted(w) + 1
	return rng.randi_range(1, faces.size())


## Value on face slot `slot` (clamped to the faces there are; an empty face
## list, a data mismatch, reads as the slot number).
func value_at(slot: int) -> int:
	if faces.is_empty():
		return slot
	return faces[clampi(slot - 1, 0, faces.size() - 1)]


func mod_at(slot: int) -> FaceModData:
	var i := slot - 1
	return mods[i] if i >= 0 and i < mods.size() else null


## The first slot showing `value` (1..face_count()), or -1.
func slot_for_value(value: int) -> int:
	var i := faces.find(value)
	return i + 1 if i >= 0 else -1


## A plain die with face mods by id per face (RunDie.faces style: &"" =
## plain), looked up in `library` (e.g. RunData.face_mods). `shape_id` sizes
## faces / mods (default d6; unknown ids fall back to d6). Extra mod ids past
## the shape's face count are ignored.
static func from_mod_ids(mod_ids: Array, library: Array, die_id: StringName = &"bone", name: String = "Bone",
		special_id: StringName = &"", shape_id: StringName = &"d6") -> TableDie:
	var d := TableDie.new(die_id, name, shape_id)
	d.special = special_id
	for i in mini(mod_ids.size(), d.face_count()):
		var want := StringName(mod_ids[i])
		if want == &"":
			continue
		for m in library:
			if m != null and (m as FaceModData).id == want:
				d.mods[i] = m
				break
	return d
