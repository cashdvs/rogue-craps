## Nerve on the table (design/nerve_v1.md): once per table the player turns
## one settled die one face up or down. NerveState (scripts/core) owns the
## rules (uses, which dice, undo); this node is the glue between it, the
## BonfireRun and the 3D dice:
##   - after a throw lands it opens the throw on NerveState (begin_throw);
##   - a nudge re-runs the copy dice (Mirror, Ferryman) and the lit check
##     with the boss filters, but no boss cheat fires again (Madame Shuffle
##     doesn't reroll), then turns the dice on the felt (DieVisual.set_face);
##   - when a throw would bust but a nudge would light something, the run
##     waits (BonfireRun.bust_hold) and the HUD offers the rescue.
## NerveState counts dice by "handful id" (the die's place in the table's
## dice, setup.dice); the run counts by its place in this throw. hid() and
## index_of() turn one into the other.
class_name NerveTable
extends Node

## Anything shown changed (uses, picking, a nudge, the rescue pause).
signal changed

## Drag on a die this far (pixels, up or down) and it is a nudge.
const DRAG_PX: float = 28.0

## The Bonfire3D table (untyped: the two scripts refer to each other).
var table: Node
var run: BonfireRun
var state: NerveState = NerveState.new()
## The slots the dice physically landed on, before any rule (throw index ->
## slot), set by the table just before land_throw. Only read once, when the
## throw opens: a copy die's landed slot goes into NerveState (it can't be
## nudged), so NerveState.landed_slots() is where copies re-copy from.
var landed: Array[int] = []
## The throw the run landed (rules applied); nudges start from it.
var base: TableThrow
## True once a die was potted this throw: Nerve is closed until the next
## throw (nudges and undo refused with nerve_potted_refusal).
var pot_closed: bool = false
## True after the Nerve button: the next die click picks a die to turn.
var armed: bool = false
## The throw index whose arrows are showing (-1 = none).
var arrows_die: int = -1
## A press on a die that may become a drag: its throw index and position.
var _press_die: int = -1
var _press_at: Vector2 = Vector2.ZERO


## A new table: [param uses] Nerves (setup.nerve_uses, 1 by default).
func start(t: Node, r: BonfireRun, table_dice: Array[TableDie], uses: int) -> void:
	table = t
	run = r
	state = NerveState.new()
	state.setup(table_dice, uses)
	run.bust_hold = _on_bust_hold
	base = null
	_close_ui()
	changed.emit()


# --- Indices ---------------------------------------------------------------

## Throw index -> handful id (NerveState's die index).
func hid(i: int) -> int:
	if i < 0 or i >= table.throw_dice.size():
		return -1
	return int(table.throw_dice[i].get_meta(&"handful_id", i))


## Handful id -> throw index (-1 if that die isn't in this throw).
func index_of(h: int) -> int:
	for i in table.throw_dice.size():
		if hid(i) == h:
			return i
	return -1


# --- Throw lifecycle ---------------------------------------------------------

## The run just landed [param th]: open it for Nerve.
func open_throw(th: TableThrow) -> void:
	base = th
	var by_hid: Array[int] = []
	by_hid.resize(state.dice.size())  # 0 = not in this throw
	for i in th.size():
		var h := hid(i)
		if h >= 0 and h < by_hid.size():
			var td := th.die(i)
			var copy := td != null and NerveState.is_copy_die(td) and i < landed.size()
			by_hid[h] = landed[i] if copy else th.slots[i]
	pot_closed = false
	state.begin_throw(by_hid)
	# Deferred: the table moves to its waiting phase later this frame.
	changed.emit.call_deferred()


## Rethrow or bank: a pending nudge is kept for good.
func close_throw() -> void:
	_commit(func() -> void: state.commit())
	base = null
	_close_ui()
	changed.emit()


## A die went into the pot or came back out (BonfireRun.toggle). Any
## completed pot closes Nerve for this throw (nerve_v1.md lines 10-11): a
## pending nudge is spent (mark_potted commits) and no new nudge or undo is
## allowed, even after the die is unpotted. Presses and drags never pot
## (handle_input decides on release), so only a real pot gets here.
func on_potted() -> void:
	if not run.potted.is_empty():
		pot_closed = true
		for i in run.potted:
			var h := hid(i)
			if h >= 0:
				_commit(func() -> void: state.mark_potted(h))
	changed.emit()


## Runs [param do_commit] (a NerveState commit) and, if it spent a pending
## nudge, emits table.events.nerve_spent once. The nudge is read first,
## because commit() clears it.
func _commit(do_commit: Callable) -> void:
	var h := state.nudged_die()
	if h < 0:
		do_commit.call()  # nothing pending: nothing to report
		return
	var from := state.nudged_from()
	var to := state.slots[h]
	var i := index_of(h)
	var id: int = table.event_id(table.throw_dice[i]) if i >= 0 else h
	do_commit.call()
	if state.nudged_die() < 0:  # the nudge is spent now
		table.events.nerve_spent.emit(id, from, to)


