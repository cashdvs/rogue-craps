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
var _granted: int = 0
var _nudged_die: int = -1
var _from_slot: int = 0
var _picking: int = -1
var _throw_open: bool = false
var _landed: Array[int] = []


## Sets up the table's dice and refills Nerve (start of a table).
func setup(table_dice: Array[TableDie], uses: int = 1) -> void:
	dice = table_dice
	uses_per_table = maxi(uses, 0)
	reset_table()


## Refills Nerve for a new table (a boss re-sit counts as a new table).
## Clears any throw and pending nudge.
func reset_table() -> void:
	_used = 0
	_granted = 0
	_nudged_die = -1
	_from_slot = 0
	_picking = -1
	_throw_open = false
	_landed.clear()
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
	_landed.assign(throw_slots)
	_landed.resize(dice.size())
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
	return maxi(uses_per_table + _granted - _used - (1 if _nudged_die >= 0 else 0), 0)


## +n Nerve uses for this hand only (rare_dice_v2 Boom).
func grant_use(n: int) -> void:
	_granted += maxi(n, 0)


## Hand over: granted uses are gone (spent ones were the grant's).
func clear_granted() -> void:
	_used -= mini(maxi(_used - uses_per_table, 0), _granted)
	_granted = 0


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


## The face slot the pending nudge turned from (0 if none is pending).
func nudged_from() -> int:
	return _from_slot


## Die index being picked (arrows shown), or -1.
func picking_die() -> int:
	return _picking


## True for a copy die (Mirror, Ferryman's Coin): never a Nerve target.
static func is_copy_die(d: TableDie) -> bool:
	return d.special == DiceIds.DIE_MIRROR or d.id == DiceIds.DIE_MIRROR \
		or d.id == DiceIds.DIE_FERRYMAN or d.special == DiceIds.DIE_FERRYMAN \
		or d.shape == DiceIds.SHAPE_COIN


## Why die [param die_index] can't be nudged, as a strings_v1 id
## (# nerve_v1): nerve_used_refusal, nerve_copy_refusal, nerve_potted_refusal
## (potted, or not in this throw because it was potted earlier), and with
## [param dir] (UP / DOWN) nerve_high_refusal / nerve_low_refusal at the end
## of the face list. "" when no string fits (index out of range, no settled
## throw, or this throw already closed by a pot) and when it can be nudged:
## use can_nudge() / can_nudge_dir() for yes / no.
func refusal(die_index: int, dir: int = 0) -> String:
	var why := _blocked(die_index)
	if why == "" and dir != 0 and target_slot(dice[die_index], slots[die_index], dir) <= 0:
		return "nerve_high_refusal" if dir > 0 else "nerve_low_refusal"
	return "" if why == _CLOSED else why


const _CLOSED := "_closed"


## refusal() without dir, plus _CLOSED for "no string fits".
func _blocked(die_index: int) -> String:
	if die_index < 0 or die_index >= dice.size():
		return _CLOSED
	if uses_left() <= 0:
		return "nerve_used_refusal"
	if is_copy_die(dice[die_index]):
		return "nerve_copy_refusal"
	if potted[die_index] or (_throw_open and slots[die_index] <= 0):
		return "nerve_potted_refusal"
	if not _throw_open:
		return _CLOSED
	return ""


## Face slots as the throw landed (begin_throw's input), before any nudge.
func landed_slots() -> Array[int]:
	return _landed.duplicate()


## True if die [param die_index] can be nudged now (Nerve left, an unpotted
## non-copy die from this throw, and at least one direction has a face).
func can_nudge(die_index: int) -> bool:
	return _blocked(die_index) == "" and (can_nudge_dir(die_index, UP) or can_nudge_dir(die_index, DOWN))


## True if die [param die_index] can go [param dir] (UP / DOWN) now; false at
## the end of its face list (no wrap). Greys out the arrow.
func can_nudge_dir(die_index: int, dir: int) -> bool:
	if _blocked(die_index) != "":
		return false
	return target_slot(dice[die_index], slots[die_index], dir) > 0


