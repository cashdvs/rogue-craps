## Rolls DieData resources using an injectable random number generator.
##
## Why injectable? Randomness makes tests flaky. By passing in a seed (or
## our own RandomNumberGenerator), the same seed always produces the same
## rolls, so tests are deterministic and runs could be replayed from a seed
## (a classic roguelite feature).
class_name DiceRoller
extends RefCounted

## The RNG used for every roll. Swap it out to control randomness.
var rng: RandomNumberGenerator


## seed_value: pass a number for repeatable rolls, or leave at -1 to
## randomize. rng_override: supply your own RNG (takes priority over seed).
func _init(seed_value: int = -1, rng_override: RandomNumberGenerator = null) -> void:
	if rng_override != null:
		rng = rng_override
	else:
		rng = RandomNumberGenerator.new()
		if seed_value >= 0:
			rng.seed = seed_value
		else:
			rng.randomize()


## Rolls one die: picks one of its faces uniformly at random.
## Returns null (and reports an error) if the die has no faces.
func roll_die(die: DieData) -> DieFace:
	if die == null or die.faces.is_empty():
		push_error("DiceRoller: cannot roll a die with no faces.")
		return null
	var index := rng.randi_range(0, die.faces.size() - 1)
	return die.faces[index]


## Rolls several dice and returns the face each one landed on, in order.
func roll_dice(dice: Array[DieData]) -> Array[DieFace]:
	var landed: Array[DieFace] = []
	for die in dice:
		landed.append(roll_die(die))
	return landed


## Helper: turns landed faces into plain numbers for CrapsRound.
## A missing (null) face counts as 0.
static func face_values(faces: Array[DieFace]) -> Array[int]:
	var values: Array[int] = []
	for face in faces:
		values.append(face.value if face != null else 0)
	return values
