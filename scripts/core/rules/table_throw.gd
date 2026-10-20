## One landed throw, handed to table rules / special dice before lighting
## (TableRule.on_throw_landed). Rules may change faces with set_value(); the
## changes are listed so the table can show them (flip + tint).
class_name TableThrow
extends RefCounted

## Value per die of this throw.
var values: Array[int] = []
## FaceModData or null per die.
var mods: Array = []
## Physical face slot (1..6) per die, or 0 if unknown (pure tests).
var slots: Array[int] = []
## TableDie per die (null = plain Bone).
var dice: Array = []
## Settled position per die (empty in pure tests).
var positions: Array[Vector3] = []
var rng: RandomNumberGenerator
## [{index, from, to, slot, by (rule id)}], in order.
var changes: Array[Dictionary] = []


static func make(faces: Array[int], face_mods: Array = [], table_dice: Array = [], rng_in: RandomNumberGenerator = null) -> TableThrow:
	var th := TableThrow.new()
	th.values = faces.duplicate()
	th.mods = face_mods.duplicate()
	th.mods.resize(faces.size())
	th.dice = table_dice.duplicate()
	th.dice.resize(faces.size())
	th.slots.resize(faces.size())
	for i in faces.size():
		var td: TableDie = th.dice[i]
		th.slots[i] = td.slot_for_value(faces[i]) if td != null else clampi(faces[i], 1, 6)
	th.rng = rng_in if rng_in != null else RandomNumberGenerator.new()
	return th


func size() -> int:
	return values.size()


func die(i: int) -> TableDie:
	return dice[i] if i < dice.size() else null


func special(i: int) -> StringName:
	var td := die(i)
	return td.special if td != null else &""


## Shows face `slot` on die i (value and mod from its TableDie; a plain
## Bone die shows slot = value).
func set_slot(i: int, slot: int, by: StringName) -> void:
	var td := die(i)
	var from := values[i]
	slots[i] = slot
	values[i] = td.value_at(slot) if td != null else slot
	mods[i] = td.mod_at(slot) if td != null else null
	changes.append({"index": i, "from": from, "to": values[i], "slot": slot, "by": by})


## Shows `value` on die i (the first slot carrying it).
func set_value(i: int, value: int, by: StringName) -> void:
	var td := die(i)
	var slot := td.slot_for_value(value) if td != null else value
	if slot <= 0:
		slot = clampi(value, 1, 6)
	set_slot(i, slot, by)
	values[i] = value


## Die i now counts as `value` but keeps the face it landed on (slot and
## that face's mod): a copy that is a natural face (Ferryman's Coin).
func copy_value(i: int, value: int, by: StringName) -> void:
	var from := values[i]
	values[i] = value
	changes.append({"index": i, "from": from, "to": value, "slot": slots[i] if i < slots.size() else 0, "by": by})


## Die i's face now has mod `m` (e.g. a lone Tails turns Blank).
func set_mod(i: int, m: FaceModData, by: StringName) -> void:
	mods[i] = m
	changes.append({"index": i, "from": values[i], "to": values[i], "slot": slots[i] if i < slots.size() else 0, "by": by, "mod": m})


## Rerolls die i with its own face weights.
func reroll(i: int, by: StringName) -> void:
	var td := die(i)
	set_slot(i, td.roll_slot(rng) if td != null else rng.randi_range(1, 6), by)
