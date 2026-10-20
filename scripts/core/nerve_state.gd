## Nerve (design/nerve_v1.md): once per table, after a throw settles and
## before you pot from it, turn one unpotted die from this throw to the
## adjacent printed value on that die's own face list. Pure logic, no nodes.
##
## Face slots are 1-based, as on TableDie (slot k shows faces[k-1]); a
## "face index" here is always such a slot. Face mods live on physical slots
## (TableDie.mods) and never move, so after a nudge the new slot's own mod
## applies (Wild, Twin, Blank, Blood, Gilded, Hellfire ...).
##
## The table owns everything physical: rolling, set_face, re-running copies
## (Mirror / Coin) and the lit check, boss filters, the HUD pip and the
## die_nudged signal. It drives this class with begin_throw() when a throw
## settles, nudge() / undo() on taps, and commit() on pot / rethrow / bank.
##
## Nerve never costs Soul or Embers (Bloodletter included): nothing here
## touches either; a Blood face it lands on is paid only if potted.
class_name NerveState
extends RefCounted

## UI state of the Nerve pip (nerve_v1.md §1 "UI states").
enum UiState { READY, PICKING, NUDGED, SPENT }

## Directions for nudge() / can_nudge_dir().
const UP := 1
const DOWN := -1

## Nerve uses per table (TableSetup.nerve_uses; 1 in v1).
var uses_per_table: int = 1
## The table's dice (same order as the table's die indices).
var dice: Array[TableDie] = []
## Current face slot per die for this throw (0 = not in this throw).
var slots: Array[int] = []
## Dice already potted from this throw (locked).
var potted: Array[bool] = []

var _used: int = 0
var _nudged_die: int = -1
var _from_slot: int = 0
var _picking: int = -1
var _throw_open: bool = false


## Sets up the table's dice and refills Nerve (start of a table).
func setup(table_dice: Array[TableDie], uses: int = 1) -> void:
	dice = table_dice
	uses_per_table = maxi(uses, 0)
	reset_table()


## Refills Nerve for a new table (a boss re-sit counts as a new table).
## Clears any throw and pending nudge.
func reset_table() -> void:
	_used = 0
	_nudged_die = -1
	_from_slot = 0
	_picking = -1
	_throw_open = false
	slots.clear()
	slots.resize(dice.size())
	slots.fill(0)
	potted.clear()
	potted.resize(dice.size())
	potted.fill(false)


## A throw settled (after copies, boss effects and the lit check). [param
## throw_slots] has one face slot per die, 0 for dice not in this throw
## (potted earlier or set aside). A still-pending nudge from an earlier
## throw is committed first (spent).
func begin_throw(throw_slots: Array[int]) -> void:
	commit()
	slots.assign(throw_slots)
	slots.resize(dice.size())
	potted.resize(dice.size())
	potted.fill(false)
	_throw_open = true


## Locks the throw's Nerve: call on pot (any die from this throw), rethrow
## or bank. A pending nudge becomes spent; undo is no longer possible.
func commit() -> void:
	if _nudged_die >= 0:
		_used += 1
	_nudged_die = -1
	_from_slot = 0
	_picking = -1
	_throw_open = false


## Marks die [param die_index] potted from this throw; commits the nudge.
func mark_potted(die_index: int) -> void:
	if die_index >= 0 and die_index < potted.size():
		potted[die_index] = true
	commit()


## Nerve uses left this table (a pending, undoable nudge counts as used).
func uses_left() -> int:
	return maxi(uses_per_table - _used - (1 if _nudged_die >= 0 else 0), 0)


## The pip's UI state.
func ui_state() -> UiState:
	if _nudged_die >= 0:
		return UiState.NUDGED
	if uses_left() <= 0:
		return UiState.SPENT
	if _picking >= 0:
		return UiState.PICKING
	return UiState.READY


## Die index currently nudged and undoable, or -1.
func nudged_die() -> int:
	return _nudged_die


## Die index being picked (arrows shown), or -1.
func picking_die() -> int:
	return _picking


## True for a copy die (Mirror, Ferryman's Coin): never a Nerve target.
static func is_copy_die(d: TableDie) -> bool:
	return d.special == DiceIds.DIE_MIRROR or d.id == DiceIds.DIE_MIRROR \
		or d.id == DiceIds.DIE_FERRYMAN or d.special == DiceIds.DIE_FERRYMAN \
		or d.shape == DiceIds.SHAPE_COIN


