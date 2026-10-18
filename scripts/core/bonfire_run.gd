## Bonfire rules state (pure; the 3D scene only shows it).
## A hand: throw the cold dice -> dice that can form a combo light -> pot
## ONE combo (exact match) -> BANK or THROW the rest again. Nothing lit =
## BUST (hand pot and pending bounty ticks lost, -Soul). All 5 potted in the
## hand = HOT HAND: all dice back, +1 mult on every later pot this hand.
## Table goal (TableGoal): bank every required bounty within the hands.
class_name BonfireRun
extends RefCounted

enum State { AIM, PICK, CLEARED, FAILED, RUN_OVER }

signal hand_finished(result: Dictionary)

var tuning: BonfireTuning
var goal: TableGoal
var state: State = State.AIM
var soul: int = 35
var hands_left: int = 0
## Points banked this table (turn into Embers at table end).
var points: int = 0
var embers: int = 0
## This hand's pot from earlier throws.
var pot: int = 0
## Hot Hands this hand (each adds tuning.hot_hand_mult_bonus to the mult).
var hot_hands: int = 0
var cold: int = 5
var throw_faces: Array[int] = []
## Per die of this throw: that face's mod (FaceModData or null).
var throw_mods: Array = []
## Dice in a full handful (Hot Hand = all of them potted in one hand).
var dice_count: int = 5
var potted: Array[int] = []
## Bounty id -> times banked / pending this hand.
var ticks: Dictionary = {}
var pending: Dictionary = {}
var last_result: Dictionary = {}
var forfeited: bool = false
## Filled when the table ends: {"points_embers", "clear_embers", "soul_lost", ...}.
var table_summary: Dictionary = {}


## soul_override / dice_override: -1 = tuning.starting_soul / tuning.dice_count.
func _init(t: BonfireTuning, g: TableGoal = null, soul_override: int = -1, dice_override: int = -1) -> void:
	tuning = t
	goal = g if g != null else t.table_goal
	soul = t.starting_soul if soul_override < 0 else soul_override
	dice_count = t.dice_count if dice_override <= 0 else dice_override
	hands_left = goal.hands
	_start_hand()


func _start_hand() -> void:
	pot = 0
	hot_hands = 0
	cold = dice_count
	throw_faces.clear()
	throw_mods.clear()
	potted.clear()
	pending.clear()
	state = State.AIM


func mult_bonus() -> int:
	return hot_hands * tuning.hot_hand_mult_bonus


func all_bounties() -> Array:
	return goal.required + goal.bonus


## The faces of a throw of `cold` dice (and each face's mod, FaceModData or
## null; omit for plain dice). Returns true if something lit.
func set_throw(faces: Array[int], mods: Array = []) -> bool:
	throw_faces = faces.duplicate()
	throw_mods = mods.duplicate()
	throw_mods.resize(faces.size())
	potted.clear()
	if lit().is_empty():
		_bust()
		return false
	if not tuning.bounty_requires_pot:
		_add_pending(BonfireScoring.plain_values(throw_dice()))
	state = State.PICK
	return true


func lit() -> Array[int]:
	return BonfireScoring.lit_indices(throw_dice(), tuning)


## This throw as scoring dice ({value, mod}).
func throw_dice() -> Array:
	var out: Array = []
	for i in throw_faces.size():
		out.append(BonfireScoring.make_die(throw_faces[i], throw_mods[i] if i < throw_mods.size() else null))
	return out


## The selected dice as scoring dice ({value, mod}).
func selection_faces(sel: Array[int] = potted) -> Array:
	var all := throw_dice()
	var f: Array = []
	for i in sel:
		f.append(all[i])
	return f


## Pots / unpots die i. Refused (false) if it couldn't be part of a combo
## with the dice already potted from this throw.
func toggle(i: int) -> bool:
	if state != State.PICK or i < 0 or i >= throw_faces.size():
		return false
	if potted.has(i):
		potted.erase(i)
		return true
	var next := potted.duplicate()
	next.append(i)
	if not BonfireScoring.can_extend(next, throw_dice(), tuning):
		return false
	potted = next
	return true


func selection() -> Dictionary:
	return BonfireScoring.score_selection(selection_faces(), tuning, mult_bonus())


func throw_points() -> int:
	return int(selection()["points"])


func hand_pot() -> int:
	return pot + throw_points()


func can_continue() -> bool:
	return state == State.PICK and selection()["valid"]


