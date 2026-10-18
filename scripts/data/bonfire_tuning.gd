## Every Bonfire number (scoring placeholders until the Game Designer's table
## arrives; swapping them is data-only: edit resources/tuning/bonfire_tuning.tres).
class_name BonfireTuning
extends Resource

@export_group("Run")
@export var starting_soul: int = 35
@export var hands: int = 8
@export var start_coin: int = 0
@export var coin_target: int = 300
@export var dice_count: int = 5
@export var bust_soul_loss: int = 2
## Scoring multiplier after a Hot Hand (every die potted, all scooped back).
@export var hot_hand_multiplier: int = 2

@export_group("Scoring")
## Points for a single 1 / single 5 that isn't part of a set.
@export var single_one: int = 10
@export var single_five: int = 5
## Three of a kind = face x triple_per_face (three 1s use triple_ones).
@export var triple_per_face: int = 10
@export var triple_ones: int = 100
## Multiplier on the triple's score for 3, 4, 5 (, 6) of a kind.
@export var of_a_kind_multiplier: Array[int] = [1, 2, 3, 4]
## Runs: 1-2-3-4-5 and 2-3-4-5-6 (exactly those five dice).
@export var run_low: int = 50
@export var run_high: int = 75


func triple_value(face: int) -> int:
	return triple_ones if face == 1 else face * triple_per_face


func kind_value(face: int, count: int) -> int:
	if count < 3:
		return 0
	var i := clampi(count - 3, 0, of_a_kind_multiplier.size() - 1)
	return triple_value(face) * of_a_kind_multiplier[i]
