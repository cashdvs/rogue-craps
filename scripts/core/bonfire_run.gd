## Bonfire rules state (pure; the 3D scene only shows it).
## A hand: throw the cold dice -> dice that can form a combo light -> pot
## ONE combo (exact match) -> BANK or THROW the rest again. Nothing lit =
## BUST (hand pot and pending bounty ticks lost, -Soul). All 5 potted in the
## hand = HOT HAND: all dice back, +1 mult on every later pot this hand.
## Table goal (TableGoal): bank every required bounty within the hands.
##
## Clearing (how_bonfire_plays.md §2.8): once every required bounty is
## banked the table is CLEARED (`cleared` = true, the clear Embers are paid
## right then) but it stays open. The player can keep throwing the hands
## that are left to chase the bonus bounty and more points, or leave()
## between hands. A bust while chasing costs Soul as usual but never undoes
## the clear or a banked bounty. When the hands run out a cleared table ends
## as CLEARED (no timeout penalty); an uncleared one as FAILED.
##
## Table rules (Elite twists, boss cheats, special-die abilities) are
## TableRule handlers (set_rules); every moment they hook is also emitted on
## `table_event` (hand_start, throw_landed, pot, bank, bust, die_shattered,
## kindling_saved, table_end) so juice / audio can subscribe to the same
## events.
class_name BonfireRun
extends RefCounted

enum State { AIM, PICK, CLEARED, FAILED, RUN_OVER }

signal hand_finished(result: Dictionary)
## event: &"hand_start" {}, &"throw_landed" {throw: TableThrow, changes},
## &"pot" {indices, result, soul_cost, embers}, &"bank" / &"bust" (the hand
## result), &"die_shattered" {index, die}, &"kindling_saved" {},
## &"table_end" {state}.
signal table_event(event: StringName, data: Dictionary)

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
## True from the bank that claimed the last required bounty, for good (a later
## bust, running out of hands or leaving never turns it back off).
var cleared: bool = false
## Filled when the table ends: {"points_embers", "clear_embers", "soul_lost", ...}.
var table_summary: Dictionary = {}
## Active rule handlers (TableRules.build); special-die handlers first.
var rules: Array[TableRule] = []
## Seeded randomness for rules (Pit Boss draw, Madame's reroll, Cracked).
var rng := RandomNumberGenerator.new()
## Soul cap (Blood Pact counts missing Soul from it).
var max_soul: int = 35
## Throws landed this hand (1 = the hand's first throw).
var throws_this_hand: int = 0
## A Kindling face was potted: the next throw can't bust.
var kindling_armed: bool = false
## The last landed throw lit nothing but Kindling saved it (no bust).
var kindling_saved: bool = false
## Knucklebone Seal steps (TableSetup.seal_steps); empty = default RunData.
var seal_steps: Dictionary = {}
## The last landed throw got a free rethrow (§4, NonStdDice.try_free_rethrow),
## and how many in a row (MAX_FREE_RETHROWS then it busts).
var free_rethrow: bool = false
var free_rethrows_in_a_row: int = 0
const MAX_FREE_RETHROWS: int = NonStdDice.MAX_FREE_RETHROWS
## TableDie (or null) per die of this throw.
var throw_table_dice: Array = []
## The last landed throw (with the rules' face changes).
var last_throw: TableThrow
## Combo ids potted this hand / banked this table (one per pot, repeats kept).
var hand_combos: Array[StringName] = []
var banked_combos: Array[StringName] = []
## Dice the player owns in the whole run bag (Cracked never shatters at or
## below tuning.cracked_min_owned_dice). Defaults to the handful size.
var owned_dice_count: int = 5
## TableDie.key() (run_die_id, else id) of every die that shattered here.
var shattered: Array[StringName] = []


## soul_override / dice_override: -1 = tuning.starting_soul / tuning.dice_count.
func _init(t: BonfireTuning, g: TableGoal = null, soul_override: int = -1, dice_override: int = -1) -> void:
	tuning = t
	goal = g if g != null else t.table_goal
	soul = t.starting_soul if soul_override < 0 else soul_override
	max_soul = maxi(soul, t.starting_soul)
	dice_count = t.dice_count if dice_override <= 0 else dice_override
	owned_dice_count = dice_count
	hands_left = goal.hands
	rng.randomize()
	_start_hand()


