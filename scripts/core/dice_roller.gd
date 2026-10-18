## Rolls DieData resources using an injectable random number generator.
##
## Why injectable? Randomness makes tests flaky. By passing in a seed (or
## our own RandomNumberGenerator), the same seed always produces the same
## rolls, so tests are deterministic and runs could be replayed from a seed
## (a classic roguelite feature).
class_name DiceRoller
extends RefCounted

## Pass this as the seed to get a random (non-repeatable) roller.
## ONLY -1 means random: every other number, including other negatives
## like -5, is a real, repeatable seed.
const RANDOM_SEED: int = -1

## The RNG used for every roll. Swap it out to control randomness.
var rng: RandomNumberGenerator


## seed_value: any number for repeatable rolls, or RANDOM_SEED (-1) to
## randomize. rng_override: supply your own RNG (takes priority over seed).
func _init(seed_value: int = RANDOM_SEED, rng_override: RandomNumberGenerator = null) -> void:
	if rng_override != null:
		rng = rng_override
	else:
		rng = RandomNumberGenerator.new()
		if seed_value == RANDOM_SEED:
			rng.randomize()
		else:
			rng.seed = seed_value


## Rolls one die: picks one of its faces uniformly at random.
## A die with no faces (or a null face) is a data bug: we report it with
## push_error and return null. We never quietly pretend it rolled a 0.
func roll_die(die: DieData) -> DieFace:
	if die == null:
		push_error("DiceRoller: tried to roll a null die.")
		return null
	if not die.is_valid():
		push_error("DiceRoller: die '%s' has no faces (or a null face) and cannot be rolled." % die.display_name)
		return null
	var index := rng.randi_range(0, die.faces.size() - 1)
	return die.faces[index]


## Rolls several dice and returns the face each one landed on, in order.
## If ANY die can't be rolled, the whole roll fails and an EMPTY array is
## returned, so callers can't accidentally score a partial roll.
func roll_dice(dice: Array[DieData]) -> Array[DieFace]:
	var landed: Array[DieFace] = []
	for die in dice:
		var face := roll_die(die)
		if face == null:
			landed.clear()
			return landed
		landed.append(face)
	return landed


## Helper: turns landed faces into plain numbers for CrapsRound.
## A null face is a bug upstream; it is reported and the result is EMPTY
## (which CrapsRound rejects) instead of silently counting as 0.
static func face_values(faces: Array[DieFace]) -> Array[int]:
	var values: Array[int] = []
	for face in faces:
		if face == null:
			push_error("DiceRoller.face_values: got a null face; returning no values.")
			values.clear()
			return values
		values.append(face.value)
	return values
