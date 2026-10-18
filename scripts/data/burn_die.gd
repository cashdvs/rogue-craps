## One die you can throw in Burn Line (Game Designer numbers live in
## resources/tuning/burn_line_tuning.tres). The die has 6 physical face slots
## (DieVisual.FACE_AXES order 1..6); `faces[i]` is what slot i+1 shows and
## adds to the total, and `weights[i]` how likely that slot lands on top.
class_name BurnDie
extends Resource

@export var id: StringName = &"bone"
@export var display_name: String = "Bone"
## Short rules text for the pick screen and the die button.
@export_multiline var perk_text: String = ""
## What each of the 6 face slots shows (and adds to the running total).
@export var faces: PackedInt32Array = PackedInt32Array([1, 2, 3, 4, 5, 6])
## Relative chance of each face slot (empty or all equal = fair).
@export var weights: PackedFloat32Array = PackedFloat32Array()
## Throws allowed per hand (0 = unlimited). Knucklebone "Cramped" = 1.
@export var max_throws_per_hand: int = 0
## Return multiplier for an exact hit when THIS die was the last throw
## (0 = use the table's exact return). Leadfoot = 2.5.
@export var exact_return_override: float = 0.0
## Extra Soul lost when a throw of THIS die burns (Leadfoot "Heavy" = 2).
@export var burn_soul_extra: int = 0
@export var body_color: Color = Color("#E8DCC0")
@export var pip_color: Color = Color("#0E1414")


## The 6 face labels as a typed array (for DieVisual.set_look).
func labels() -> Array[int]:
	var out: Array[int] = []
	for v in faces:
		out.append(v)
	return out


## Seeded pick of a face SLOT (1..6) using `weights`.
func roll_slot(rng: RandomNumberGenerator) -> int:
	if weights.size() != faces.size():
		return rng.randi_range(1, faces.size())
	return rng.rand_weighted(weights) + 1


## The face values with their chances, e.g. for the die button: "1 2 3 4 5 6(x3)".
func faces_text() -> String:
	var parts: PackedStringArray = []
	for i in faces.size():
		var w := weights[i] if weights.size() == faces.size() else 1.0
		var min_w := 1.0
		if weights.size() == faces.size():
			min_w = Array(weights).min()
		parts.append(str(faces[i]) + ("(x%d)" % int(round(w / min_w)) if w > min_w + 0.001 else ""))
	return " ".join(parts)