## Installs the table's rules (TableRules.build) and seeds their randomness
## (-1 = random); runs on_table_start and this hand's on_hand_start.
func set_rules(list: Array[TableRule], seed_value: int = -1) -> void:
	rules = list
	if seed_value >= 0:
		rng.seed = seed_value * 104729 + 17
	for r in rules:
		r.on_table_start(self)
	for r in rules:
		r.on_hand_start(self)


func has_rule(rule_id: StringName) -> bool:
	for r in rules:
		if r.id == rule_id:
			return true
	return false


func _start_hand() -> void:
	pot = 0
	hot_hands = 0
	cold = dice_count
	throw_faces.clear()
	throw_mods.clear()
	potted.clear()
	pending.clear()
	throws_this_hand = 0
	kindling_armed = false
	free_rethrows_in_a_row = 0
	hand_combos.clear()
	throw_table_dice.clear()
	state = State.AIM
	for r in rules:
		r.on_hand_start(self)
	table_event.emit(&"hand_start", {})


func mult_bonus() -> int:
	var per := tuning.hot_hand_mult_bonus
	for r in rules:
		per = r.hot_hand_mult_bonus(self, per)
	return hot_hands * per


## What the rules say right now, as BonfireScoring's ctx.
func rule_ctx() -> Dictionary:
	var cold_values: Array[int] = []
	for v in range(1, BonfireScoring.MAX_FACE + 1):
		for r in rules:
			if not r.can_light(self, v):
				cold_values.append(v)
				break
	var no_mods := false
	var excluded: Array = []
	var min_pot := 0
	for r in rules:
		no_mods = no_mods or not r.mods_active(self)
		for c in r.excluded_combos(self):
			if not excluded.has(c):
				excluded.append(c)
		min_pot = maxi(min_pot, r.min_pot(self))
	var n := throw_faces.size()
	return {"cold_values": cold_values, "no_mods": no_mods, "excluded_combos": excluded,
		"min_dice": mini(min_pot, n) if min_pot > 0 else 1, "soul": soul, "max_soul": max_soul,
		"throw_size": n, "is_rethrow": throws_this_hand > 1, "wild_max": wild_max(), "seal_steps": seal_steps,
		"blood_cost": func(raw: int) -> int: return soul_cost(raw, &"blood")}


## The Wild / Step cap for this tray (NonStdDice, §5).
func wild_max() -> int:
	return NonStdDice.wild_max(throw_table_dice)


## The ctx for a throw of `n` dice that hasn't happened yet (the rethrow
## prompt's bust risk): like rule_ctx(), but sized for those n dice.
func next_throw_ctx(n: int) -> Dictionary:
	var ctx := rule_ctx()
	var min_pot := 0
	for r in rules:
		min_pot = maxi(min_pot, r.min_pot(self))
	ctx["throw_size"] = n
	ctx["min_dice"] = mini(min_pot, n) if min_pot > 0 else 1
	ctx["is_rethrow"] = throws_this_hand >= 1
	return ctx


## The rules that change faces after the dice settle, for BustRisk.
func throw_effects() -> Array:
	var out: Array = []
	for r in rules:
		if r is RuleMadameShuffle:
			out.append({"kind": &"shuffle", "count": int(r.param("count", 1))})
		elif r is DieMirror and not out.any(func(e: Dictionary) -> bool: return e["kind"] == &"mirror"):
			out.append({"kind": &"mirror"})  # one entry covers every Mirror die
	return out


## Chance the next throw of these dice (TableDie or null) burns, exactly
## (BustRisk). `kindling`: a Kindling face is armed for it (can't burn).
## A throw that would get the §4 free rethrow (NonStdDice) can't burn
## either: lighting nothing just throws it again ("free_rethrow": true).
func next_throw_risk(table_dice: Array, kindling: bool = false) -> Dictionary:
	var free := NonStdDice.next_throw_is_free(self, table_dice)
	var out := BustRisk.chance(table_dice, tuning, next_throw_ctx(table_dice.size()), throw_effects(), kindling or free)
	out["free_rethrow"] = free
	return out


func bounties_count() -> bool:
	for r in rules:
		if not r.bounties_count(self):
			return false
	return true


func hot_hand_allowed() -> bool:
	for r in rules:
		if not r.hot_hand_allowed(self):
			return false
	return true


## Soul a cost really takes after the rules (kind: &"bust", &"timeout", &"blood").
func soul_cost(amount: int, kind: StringName) -> int:
	for r in rules:
		amount = r.soul_cost(self, amount, kind)
	return amount


