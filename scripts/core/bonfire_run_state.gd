## Layer 1 of the Bonfire rules (see bonfire_run.gd for the whole picture).
## Holds the table's state (signals, constants, variables), the rule hooks
## and the read-only questions (what is lit? may I leave?). The actions that
## change the state (land a throw, pot, rethrow, bank, bust) live in
## BonfireRun, which extends this. Only BonfireRun is ever created.
@abstract
class_name BonfireRunState
extends RefCounted


# Declared here, written in a later layer (the chain ends at BonfireRun).
# "@abstract" only promises the function exists so this file can call it.
@abstract func land_throw(th: TableThrow) -> bool
@abstract func confirm_bust() -> void
@abstract func relight(th: TableThrow) -> bool
@abstract func rethrow() -> Dictionary
@abstract func bank() -> Dictionary
@abstract func leave() -> bool


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
	# table_goals_v1 PR1: a target table has no bounty cards; nothing ticks.
	if goal != null and goal.target > 0:
		return false
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


## Nerve's bust-rescue pause (nerve_v1.md §1). The table sets bust_hold to
## a Callable() -> bool; when a throw lights nothing (and no free rethrow or
## Kindling saves it) land_throw asks it first. True = don't bust yet:
## bust_pending is set and the throw stays open (State.PICK, nothing lit)
## until the player nudges a die (relight) or takes the bust (confirm_bust).
var bust_hold: Callable
var bust_pending: bool = false


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


## Embers that `pts` table points pay under tuning `t`: 1 per points_per_ember,
## capped at points_embers_cap per table (0 = no cap). The one conversion:
## the payout and every preview use it.
static func points_to_embers(t: BonfireTuning, pts: int) -> int:
	var converted := pts / maxi(t.points_per_ember, 1)
	# P1 (economy v1): points pay at most points_embers_cap Embers per table.
	if t.points_embers_cap > 0:
		converted = mini(converted, t.points_embers_cap)
	return converted


## Can the player leave now? Only a cleared table, only between hands (no
## throw made yet this hand).
func can_leave() -> bool:
	return cleared and not is_over() and state == State.AIM and throws_this_hand == 0


## Ids of the bounties banked so far (required and bonus).
func claimed_bounties() -> Array[StringName]:
	var out: Array[StringName] = []
	for b: BountyData in all_bounties():
		if is_ticked(b):
			out.append(b.id)
	return out


func is_over() -> bool:
	return state == State.CLEARED or state == State.FAILED or state == State.RUN_OVER