## Why die [param die_index] can't be nudged: "" if it can, else a strings_v1
## id (nerve_used_refusal, nerve_copy_refusal, nerve_potted_refusal) or
## "not_in_throw".
func refusal(die_index: int) -> String:
	if die_index < 0 or die_index >= dice.size():
		return "not_in_throw"
	if uses_left() <= 0:
		return "nerve_used_refusal"
	if is_copy_die(dice[die_index]):
		return "nerve_copy_refusal"
	if potted[die_index]:
		return "nerve_potted_refusal"
	if not _throw_open or slots[die_index] <= 0:
		return "not_in_throw"
	return ""


## True if die [param die_index] can be nudged now (Nerve left, an unpotted
## non-copy die from this throw, and at least one direction has a face).
func can_nudge(die_index: int) -> bool:
	return refusal(die_index) == "" and (can_nudge_dir(die_index, UP) or can_nudge_dir(die_index, DOWN))


## True if die [param die_index] can go [param dir] (UP / DOWN) now; false at
## the end of its face list (no wrap). Greys out the arrow.
func can_nudge_dir(die_index: int, dir: int) -> bool:
	if refusal(die_index) != "":
		return false
	return target_slot(dice[die_index], slots[die_index], dir) > 0


## Face slot die [param d] turns to from [param slot] going [param dir]: the
## next distinct printed value up or down on its own face list, no wrap.
## With repeated values (Powder Keg 1-1-2-2-3-3) the first slot holding that
## value in face-list order. 0 if there is none.
static func target_slot(d: TableDie, slot: int, dir: int) -> int:
	if slot < 1 or slot > d.face_count() or (dir != UP and dir != DOWN):
		return 0
	var v := d.value_at(slot)
	var best := 0
	var best_v := 0
	for k in range(1, d.face_count() + 1):
		var w := d.value_at(k)
		if (w - v) * dir <= 0:
			continue
		if best == 0 or (w - best_v) * dir < 0:
			best = k
			best_v = w
	return best


## Nudges die [param die_index] one face in [param dir]; returns the new face
## slot, or -1 if refused. Nerve is then pending (undoable) until commit().
func nudge(die_index: int, dir: int) -> int:
	if not can_nudge_dir(die_index, dir):
		return -1
	var to := target_slot(dice[die_index], slots[die_index], dir)
	_nudged_die = die_index
	_from_slot = slots[die_index]
	slots[die_index] = to
	_picking = -1
	return to


## Undoes the pending nudge on [param die_index] (tap the die again); Nerve
## returns. Returns the restored slot, or -1 if there is nothing to undo.
func undo(die_index: int) -> int:
	if _nudged_die < 0 or die_index != _nudged_die:
		return -1
	var back := _from_slot
	slots[die_index] = back
	_nudged_die = -1
	_from_slot = 0
	return back


## Tap on a die: picks it (Picking state) if it can be nudged; returns true.
func pick(die_index: int) -> bool:
	if not can_nudge(die_index):
		return false
	_picking = die_index
	return true


## Closes the arrows without nudging.
func cancel_pick() -> void:
	_picking = -1


## Bust rescue: true if Nerve is available and some legal nudge would light
## something. [param lit_fn] takes the whole throw's slots (Array[int], one
## per die, 0 = not in throw) and returns true if anything lights after the
## table re-runs copies and the lit check (boss filters included, so a 6
## nudged up under Wick / Cold Sixes stays cold).
func any_nudge_lights(lit_fn: Callable) -> bool:
	return not rescue_options(lit_fn).is_empty()


## Every legal nudge that would light something: [{die, dir, slot}, ...].
func rescue_options(lit_fn: Callable) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _nudged_die >= 0:
		return out
	for i in dice.size():
		for dir in [UP, DOWN]:
			if not can_nudge_dir(i, dir):
				continue
			var trial := slots.duplicate()
			trial[i] = target_slot(dice[i], slots[i], dir)
			if lit_fn.call(trial):
				out.append({"die": i, "dir": dir, "slot": trial[i]})
	return out