## The special die id of die i of this throw (&"" = none).
func throw_special(i: int) -> StringName:
	var td: TableDie = throw_table_dice[i] if i >= 0 and i < throw_table_dice.size() else null
	return td.special if td != null else &""


## Can a Cracked die shatter now? Never while the bag is at the floor.
func can_shatter() -> bool:
	return owned_dice_count > tuning.cracked_min_owned_dice


## Die i of this throw leaves the table for good (Cracked). It stays potted
## for this pot; later throws have one die fewer.
func shatter(i: int) -> void:
	var td: TableDie = throw_table_dice[i] if i >= 0 and i < throw_table_dice.size() else null
	if td != null:
		shattered.append(td.key())
	dice_count = maxi(dice_count - 1, 0)
	owned_dice_count -= 1
	table_event.emit(&"die_shattered", {"index": i, "die": td})


func all_bounties() -> Array:
	return goal.required + goal.bonus


## The faces of a throw of `cold` dice (and each face's mod, FaceModData or
## null; omit for plain dice). Returns true if something lit.
func set_throw(faces: Array[int], mods: Array = [], table_dice: Array = []) -> bool:
	return land_throw(TableThrow.make(faces, mods, table_dice, rng))


## A settled throw: the rules may change faces (th.changes), then it lights
## or busts. Returns true if something lit. False with kindling_saved = a
## Kindling face saved it (throw the same dice again), else a bust.
func land_throw(th: TableThrow) -> bool:
	throws_this_hand += 1
	if th.rng == null:
		th.rng = rng
	for r in rules:
		r.on_throw_landed(self, th)
	throw_faces = th.values.duplicate()
	throw_mods = th.mods.duplicate()
	throw_mods.resize(throw_faces.size())
	throw_table_dice = th.dice.duplicate()
	throw_table_dice.resize(throw_faces.size())
	last_throw = th
	potted.clear()
	table_event.emit(&"throw_landed", {"throw": th, "changes": th.changes})
	var saved := kindling_armed
	kindling_armed = false
	kindling_saved = false
	free_rethrow = false
	if lit().is_empty():
		if NonStdDice.try_free_rethrow(self, th.size(), cold):
			return false
		if saved:
			throw_faces.clear()
			throw_mods.clear()
			throw_table_dice.clear()
			state = State.AIM
			kindling_saved = true
			table_event.emit(&"kindling_saved", {})
			return false
		_bust()
		return false
	free_rethrows_in_a_row = 0
	if not tuning.bounty_requires_pot and bounties_count():
		_add_pending(BonfireScoring.plain_values(throw_dice()))
	state = State.PICK
	return true


func lit() -> Array[int]:
	return BonfireScoring.lit_indices(throw_dice(), tuning, rule_ctx())


## This throw as scoring dice ({value, mod, special}).
func throw_dice() -> Array:
	var out: Array = []
	for i in throw_faces.size():
		out.append(BonfireScoring.make_die(throw_faces[i], throw_mods[i] if i < throw_mods.size() else null, throw_special(i)))
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
	if not BonfireScoring.can_extend(next, throw_dice(), tuning, rule_ctx()):
		return false
	potted = next
	return true


func selection() -> Dictionary:
	var res := BonfireScoring.score_selection(selection_faces(), tuning, mult_bonus(), rule_ctx())
	if res["valid"]:
		for r in rules:
			r.modify_score(self, res)
	return res


func throw_points() -> int:
	return int(selection()["points"])


func hand_pot() -> int:
	return pot + throw_points()


func can_continue() -> bool:
	return state == State.PICK and selection()["valid"]


## Would potting the current selection empty the hand (a Hot Hand)?
func is_hot() -> bool:
	return can_continue() and potted.size() == throw_faces.size()


## "" if the current selection may be thrown on, else why not.
func rethrow_block_reason() -> String:
	if not can_continue():
		return "Pot at least one burning die first."
	if is_hot() and not hot_hand_allowed():
		return "No Hot Hand at this table: bank it."
	return ""


