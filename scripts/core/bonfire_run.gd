## Bonfire rules state (pure; the 3D scene only shows it).
## A hand: throw -> dice that can form a combo light -> pot ONE combo
## (exact match) -> BANK. No cold rethrow: THROW banks unless every die is
## potted (Hot Hand). Nothing lit =
## BUST (hand pot and pending bounty ticks lost, -Soul). All 5 potted in the
## hand = HOT HAND: all dice back, +1 mult on every later pot this hand.
## Table goal (TableGoal, table_goals_v1 PR1): bank `goal.target` points
## within the hands.
##
## Passing: the bank that reaches the target makes the table CLEARED
## (`cleared` = true, the clear Embers are paid right then) but it stays
## open: keep throwing for more points, or leave() between hands. A bust
## costs Soul as usual but never undoes the pass or banked points. When the
## hands run out a passed table ends as CLEARED; an unpassed one as FAILED
## (`goal.miss_soul`, which can end the run).
##
## Table rules (Elite twists, boss cheats, special-die abilities) are
## TableRule handlers (set_rules); every moment they hook is also emitted on
## `table_event` (hand_start, throw_landed, pot, bank, bust, die_shattered,
## kindling_saved, table_end) so juice / audio can subscribe to the same
## events.
class_name BonfireRun
extends BonfireRunState

# The state and read-only questions live in bonfire_run_state.gd
# (BonfireRunState); this file keeps the actions that change it.


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
	RareDiceRules.on_land(self, th)  # Land-effect faces (Fuse, Hex) on the final faces; rare_dice_v2 PR 2.
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
		if bust_hold.is_valid() and bool(bust_hold.call()):
			# Nerve can still save it (nerve_v1.md): wait for the player.
			bust_pending = true
			state = State.PICK
			return false
		_bust()
		return false
	free_rethrows_in_a_row = 0
	if not tuning.bounty_requires_pot and bounties_count():
		_add_pending(BonfireScoring.plain_values(throw_dice()))
	state = State.PICK
	return true


## The player declined the rescue: the pending bust happens now.
func confirm_bust() -> void:
	if not bust_pending:
		return
	bust_pending = false
	_bust()


## The same throw with some faces changed by the table (a Nerve nudge, then
## the copies re-run; nerve_v1.md §1): the lit check runs again on [param
## th], but no rule's on_throw_landed fires again (Madame doesn't reroll)
## and it is still the same throw. Returns true if something lit (a
## pending bust is then cancelled).
func relight(th: TableThrow) -> bool:
	if not tuning.bounty_requires_pot and bounties_count() and state == State.PICK and not bust_pending:
		for id in BonfireScoring.bounty_ticks(all_bounties(), BonfireScoring.plain_values(throw_dice())):
			pending[id] = maxi(int(pending.get(id, 0)) - 1, 0)
	throw_faces = th.values.duplicate()
	throw_mods = th.mods.duplicate()
	throw_mods.resize(throw_faces.size())
	last_throw = th
	# Dice already potted stay potted (Nerve can't turn them) unless the
	# new faces broke their combo (a potted Mirror followed the nudge).
	if not potted.is_empty() and not BonfireScoring.can_extend(potted, throw_dice(), tuning, rule_ctx()):
		potted.clear()
	state = State.PICK
	if lit().is_empty():
		# Nothing lights now (e.g. a lit 5 turned into a 4): the throw would
		# bust, so it waits like a rescue pause (undo, or take the bust).
		bust_pending = true
		return false
	bust_pending = false
	free_rethrows_in_a_row = 0
	if not tuning.bounty_requires_pot and bounties_count():
		_add_pending(BonfireScoring.plain_values(throw_dice()))
	return true


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


## True if throw die [param i] could be potted next: it is in the current
## throw, not potted yet, and fits the combo with the dice already potted.
## With nothing potted this is "die i lights" (VFX: joinable dice glow).
func can_join(i: int) -> bool:
	if state != State.PICK or i < 0 or i >= throw_faces.size() or potted.has(i):
		return false
	var next := potted.duplicate()
	next.append(i)
	return BonfireScoring.can_extend(next, throw_dice(), tuning, rule_ctx())


## "" if the current selection may be thrown on, else why not.
func rethrow_block_reason() -> String:
	if not can_continue():
		return "Pot at least one lit die first."
	if not is_hot():
		return "Bank it: only a Hot Hand throws again."
	if not hot_hand_allowed():
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


## Hot Hand only (no cold rethrow): pot every die and throw them all again.
## {} if not allowed, else {"hot": true, "cold": dice_count}.
func rethrow() -> Dictionary:
	if rethrow_block_reason() != "":
		return {}
	_commit_pot()
	cold = dice_count
	hot_hands += 1
	throw_faces.clear()
	throw_mods.clear()
	potted.clear()
	state = State.AIM
	return {"hot": true, "cold": cold}


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
	# The bank that reaches the target passes the table (table_goals_v1
	# PR1): the clear Embers are locked in now, and the table stays open.
	r["cleared_now"] = false
	if r["kind"] == &"bank" and not cleared and _goal_met():
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


## A target table (goal.target > 0, every map table in table_goals_v1
## PR1) is passed once the banked points reach it. A goal with no target
## (the standalone table's bonfire_tuning goal) keeps the bounty rule
## until PR3 removes bounties.
func _goal_met() -> bool:
	if goal.target > 0:
		return points >= goal.target
	return unticked_required() == 0


func _end_table(st: State) -> void:
	var converted := points_to_embers(tuning, points)
	# The clear Embers were already paid at the clearing bank (see _finish).
	var clear := goal.clear_embers if cleared else 0
	var soul_lost := 0
	if st == State.FAILED:
		soul_lost = soul_cost(goal.miss_soul if goal.target > 0 else unticked_required() * goal.timeout_soul_per_bounty, &"timeout")  # can end the run
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


## Leave a cleared table between hands: it ends as CLEARED (points convert,
## no timeout penalty). False if not allowed right now (see can_leave).
func leave() -> bool:
	if not can_leave():
		return false
	_end_table(State.CLEARED)
	last_result = {"kind": &"leave", "state": state, "points": points, "soul": soul}
	return true


## Give up the table (run mode): ends it like running out of hands
## (the goal's miss Soul, points still convert to
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