## BonfireRun.bust_hold: the throw lit nothing. Hold the bust if a nudge
## would light something.
func _on_bust_hold() -> bool:
	open_throw(run.last_throw)
	return state.any_nudge_lights(lights, score)


## True while Nerve can be seen: a settled throw waiting for the player
## (not during the boss intro, the roll or the count-up).
func can_show() -> bool:
	return base != null and run != null and not run.is_over() \
			and table.phase == Table3D.Phase.BET and run.state == BonfireRun.State.PICK


# --- The lit check after a nudge ---------------------------------------------

## NerveState's lit_fn: does anything light with these faces (by handful id)?
func lights(slots_by_hid: Array) -> bool:
	return not lit_of(throw_for(slots_by_hid)).is_empty()


## The throw with these faces: copies re-run from where they landed.
func throw_for(slots_by_hid: Array) -> TableThrow:
	var at_land := state.landed_slots()
	var vals: Array[int] = []
	var sl: Array[int] = []
	var mods: Array = []
	for i in base.size():
		var td := base.die(i)
		var h := hid(i)
		var s: int = int(slots_by_hid[h]) if h >= 0 and h < slots_by_hid.size() else base.slots[i]
		if td != null and NerveState.is_copy_die(td) and h >= 0 and h < at_land.size():
			s = at_land[h]  # a copy die copies again from scratch
		sl.append(s)
		vals.append(td.value_at(s) if td != null else s)
		mods.append(td.mod_at(s) if td != null else null)
	var th := TableThrow.make(vals, mods, base.dice, base.rng)
	th.slots = sl
	th.positions = base.positions.duplicate()
	# Only the copy dice run again: no boss cheat fires twice.
	for r in run.rules:
		if r is DieMirror or r is DieFerryman:
			r.on_throw_landed(run, th)
	return th


## Lit throw indices of [param th], boss filters included (rule_ctx).
func lit_of(th: TableThrow) -> Array[int]:
	var saved := run.throw_faces.duplicate()
	var lit := RuleMadameShuffle.lit_now(run, th)
	run.throw_faces = saved
	return lit


## Best single pot of [param th] (0 = nothing lights).
func points_of(th: TableThrow) -> int:
	var dice: Array = []
	for i in th.size():
		dice.append(BonfireScoring.make_die(th.values[i], th.mods[i], th.special(i)))
	var saved := run.throw_faces.duplicate()
	run.throw_faces = th.values.duplicate()
	var best := BonfireScoring.best_points(dice, run.tuning, run.mult_bonus(), run.rule_ctx())
	run.throw_faces = saved
	return best


## NerveState's score_fn: the best single pot with these faces (by handful
## id), with the same rule_ctx as the lit check. NerveState uses it to pick
## among faces showing the same value (Powder Keg): best score wins, a tie
## goes to the first slot, Blank / Blood faces only if nothing else.
func score(slots_by_hid: Array) -> int:
	return points_of(throw_for(slots_by_hid))


# --- Player actions ----------------------------------------------------------

## The Nerve button: the next die click picks the die to turn.
func arm() -> bool:
	if pot_closed:
		refuse("nerve_potted_refusal")
		return false
	if not can_show() or state.uses_left() <= 0:
		refuse("nerve_used_refusal")
		return false
	armed = true
	changed.emit()
	return true


## Turns throw die [param i] one face [param dir] (NerveState.UP / DOWN).
## Returns the new face slot, or -1 (refused; the reason is shown).
func nudge(i: int, dir: int) -> int:
	var h := hid(i)
	if not can_show() or h < 0:
		return -1
	if pot_closed or run.potted.has(i):
		refuse("nerve_potted_refusal")
		return -1
	if not state.can_nudge_dir(h, dir):
		refuse(state.refusal(h, dir))
		return -1
	var from := state.slots[h]
	var to := state.nudge(h, dir, score)
	if to < 0:
		return -1
	_apply()
	table.events.die_nudged.emit(table.event_id(table.throw_dice[i]), from, to, dir)
	table._set_why(NerveText.get_text("nerve_undo"))
	return to


## Undoes the pending nudge on throw die [param i]; true if there was one.
func undo(i: int) -> bool:
	if pot_closed:
		refuse("nerve_potted_refusal")
		return false
	var h := hid(i)
	var from := state.slots[h] if h >= 0 else 0
	var back := state.undo(h) if h >= 0 else -1
	if back < 0:
		return false
	_apply()
	var dir := NerveState.DOWN if from > back else NerveState.UP
	table.events.die_nudged.emit(table.event_id(table.throw_dice[i]), from, back, dir)
	return true


## True while a nudge can still be undone (nothing potted, no rethrow).
func can_undo() -> bool:
	return can_show() and not pot_closed and state.nudged_die() >= 0