func _commit_pot() -> void:
	var res := selection()
	pot += int(res["points"])
	if tuning.bounty_requires_pot and bounties_count():
		# The scored combo's effective values (Twins doubled, Wilds as scored).
		# A gapped (Wanderer) run ticks the run bounty of its length.
		_add_pending(res["bounty_values"])
	# Blood faces: Soul paid as the pot is scored (BonfireScoring already
	# applied the Bloodletter and refused it if it would take the last Soul).
	var cost := int(res["soul_cost"])
	soul -= cost
	# Gilded faces: Embers right away (kept even if the hand busts later).
	embers += int(res["embers"])
	if res["kindling"]:
		kindling_armed = true
	hand_combos.append(StringName(res["combo"]))
	var info := {"indices": potted.duplicate(), "result": res, "soul_cost": cost, "embers": int(res["embers"])}
	for r in rules:
		r.on_pot(self, info)
	table_event.emit(&"pot", info)


func _add_pending(faces: Array) -> void:
	for id in BonfireScoring.bounty_ticks(all_bounties(), faces):
		pending[id] = int(pending.get(id, 0)) + 1


## Pot this throw's combo and throw the rest. {} if not allowed, else
## {"hot": bool, "cold": n}.
func rethrow() -> Dictionary:
	if rethrow_block_reason() != "":
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
	banked_combos.append_array(hand_combos)
	var r := {"kind": &"bank", "gain": gain, "ticked": newly, "bonus_embers": bonus_embers}
	for rule in rules:
		rule.on_bank(self, r)
	table_event.emit(&"bank", r)
	return _finish(r)


func _bust() -> void:
	var lost := pot
	var cost := soul_cost(tuning.bust_soul_loss, &"bust")
	soul = maxi(soul - cost, 0)
	var r := {"kind": &"bust", "lost_pot": lost, "soul_lost": cost}
	for rule in rules:
		rule.on_bust(self, r)
	table_event.emit(&"bust", r)
	_finish(r)


func _finish(r: Dictionary) -> Dictionary:
	hands_left -= 1
	pending.clear()
	# The bank that claims the last required bounty clears the table: the
	# clear Embers are locked in now, and the table stays open.
	r["cleared_now"] = false
	if r["kind"] == &"bank" and not cleared and unticked_required() == 0:
		cleared = true
		embers += goal.clear_embers
		r["cleared_now"] = true
		table_event.emit(&"table_cleared", {})
	if soul <= 0:
		_end_table(State.RUN_OVER)
	elif hands_left <= 0:
		# Out of hands: a cleared table simply ends (the "auto-leave"); an
		# uncleared one has failed (timeout Soul in _end_table).
		_end_table(State.CLEARED if cleared else State.FAILED)
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
	# The clear Embers were already paid at the clearing bank (see _finish).
	var clear := goal.clear_embers if cleared else 0
	var soul_lost := 0
	if st == State.FAILED:
		soul_lost = soul_cost(unticked_required() * goal.timeout_soul_per_bounty, &"timeout")
		soul = maxi(soul - soul_lost, 0)
		if soul <= 0:
			st = State.RUN_OVER
	embers += converted
	# The hand is over: its pot was banked or lost, nothing is potted any
	# more (else hand_pot() shows the last pot twice on the end panel; QA).
	pot = 0
	potted.clear()
	table_summary = {"points_embers": converted, "clear_embers": clear, "timeout_soul": soul_lost, "points": points}
	state = st
	table_event.emit(&"table_end", {"state": st})


## Can the player leave now? Only a cleared table, only between hands (no
## throw made yet this hand).
func can_leave() -> bool:
	return cleared and not is_over() and state == State.AIM and throws_this_hand == 0


## Leave a cleared table between hands: it ends as CLEARED (points convert,
## no timeout penalty). False if not allowed right now (see can_leave).
func leave() -> bool:
	if not can_leave():
		return false
	_end_table(State.CLEARED)
	last_result = {"kind": &"leave", "state": state, "points": points, "soul": soul}
	return true


## Give up the table (run mode): ends it like running out of hands
## (timeout Soul per unticked required bounty, points still convert to
## Embers, no clear bonus); the hand in progress is lost. False if over.
## On a table that is already cleared it is a Leave instead: the hand in
## progress is lost, but the clear and the banked bounties stand (not
## counted as forfeited, so the run still sees a cleared table).
func forfeit() -> bool:
	if is_over():
		return false
	forfeited = not cleared
	pending.clear()
	pot = 0
	potted.clear()
	throw_faces.clear()
	throw_mods.clear()
	_end_table(State.CLEARED if cleared else State.FAILED)
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
