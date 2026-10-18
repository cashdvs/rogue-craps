## The rules of the Burn Line sandbox (no nodes, so tests run headless).
##
## A HAND: place a bet (chips of bet_chip, up to the table's cap; taken from
## coin when placed), optionally the Exact Hit side bet, then throw one die at
## a time from your loadout. Each face adds to the running total. Stop any
## time after the first throw: the bet's RETURN depends on how far under the
## Line you are (BurnLineTuning.return_by_distance). Going over the Line is a
## BURN: the bet is lost and Soul burns.
## A TABLE: hands toward a coin target; clear it by ending a hand with coin
## >= target. Fail when hands run out or coin can't cover the minimum bet.
## A RUN: tables in order; Soul carries over (0 = run over); the last table
## cleared = run won. Coin resets every table. No healing in the sandbox.
## All numbers: resources/tuning/burn_line_tuning.tres (BurnLineTuning).
class_name BurnLineRun
extends RefCounted

enum State { HAND, TABLE_CLEARED, TABLE_FAILED, RUN_WON, RUN_OVER }

## A hand ended. result: see _finish_hand().
signal hand_finished(result: Dictionary)
signal state_changed(state: State)

var tuning: BurnLineTuning
var rng := RandomNumberGenerator.new()
var state: State = State.HAND
var table_index: int = 0
var soul: int = 35
var coin: int = 0
var hands_left: int = 0
## The two dice in play this table.
var loadout: Array[BurnDie] = []
var loadout_id: StringName = &"standard"

# --- This hand ---
var bet: int = 0
var side_bet: bool = false
var total: int = 0
## Every throw: {"die": StringName, "slot": int, "value": int}.
var throws: Array[Dictionary] = []
var throws_by_die: Dictionary = {}
var last_result: Dictionary = {}


func _init(t: BurnLineTuning, seed_value: int = -1) -> void:
	tuning = t
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	start_run()


## A fresh run: full Soul, table 1, the default loadout.
func start_run() -> void:
	soul = tuning.starting_soul
	table_index = 0
	set_loadout(tuning.default_dice(), tuning.default_loadout)
	start_table()


func table() -> BurnTableSpec:
	return tuning.tables[table_index]


func line() -> int:
	return table().line


## Choose the dice for this table (e.g. from the "Change dice" picker). Only
## allowed before the hand's first throw.
func set_loadout(dice: Array[BurnDie], id: StringName = &"custom") -> bool:
	if not throws.is_empty() or dice.is_empty():
		return false
	loadout = dice.duplicate()
	loadout_id = id
	return true


func start_table() -> void:
	coin = table().start_coin
	hands_left = table().hands
	state = State.HAND
	_start_hand()
	state_changed.emit(state)


## Next table after a clear (or the run is won after the last one).
func next_table() -> void:
	if state != State.TABLE_CLEARED:
		return
	table_index += 1
	start_table()


func _start_hand() -> void:
	total = 0
	throws.clear()
	throws_by_die.clear()
	bet = 0
	side_bet = false
	# Auto-place the minimum bet if affordable (the bet selector changes it).
	if coin >= tuning.min_bet:
		place_bet(tuning.min_bet)


func hand_started() -> bool:
	return not throws.is_empty()


## Coin including the bet (and side bet) already on the table this hand.
func bankroll() -> int:
	return coin + bet + (tuning.exact_side_cost if side_bet else 0)


func bet_cap() -> int:
	return table().bet_cap


## Sets the hand's bet (refunds the old one first). Before the first throw only.
func place_bet(amount: int) -> bool:
	if state != State.HAND or hand_started():
		return false
	amount = clampi(amount, tuning.min_bet, bet_cap())
	amount -= amount % tuning.bet_chip
	if amount < tuning.min_bet or amount > coin + bet:
		return false
	coin += bet - amount
	bet = amount
	return true


## Toggles the Exact Hit side bet (before the first throw). Returns true if changed.
func set_side_bet(on: bool) -> bool:
	if state != State.HAND or hand_started() or on == side_bet:
		return false
	if on:
		if coin < tuning.exact_side_cost:
			return false
		coin -= tuning.exact_side_cost
	else:
		coin += tuning.exact_side_cost
	side_bet = on
	return true