## Undoes the pending nudge, whichever die it is on. True if it did.
func undo_pending() -> bool:
	if not can_undo():
		return false
	return undo(index_of(state.nudged_die()))


## The Nerve token (the pip, or the rescue prompt's Nerve button): undo a
## pending nudge, otherwise arm Nerve for a pick.
func token_pressed() -> bool:
	if can_undo():
		return undo_pending()
	return arm()


## A click on settled die [param i]. Returns true if Nerve used it (then
## the table doesn't pot it): the nudged die (undo), or a die picked after
## the Nerve button or in the rescue pause (shows the arrows).
func tap(i: int) -> bool:
	if not can_show():
		return false
	var h := hid(i)
	# Tapping the nudged die pots it with its new face (nerve_v1.md, Oct 24
	# ruling): return false so the table's normal pot runs. Undo lives on
	# the Nerve token (token_pressed) and Backspace / Z.
	if h >= 0 and state.nudged_die() == h:
		return false
	if not armed and not run.bust_pending:
		return false
	if pot_closed or run.potted.has(i):
		refuse("nerve_potted_refusal")
	elif state.pick(h):
		armed = false
		arrows_die = i
	else:
		refuse(state.refusal(h))
	changed.emit()
	return true


## Mouse / keys while the throw waits. True if Nerve handled the event.
##   - a press on a die only remembers it: nothing is potted yet, because
##     a drag may follow (QA, #126);
##   - its release decides: moved DRAG_PX or more up / down = a nudge;
##     less = a tap (undo, a pick after the Nerve button) or, if Nerve has
##     no use for it, the table's normal pot;
##   - Up / Down keys while the arrows show: nudge that die.
func handle_input(event: InputEvent) -> bool:
	if not can_show():
		_press_die = -1
		return false
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_press_die = table.die_at_screen(mb.position)
			_press_at = mb.position
			return _press_die >= 0
		var was := _press_die
		_press_die = -1
		if was < 0:
			return false
		var dy := _press_at.y - mb.position.y
		if absf(dy) >= DRAG_PX:
			nudge(was, NerveState.UP if dy > 0 else NerveState.DOWN)
		elif not tap(was):
			table.pick_die(was)
		return true
	var key := event as InputEventKey
	# Backspace / Z on PC: the same undo as the Nerve token.
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_BACKSPACE or key.keycode == KEY_Z):
		return undo_pending()
	if key != null and key.pressed and not key.echo and arrows_die >= 0:
		if key.keycode == KEY_UP or key.keycode == KEY_DOWN:
			nudge(arrows_die, NerveState.UP if key.keycode == KEY_UP else NerveState.DOWN)
			return true
		if key.keycode == KEY_ESCAPE:
			state.cancel_pick()
			_close_ui()
			changed.emit()
			return true
	return false


## The rescue's Bust button: take the bust now.
func take_bust() -> void:
	if not run.bust_pending:
		return
	_close_ui()
	base = null
	changed.emit()
	table.nerve_bust()


## Shows a refusal (a strings_v1 id) as a callout and the why line.
func refuse(id: String) -> void:
	var text := NerveText.get_text(id)
	if text == "":
		return
	table._refuse(text)  # the why line (a big flash ran off-screen: QA #126)


func _close_ui() -> void:
	armed = false
	arrows_die = -1
	_press_die = -1


# --- After a nudge or undo ----------------------------------------------------

## Re-runs copies and the lit check for NerveState's faces, turns the dice
## on the felt and refreshes their lit / cold look.
func _apply() -> void:
	# Any nudge or undo uses up an armed press: a drag nudge after pressing
	# Nerve must not leave later taps going to state.pick.
	armed = false
	var th := throw_for(state.slots)
	run.relight(th)
	arrows_die = -1
	var animate: bool = not table.reduced_motion and table.speed_mode != 2
	for i in th.size():
		var shown: int = table.throw_slots[i] if i < table.throw_slots.size() else 0
		if th.slots[i] != shown:
			show_face(i, th.slots[i], animate)
	var lit := run.lit()
	for i in table.throw_dice.size():
		if run.potted.has(i):
			continue
		if i in lit:
			table._set_lit(table.throw_dice[i], true)
		else:
			table._set_cold(table.throw_dice[i])
	table.last_values = run.throw_faces.duplicate()
	table._refresh_hud()
	changed.emit()


## Turns throw die [param i] to face [param slot] on the felt and keeps the
## table's face bookkeeping (throw_slots, the d6 remap) in step.
func show_face(i: int, slot: int, animate: bool) -> void:
	var d: DieVisual = table.throw_dice[i]
	var q := d.set_face(slot, animate)
	if i < table.throw_slots.size():
		table.throw_slots[i] = slot
	var k: int = table.dice.find(d)
	if k >= 0 and k < table._remap_to.size():
		table._remap_from[k] = q
		table._remap_to[k] = q
