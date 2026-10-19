## Table rules for the non-d6 dice (design/nonstandard_dice.md, APPROVED by
## PM Oct 19, 2026). BonfireRun and BonfireScoring call these; kept here so
## the d6 table code stays short and the odd-dice rules sit in one place.
##   §2/§3  faces up to MAX_FACE (a d20); a face above 6 lights alone.
##   §2     a face of value 0 or less (a Blank, the coin's Tails) never scores.
##   §4     free rethrow: a full throw that lights nothing AND has a non-d6
##          die in the tray is thrown again for free; MAX_FREE_RETHROWS in
##          a row bust. A plain d6 throw still busts (Cold Sixes, Greedy Pot,
##          Bloodletter keep working).
##   §5     Wild / Step reach is capped at the tray's highest face.
##   §10    Caltrop: +caltrop_run_mult mult on a Run containing it.
##          Knucklebone: Pair, Trips, Four or Five of a kind containing it
##          scores one Seal level higher (not Two Pair / Full House).
class_name NonStdDice
extends RefCounted

## Highest face value the table handles (a d20).
const MAX_FACE: int = 20
## Free rethrows in a row before a handful that can't light busts anyway.
const MAX_FREE_RETHROWS: int = 5
## The combos the Knucklebone levels up (PM ruling 3: no Two Pair / Full House).
const KNUCKLEBONE_COMBOS: Array[StringName] = [&"pair", &"trips", &"quads", &"five_kind"]
## The run's data, for the Seal steps when the ctx doesn't pass any.
const RUN_DATA_PATH: String = "res://resources/map/bonfire_run.tres"

static var _default_steps: Dictionary = {}


## A face value that can score: 1 or more (§2).
static func scores(value: int) -> bool:
	return value >= 1


## A non-d6 die (coin, d4, d8, ...) is in `table_dice` (TableDie or null each).
static func has_wide_die(table_dice: Array) -> bool:
	for td in table_dice:
		if td != null and (td as TableDie).shape != &"d6":
			return true
	return false


## The Wild cap (§5): 6, or the highest face a die in the tray can show.
static func wild_max(table_dice: Array) -> int:
	var top := 6
	for td in table_dice:
		if td != null:
			for v in (td as TableDie).faces:
				top = maxi(top, int(v))
	return mini(top, MAX_FACE)


## §4: does a throw that lit nothing get thrown again for free? Only a full
## throw (`thrown` and `cold` both cover every die), with a non-d6 die in
## the tray, fewer than MAX_FREE_RETHROWS times in a row.
static func free_rethrow_ok(thrown: int, cold: int, dice_count: int, table_dice: Array, in_a_row: int) -> bool:
	return thrown >= dice_count and cold >= dice_count and has_wide_die(table_dice) and in_a_row < MAX_FREE_RETHROWS


## §4 on a BonfireRun whose throw of `thrown` dice lit nothing (`cold` dice
## unlit): if it qualifies (free_rethrow_ok), the same dice go again for
## free and it still counts as this throw (a hand's first stays the first).
## Returns true when it did; false = the run busts / Kindling as usual.
static func try_free_rethrow(run: BonfireRun, thrown: int, cold: int) -> bool:
	if not free_rethrow_ok(thrown, cold, run.dice_count, run.throw_table_dice, run.free_rethrows_in_a_row):
		return false
	run.throw_faces.clear()
	run.throw_mods.clear()
	run.throw_table_dice.clear()
	run.throws_this_hand -= 1
	run.state = BonfireRun.State.AIM
	run.free_rethrow = true
	run.free_rethrows_in_a_row += 1
	run.table_event.emit(&"free_rethrow", {})
	return true


## The Knucklebone's "one Seal level" per combo, {combo id: Vector2i(base,
## mult)}, from a RunData's seal_base_step / seal_mult_step.
static func seal_steps(rd: RunData) -> Dictionary:
	var out: Dictionary = {}
	if rd == null:
		return out
	for id in KNUCKLEBONE_COMBOS:
		out[id] = Vector2i(int(rd.seal_base_step.get(id, 0)), int(rd.seal_mult_step.get(id, 0)))
	return out


## seal_steps() of the run's own RunData (loaded once).
static func default_seal_steps() -> Dictionary:
	if _default_steps.is_empty():
		_default_steps = seal_steps(load(RUN_DATA_PATH) as RunData)
	return _default_steps


## Caltrop / Knucklebone on one scoring candidate: `sp` is the special id,
## `c` the combo, `acc` the running {"adds", "seal_base", "seal_up"}. Other
## specials are left alone (false).
static func apply_special(sp: StringName, c: BonfireCombo, t: BonfireTuning, ctx: Dictionary, acc: Dictionary) -> bool:
	match sp:
		&"caltrop":
			if c.kind == BonfireCombo.Kind.RUN:
				acc["adds"] += t.caltrop_run_mult
			return true
		&"knucklebone":
			# One level up per pot, however many Knucklebones are in it.
			if c.kind == BonfireCombo.Kind.N_OF_A_KIND and c.n >= 2 and not acc["seal_up"]:
				var steps: Dictionary = ctx.get("seal_steps", {})
				if steps.is_empty():
					steps = default_seal_steps()
				var step: Vector2i = steps.get(c.id, Vector2i.ZERO)
				acc["seal_base"] += step.x
				acc["adds"] += step.y
				acc["seal_up"] = true
			return true
	return false


## Every choice of value for each Step face: its value or +-1 (1..top, not
## cold; top = 6 unless a wider die is in the tray).
static func step_options(steps: Array[int], cold: Array, top: int = 6) -> Array:
	var out: Array = [[]]
	for v in steps:
		var next: Array = []
		for prefix: Array in out:
			for o in [v, v - 1, v + 1]:
				if o >= 1 and o <= maxi(top, v) and not cold.has(o):
					var p := prefix.duplicate()
					p.append(o)
					next.append(p)
		out = next
	return out


## Every multiset of `n` values 1..top not in `cold` (order doesn't matter).
static func wild_assignments(n: int, cold: Array = [], top: int = 6) -> Array:
	var out: Array = []
	var cur: Array[int] = []
	_assign_rec(n, 1, cur, out, cold, clampi(top, 1, MAX_FACE))
	return out


static func _assign_rec(n: int, from: int, cur: Array[int], out: Array, cold: Array, top: int) -> void:
	if cur.size() == n:
		out.append(cur.duplicate())
		return
	for v in range(from, top + 1):
		if cold.has(v):
			continue
		cur.append(v)
		_assign_rec(n, v, cur, out, cold, top)
		cur.pop_back()