## Mod ids never auto-picked when another face with the same value lacks them:
## Blank (a curse) and the opt-in Blood face.
const AVOID_MOD_IDS: Array[StringName] = [&"blank", &"blood"]


## Every slot on die [param d] showing the next distinct printed value from
## [param slot] going [param dir] (no wrap), in face-list order; empty if none.
static func candidate_slots(d: TableDie, slot: int, dir: int) -> Array[int]:
	var out: Array[int] = []
	if slot < 1 or slot > d.face_count() or (dir != UP and dir != DOWN):
		return out
	var v := d.value_at(slot)
	var best_v := 0
	for k in range(1, d.face_count() + 1):
		var w := d.value_at(k)
		if (w - v) * dir <= 0:
			continue
		if out.is_empty() or (w - best_v) * dir < 0:
			out.clear()
			best_v = w
		if w == best_v:
			out.append(k)
	return out


## True if slot [param k] of [param d] carries a Blank or Blood mod.
static func is_avoided(d: TableDie, k: int) -> bool:
	var m := d.mod_at(k)
	return m != null and AVOID_MOD_IDS.has(m.id)


## Face slot die [param d] turns to from [param slot] going [param dir]
## without a scorer: the first non-Blank / non-Blood slot holding the next
## value, else the first such slot. 0 if there is none.
static func target_slot(d: TableDie, slot: int, dir: int) -> int:
	var c := candidate_slots(d, slot, dir)
	for k in c:
		if not is_avoided(d, k):
			return k
	return c[0] if not c.is_empty() else 0


## The slot die [param die_index] would turn to going [param dir] (0 if
## none). When the next value is on several faces (Powder Keg 1-1-2-2-3-3),
## Blank / Blood faces are dropped unless every candidate is one, then
## [param score_fn] (slots: Array -> int, the Wild best-value scorer, e.g.
## BonfireScoring.best_points on the throw) picks the best; ties and no
## score_fn go to the first slot in face-list order. No player pick.
func choose_slot(die_index: int, dir: int, score_fn: Callable = Callable()) -> int:
	var d := dice[die_index]
	var c := candidate_slots(d, slots[die_index], dir)
	var keep: Array[int] = []
	for k in c:
		if not is_avoided(d, k):
			keep.append(k)
	if keep.is_empty():
		keep = c
	if keep.is_empty():
		return 0
	if keep.size() == 1 or not score_fn.is_valid():
		return keep[0]
	var best := keep[0]
	var best_score := -1
	for k in keep:
		var trial := slots.duplicate()
		trial[die_index] = k
		var sc := int(score_fn.call(trial))
		if sc > best_score:
			best_score = sc
			best = k
	return best


## Nudges die [param die_index] one face in [param dir]; returns the new face
## slot, or -1 if refused. [param score_fn]: see choose_slot(). Nerve is then pending (undoable) until commit().
func nudge(die_index: int, dir: int, score_fn: Callable = Callable()) -> int:
	if not can_nudge_dir(die_index, dir):
		return -1
	var to := choose_slot(die_index, dir, score_fn)
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
func any_nudge_lights(lit_fn: Callable, score_fn: Callable = Callable()) -> bool:
	return not rescue_options(lit_fn, score_fn).is_empty()


## Every legal nudge that would light something: [{die, dir, slot}, ...];
## the slot is the one nudge() would pick with the same [param score_fn].
func rescue_options(lit_fn: Callable, score_fn: Callable = Callable()) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _nudged_die >= 0:
		return out
	for i in dice.size():
		for dir in [UP, DOWN]:
			if not can_nudge_dir(i, dir):
				continue
			var trial := slots.duplicate()
			trial[i] = choose_slot(i, dir, score_fn)
			if lit_fn.call(trial):
				out.append({"die": i, "dir": dir, "slot": trial[i]})
	return out