## Throws left for a die this hand (-1 = unlimited).
func throws_left(die: BurnDie) -> int:
	if die.max_throws_per_hand <= 0:
		return -1
	return maxi(die.max_throws_per_hand - int(throws_by_die.get(die.id, 0)), 0)


func can_throw(die: BurnDie) -> String:
	if state != State.HAND:
		return "The table is over."
	if bet <= 0:
		return "Place a bet first."
	if not loadout.has(die):
		return "That die isn't in your loadout."
	if throws_left(die) == 0:
		return "%s is Cramped: one throw per hand." % die.display_name
	return ""


## Seeded face for the next throw of `die`: returns the face SLOT (1..6).
## The 3D table lands the physical die on this slot (pre-sim remap).
func pick_slot(die: BurnDie) -> int:
	return die.roll_slot(rng)


## Adds a thrown die to the total. A total over the Line burns at once.
## Returns the new total.
func add_throw(die: BurnDie, slot: int) -> int:
	var value: int = die.faces[slot - 1]
	total += value
	throws.append({"die": die.id, "slot": slot, "value": value})
	throws_by_die[die.id] = int(throws_by_die.get(die.id, 0)) + 1
	if total > line():
		_finish_hand(true, die)
	return total


func can_stop() -> bool:
	return state == State.HAND and hand_started()


## Ends the hand on the player's Stop. Returns the result (see _finish_hand).
func stop() -> Dictionary:
	if not can_stop():
		return {}
	var last := tuning.find_die(throws[throws.size() - 1]["die"])
	return _finish_hand(false, last)


## What a stop at the current total would return (for the HUD).
func return_multiplier_now() -> float:
	var d := line() - total
	if d == 0 and not throws.is_empty():
		var last := tuning.find_die(throws[throws.size() - 1]["die"])
		if last != null and last.exact_return_override > 0.0:
			return last.exact_return_override
	return tuning.return_for(d)


## Settles the hand. result = {"kind": &"exact"|&"close"|&"near"|&"miss"|&"burn",
## "total", "line", "bet", "returned", "profit", "soul_lost", "side_bet",
## "side_returned", "die": last die id}.
func _finish_hand(burned: bool, last_die: BurnDie) -> Dictionary:
	var d := line() - total
	var r := {"total": total, "line": line(), "bet": bet, "side_bet": side_bet, "die": last_die.id if last_die != null else &""}
	var returned := 0
	var side_returned := 0
	var soul_lost := 0
	if burned:
		r["kind"] = &"burn"
		soul_lost = tuning.burn_soul_loss + (last_die.burn_soul_extra if last_die != null else 0)
	else:
		var mult := return_multiplier_now()
		returned = int(floor(float(bet) * mult + 0.0001))
		r["kind"] = &"exact" if d == 0 else (&"close" if d == 1 else (&"near" if mult > 0.0 else &"miss"))
		r["multiplier"] = mult
		if side_bet and d == 0:
			side_returned = tuning.exact_side_cost * (1 + tuning.exact_side_pay)
	coin += returned + side_returned
	soul = maxi(soul - soul_lost, 0)
	r["returned"] = returned
	r["side_returned"] = side_returned
	r["profit"] = returned + side_returned - bet - (tuning.exact_side_cost if side_bet else 0)
	r["soul_lost"] = soul_lost
	hands_left -= 1
	# Next state: run over > clear > fail > next hand.
	if soul <= 0:
		state = State.RUN_OVER
	elif coin >= table().coin_target:
		state = State.RUN_WON if table_index >= tuning.tables.size() - 1 else State.TABLE_CLEARED
	elif hands_left <= 0 or coin < tuning.min_bet:
		state = State.TABLE_FAILED
	else:
		state = State.HAND
	r["state"] = state
	last_result = r
	if state == State.HAND:
		_start_hand()
	else:
		throws.clear()
		throws_by_die.clear()
		bet = 0
		side_bet = false
		total = 0
	hand_finished.emit(r)
	if state != State.HAND:
		state_changed.emit(state)
	return r