## Would potting the current selection empty the hand (a Hot Hand)?
func is_hot() -> bool:
	return can_continue() and potted.size() == throw_faces.size()


func _commit_pot() -> void:
	pot += throw_points()
	if tuning.bounty_requires_pot:
		# The scored combo's effective values (Twins doubled, Wilds as scored).
		_add_pending(selection()["values"])


func _add_pending(faces: Array) -> void:
	for id in BonfireScoring.bounty_ticks(all_bounties(), faces):
		pending[id] = int(pending.get(id, 0)) + 1


## Pot this throw's combo and throw the rest. {} if not allowed, else
## {"hot": bool, "cold": n}.
func rethrow() -> Dictionary:
	if not can_continue():
		return {}
	_commit_pot()
	cold -= potted.size()
	var hot := cold <= 0
	if hot:
		cold = dice_count
		hot_hands += 1
	throw_faces.clear()
	throw_mods.clear()
	potted.clear()
	state = State.AIM
	return {"hot": hot, "cold": cold}


func is_ticked(b: BountyData) -> bool:
	return int(ticks.get(b.id, 0)) >= b.count_needed


func is_pending(b: BountyData) -> bool:
	return not is_ticked(b) and int(ticks.get(b.id, 0)) + int(pending.get(b.id, 0)) >= b.count_needed


func unticked_required() -> int:
	var n := 0
	for b in goal.required:
		if not is_ticked(b):
			n += 1
	return n


## Bank: the pot goes to points, pending ticks become real. Returns the
## result ({} if not allowed).
func bank() -> Dictionary:
	if not can_continue():
		return {}
	_commit_pot()
	var gain := pot
	points += gain
	var newly: Array[StringName] = []
	var bonus_embers := 0
	for b: BountyData in all_bounties():
		var was := is_ticked(b)
		ticks[b.id] = int(ticks.get(b.id, 0)) + int(pending.get(b.id, 0))
		if not was and is_ticked(b):
			newly.append(b.id)
			if goal.bonus.has(b):
				bonus_embers += b.bonus_embers
	embers += bonus_embers
	return _finish({"kind": &"bank", "gain": gain, "ticked": newly, "bonus_embers": bonus_embers})


func _bust() -> void:
	var lost := pot
	soul = maxi(soul - tuning.bust_soul_loss, 0)
	_finish({"kind": &"bust", "lost_pot": lost, "soul_lost": tuning.bust_soul_loss})


func _finish(r: Dictionary) -> Dictionary:
	hands_left -= 1
	pending.clear()
	if r["kind"] == &"bank" and unticked_required() == 0:
		_end_table(State.CLEARED)
	elif soul <= 0:
		_end_table(State.RUN_OVER)
	elif hands_left <= 0:
		_end_table(State.FAILED)
	else:
		_start_hand()
	r["state"] = state
	r["points"] = points
	r["soul"] = soul
	last_result = r
	hand_finished.emit(r)
	return r


func _end_table(st: State) -> void:
	var converted := points / maxi(tuning.points_per_ember, 1)
	var clear := goal.clear_embers if st == State.CLEARED else 0
	var soul_lost := 0
	if st == State.FAILED:
		soul_lost = unticked_required() * goal.timeout_soul_per_bounty
		soul = maxi(soul - soul_lost, 0)
		if soul <= 0:
			st = State.RUN_OVER
	embers += converted + clear
	table_summary = {"points_embers": converted, "clear_embers": clear, "timeout_soul": soul_lost, "points": points}
	state = st


## Give up the table (run mode): ends it like running out of hands
## (timeout Soul per unticked required bounty, points still convert to
## Embers, no clear bonus); the hand in progress is lost. False if over.
func forfeit() -> bool:
	if is_over():
		return false
	forfeited = true
	pending.clear()
	pot = 0
	potted.clear()
	throw_faces.clear()
	throw_mods.clear()
	_end_table(State.FAILED)
	last_result = {"kind": &"forfeit", "state": state, "points": points, "soul": soul}
	return true


## Ids of the bounties banked so far (required and bonus).
func claimed_bounties() -> Array[StringName]:
	var out: Array[StringName] = []
	for b: BountyData in all_bounties():
		if is_ticked(b):
			out.append(b.id)
	return out


func is_over() -> bool:
	return state == State.CLEARED or state == State.FAILED or state == State.RUN_OVER
