## Bonfire rules state (pure; the 3D scene only shows it).
## A hand: throw the cold dice -> lit dice (scoring) catch fire -> pot at
## least one group -> BANK (pot to coin, hand over) or THROW the rest again.
## Nothing lit = BUST (hand pot lost, -Soul). Pot every die = HOT HAND (all
## dice come back, further scoring x hot_hand_multiplier).
class_name BonfireRun
extends RefCounted

enum State { AIM, PICK, CLEARED, FAILED, RUN_OVER }

signal hand_finished(result: Dictionary)

var tuning: BonfireTuning
var state: State = State.AIM
var coin: int = 0
var soul: int = 35
var hands_left: int = 0
## Points banked into this hand's pot by earlier throws (already multiplied).
var pot: int = 0
var multiplier: int = 1
## How many dice the next throw uses.
var cold: int = 5
var throw_faces: Array[int] = []
## Indices into throw_faces potted from this throw.
var potted: Array[int] = []
var last_result: Dictionary = {}


func _init(t: BonfireTuning) -> void:
	tuning = t
	soul = t.starting_soul
	coin = t.start_coin
	hands_left = t.hands
	_start_hand()


func _start_hand() -> void:
	pot = 0
	multiplier = 1
	cold = tuning.dice_count
	throw_faces.clear()
	potted.clear()
	state = State.AIM


## The faces of a throw of `cold` dice. Returns true if something lit.
func set_throw(faces: Array[int]) -> bool:
	throw_faces = faces.duplicate()
	potted.clear()
	if lit().is_empty():
		_finish({"kind": &"bust", "lost_pot": pot, "soul_lost": tuning.bust_soul_loss})
		return false
	state = State.PICK
	return true


func lit() -> Array[int]:
	return BonfireScoring.lit_indices(throw_faces, tuning)


func group_of(i: int) -> Array[int]:
	for g in BonfireScoring.groups(throw_faces, tuning):
		if (g as Array).has(i):
			return g as Array[int]
	return []


func selection_faces(sel: Array[int] = potted) -> Array:
	var f: Array = []
	for i in sel:
		f.append(throw_faces[i])
	return f


## Pots / unpots the whole group die `i` belongs to. Refused (false) if the
## die is cold or the selection would stop being valid.
func toggle(i: int) -> bool:
	if state != State.PICK:
		return false
	var g := group_of(i)
	if g.is_empty():
		return false
	var next := potted.duplicate()
	var all_in := true
	for k in g:
		all_in = all_in and next.has(k)
	if all_in:
		for k in g:
			next.erase(k)
	else:
		for k in g:
			if not next.has(k):
				next.append(k)
	if not next.is_empty() and not BonfireScoring.score_selection(selection_faces(next), tuning)["valid"]:
		return false
	potted = next
	return true


func throw_points() -> int:
	if potted.is_empty():
		return 0
	var s := BonfireScoring.score_selection(selection_faces(), tuning)
	return int(s["points"]) * multiplier if s["valid"] else 0


func hand_pot() -> int:
	return pot + throw_points()


func can_continue() -> bool:
	return state == State.PICK and throw_points() > 0


func is_hot() -> bool:
	return can_continue() and potted.size() == throw_faces.size()


## Pot this throw's dice and throw the rest. Returns {} if not allowed,
## else {"hot": bool, "cold": n}.
func rethrow() -> Dictionary:
	if not can_continue():
		return {}
	var hot := is_hot()
	pot += throw_points()
	cold -= potted.size()
	if hot or cold <= 0:
		hot = true
		cold = tuning.dice_count
		multiplier = tuning.hot_hand_multiplier
	throw_faces.clear()
	potted.clear()
	state = State.AIM
	return {"hot": hot, "cold": cold}


## Bank the hand's pot into coin. Returns the result ({} if not allowed).
func bank() -> Dictionary:
	if not can_continue():
		return {}
	var gain := hand_pot()
	coin += gain
	return _finish({"kind": &"bank", "gain": gain})


func _finish(r: Dictionary) -> Dictionary:
	if r["kind"] == &"bust":
		soul = maxi(soul - int(r["soul_lost"]), 0)
	hands_left -= 1
	if soul <= 0:
		state = State.RUN_OVER
	elif coin >= tuning.coin_target:
		state = State.CLEARED
	elif hands_left <= 0:
		state = State.FAILED
	else:
		_start_hand()
	r["state"] = state
	r["coin"] = coin
	r["soul"] = soul
	last_result = r
	hand_finished.emit(r)
	return r


func is_over() -> bool:
	return state == State.CLEARED or state == State.FAILED or state == State.RUN_OVER
