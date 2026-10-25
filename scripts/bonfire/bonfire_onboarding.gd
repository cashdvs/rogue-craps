## The Bonfire table's onboarding (design/onboarding_hints_v1.md): when the
## Table 1 tutorial runs, which hint to ask for at each table moment, the
## seeded tutorial throws, and where each hint points on screen.
##
## Bonfire3D owns one of these (`table.onboarding`) and calls an on_*()
## function at each moment (table start, a lit settle, a pick, a pot, a
## bank, a bust, a new hand). This node only ASKS: the hint panel itself
## (BonfireTutorial, `bhud.tutorial`) decides what shows and when.
class_name BonfireOnboarding
extends Node

## The table this runs on (set by Bonfire3D before the first new_run()).
var table: Bonfire3D

## Seeding is on (stops at the first unseeded throw, after hand 2, on Skip).
var seeding: bool = false
## The hand of the table (1 = first).
var seed_hand: int = 1
## Hand 1 reached a Hot Hand (hand 2 then isn't seeded).
var seed_hot_h1: bool = false
## Per throw this table: true if it was seeded (tests).
var seeded_throws: Array[bool] = []


# --- Who gets hints ---------------------------------------------------------------

## The GameSettings autoload, or null (tests without it).
func _settings() -> Node:
	return get_node_or_null("/root/GameSettings")


## The table plays Table 1's goal.
func _is_table_one() -> bool:
	var s := table.setup
	return s != null and s.goal != null and (s.goal == table.bonfire_tuning.table_goal or s.goal.display_name == "Table 1")


## The run's first table (setup.first_table; the sandbox counts as one), and
## it's Table 1. In a run every goal passes _is_table_one(), so first_table
## is what keeps the tutorial off the later tables.
func _is_first_table() -> bool:
	return table.setup != null and table.setup.first_table and _is_table_one()


## The Table 1 tutorial (TH hints + seeded throws) runs on this table.
func tutorial_wanted() -> bool:
	if table.tutorial_override >= 0:
		return table.tutorial_override == 1 and _is_first_table()
	if not hints_wanted():
		return false
	var gs := _settings()
	return _is_first_table() and not bool(gs.get("tutorial_seen"))


## Any hints on this table (Settings: Tutorial hints On/Off). Only the real
## game, never tests / tools (unless a test sets tutorial_override = 1): the
## table is the current scene (sandbox) or inside it (a run's RunScreen;
## same check as fix/full-run-pass-1, QA M2).
func hints_wanted() -> bool:
	if table.tutorial_override >= 0:
		return table.tutorial_override == 1
	var scene := table.get_tree().current_scene
	if scene == null or not (scene == table or scene.is_ancestor_of(table)):
		return false
	var gs := _settings()
	return gs != null and bool(gs.get("tutorial_enabled"))


## Asks the hint panel for hint `id` (BonfireTutorial.request). True if it
## showed now.
func hint(id: StringName, ctx: Dictionary = {}, still: Callable = Callable()) -> bool:
	return table.bhud != null and table.bhud.tutorial.request(id, ctx, still)


func _save_hints_seen(seen: Dictionary) -> void:
	var gs := _settings()
	if gs != null and gs.has_method("set_option") and table.tutorial_override < 0:
		gs.set_option(&"hints_seen", seen.duplicate())


# --- Table moments -------------------------------------------------------------------

## A new table (new_run): resets the hint panel and the seeds, starts the
## tutorial if wanted, then TH0, JIT5 and HB3.
func on_table_start() -> void:
	var tut := table.bhud.tutorial
	tut.visible = false
	tut.active = false
	tut.stopped = false
	tut.current = &""
	tut.enabled = hints_wanted()
	var gs := _settings()
	tut.touch = table.phone_screen != Vector2.ZERO or (gs != null and gs.has_method("is_mobile") and bool(gs.call("is_mobile")))
	tut.anchor_provider = anchor_rect
	if gs != null and gs.get("hints_seen") is Dictionary and table.tutorial_override < 0:
		tut.seen = (gs.get("hints_seen") as Dictionary).duplicate()
	if not tut.seen_changed.is_connected(_save_hints_seen):
		tut.seen_changed.connect(_save_hints_seen)
		tut.skipped.connect(func() -> void: seeding = false)
	seeding = false
	seed_hand = 1
	seed_hot_h1 = false
	seeded_throws.clear()
	if tutorial_wanted():
		tut.start()
		seeding = true
		if gs != null and gs.has_method("set_option") and table.tutorial_override < 0:
			gs.set_option(&"tutorial_seen", true)
		hint(&"th0_throw")
	# JIT5: an Elite / boss table (a twist or cheat rule) starts.
	var run := table.run
	if run != null and run.rules.any(func(r: TableRule) -> bool: return r.kind == TableRule.Kind.TWIST or r.kind == TableRule.Kind.CHEAT):
		hint(&"jit5_twist")
	_bonus_hint()


## A new hand starts: seeding covers hands 1 and 2 only; JIT1 on the last hand.
func on_hand_start() -> void:
	seed_hand += 1
	if seed_hand > 2:
		seeding = false
	var run := table.run
	if run == null or run.hands_left != 1 or run.is_over():
		return
	if run.goal.required.any(func(b: BountyData) -> bool: return not run.is_ticked(b)):
		hint(&"jit1_last", {"soul": run.soul_cost(run.goal.timeout_soul_per_bounty, &"timeout")})


## The dice settled and some lit: TH1 + TH2 on the first throw, then HB3.
func on_lit_settle() -> void:
	var run := table.run
	if seed_hand == 1 and run.throws_this_hand == 1:
		hint(&"th1_lit")
		hint(&"th2_pot", {}, func() -> bool: return run.state == BonfireRun.State.PICK and run.potted.is_empty())
	_bonus_hint()


## A Hot Hand: TH6 (and hand 2 won't be seeded).
func on_hot_hand() -> void:
	var run := table.run
	if seed_hand == 1:
		seed_hot_h1 = true
	hint(&"th6_hot", {"all": run.cold, "mult": run.mult_bonus() / maxi(run.hot_hands, 1)})


## A pot scores: HS2 for a sealed combo, JIT4 for the first Wild face
## (wild_die = its index in the throw, -1 = none).
func on_pot(combo: StringName, wild_die: int) -> void:
	if is_sealed(combo):
		hint(&"hs2_sealed", {})
	if wild_die >= 0:
		hint(&"jit4_wild", {"die": wild_die})


## A bank: TH7 for the first required card claimed, then TH8 (points), and
## TH10 when the clear leaves the bonus to chase.
func on_bank(r: Dictionary) -> void:
	var run := table.run
	for b: BountyData in run.goal.required:
		if (r["ticked"] as Array).has(b.id):
			hint(&"th7_claimed", {"card": b.id})
			break
	var tut := table.bhud.tutorial
	hint(&"th8_points", {}, func() -> bool: return int(tut.seen.get(&"th7_claimed", 0)) > 0)
	if r.get("cleared_now", false) and not run.is_over() and run.hands_left > 0 and run.goal.bonus.any(func(b: BountyData) -> bool: return not run.is_ticked(b)):
		hint(&"th10_cleared", {"card": (run.goal.bonus[0] as BountyData).id})


## A click on a die that can't join the pot: TH2b, now or never.
func on_refused(i: int) -> void:
	hint(&"th2b_nofit", {"die": i}, func() -> bool: return false)


## A bust: HB5 when it lost a pending card (TH9 stays unseen), else TH9.
func on_bust(soul_lost: int, lost_cards: Array) -> void:
	if not lost_cards.is_empty():
		hint(&"hb5_lost", {"card": lost_cards[0]})
	else:
		hint(&"th9_bust", {"soul": soul_lost})


## Nerve's bust rescue is waiting (nerve_v1.md): HN1, once per profile
## (hints_seen, like the other hints).
func on_nerve_rescue() -> void:
	hint(&"hn1_nerve")


## After a pick that leaves a valid pot: TH3 if it would claim a bounty
## (HB4 if a bigger combo claims it), TH4 when Bank and Rethrow are both on
## offer, TH5 (with the exact odds) when the rethrow would be 1-3 dice. One
## at a time: the later ones wait and show only if still true.
func on_selection() -> void:
	var t := table
	var run := t.run
	var claims := t.claimable_bounties()
	if not claims.is_empty():
		var id: StringName = (claims[0] as BountyData).id if claims[0] is BountyData else StringName(str(claims[0]))
		hint(&"th3_pending", {"card": id}, func() -> bool: return not t.claimable_bounties().is_empty())
		if not run.potted.is_empty():
			var sel := run.selection()
			var combo := StringName(sel.get("combo", &""))
			for c in claims:
				var b: BountyData = c if c is BountyData else _bounty(StringName(str(c)))
				if b != null and bounty_combo(b) != &"" and bounty_combo(b) != combo:
					hint(&"hb4_bigger", {"card": b.id, "card_name": b.display_name, "combo": str(sel.get("name", combo)),
						"run": b.kind == BountyData.Kind.RUN and String(combo).begins_with("run")},
						func() -> bool: return t.claimable_bounties().has(b))
					break
	var both := func() -> bool: return run.state == BonfireRun.State.PICK and run.can_continue() and t.next_throw_size() > 0
	if both.call():
		hint(&"th4_choice", {}, both)
	var small := func() -> bool:
		var k := t.next_throw_size()
		return run.state == BonfireRun.State.PICK and run.can_continue() and k >= 1 and k <= 3 and not run.is_hot()
	if small.call():
		t.rethrow_prompt()
		hint(&"th5_risk", {"n": t.next_throw_size(), "odds": BustRisk.odds_text(t.bust_chance())}, small)


## HB3: the bonus card is on screen and TH1 has been dismissed (or no
## tutorial runs on this table). Asked at table start and after each throw
## lights; shown once per profile.
func _bonus_hint() -> void:
	var run := table.run
	if run == null or run.goal == null or run.goal.bonus.is_empty() or run.is_over():
		return
	var tut := table.bhud.tutorial
	# On a tutorial table, after TH1; elsewhere right away.
	var ready := func() -> bool: return (not tut.active or int(tut.seen.get(&"th1_lit", 0)) > 0) and tut.current != &"th1_lit" and not run.is_over()
	if ready.call():
		hint(&"hb3_bonus", {"card": (run.goal.bonus[0] as BountyData).id}, ready)


# --- Bounties and Seals ----------------------------------------------------------

## The table's bounty with this id, or null.
func _bounty(id: StringName) -> BountyData:
	for b: BountyData in table.run.all_bounties():
		if b.id == id:
			return b
	return null


## The combo that exactly matches a bounty (Trips card = trips), so a
## bigger one claiming it (Quads, Full House) can be told apart (HB4).
static func bounty_combo(b: BountyData) -> StringName:
	match b.kind:
		BountyData.Kind.N_OF_A_KIND:
			return [&"single", &"pair", &"trips", &"quads", &"five_kind"][clampi(b.n, 1, 5) - 1]
		BountyData.Kind.RUN:
			return StringName("run%d" % b.n)
		BountyData.Kind.TWO_PAIR:
			return &"two_pair"
		BountyData.Kind.FULL_HOUSE:
			return &"full_house"
		BountyData.Kind.STRAIGHT_5:
			return &"run5"
	return &""


## Does the run hold a Seal for this combo? (Its combo in this table's
## tuning has more base or mult than the base tuning's: the run's Seal
## levels, RunTableSetup.leveled.)
func is_sealed(combo_id: StringName) -> bool:
	if table.setup == null or not table.setup.run_mode:
		return false
	var base := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	var mine: BonfireCombo = null
	var plain: BonfireCombo = null
	for c in table.bonfire_tuning.combos:
		if c.id == combo_id:
			mine = c
	for c in base.combos:
		if c.id == combo_id:
			plain = c
	return mine != null and plain != null and (mine.base > plain.base or mine.mult > plain.mult)


# --- Tutorial seeds (Table 1 only, tutorial on) ----------------------------------

## Before a throw: rigs the next seeded faces, if any. Returns true if this
## throw is seeded (seeding stops at the first throw without a seed).
func seed_next_throw() -> bool:
	if not seeding or table.run == null or table.run.state != BonfireRun.State.AIM:
		return false
	var f := tutorial_seed()
	if f.is_empty():
		seeding = false
		return false
	table.rig_faces(f)
	return true


## The faces for the next throw from BonfireTuning.tutorial_first_throw /
## tutorial_seeds, or [] (unseeded: seeding stops). Never a bust: a seed
## that would light nothing is not used.
func tutorial_seed() -> Array[int]:
	var out: Array[int] = []
	var run := table.run
	if not seeding or run == null or seed_hand > 2 or not _is_first_table():
		return out
	var hand := seed_hand
	var th := run.throws_this_hand + 1
	var n := table.dice.size()
	var t := table.bonfire_tuning
	if hand == 1 and th == 1:
		if t.tutorial_first_throw.size() == n:
			out.assign(t.tutorial_first_throw)
	elif not (hand == 2 and seed_hot_h1):
		for e: Dictionary in t.tutorial_seeds:
			if int(e.get("hand", 0)) != hand or int(e.get("throw", 0)) != th or int(e.get("dice", n)) != n:
				continue
			if bool(e.get("no_hot_hand", false)) and seed_hot_h1:
				continue
			if e.has("bounty"):
				var bid := StringName(e["bounty"])
				var b: BountyData = null
				for rb: BountyData in run.goal.required:
					if rb.id == bid:
						b = rb
				if b == null or run.is_ticked(b) or run.pending.has(bid):
					continue
			out.assign(e.get("faces", []))
			break
	if out.size() != n or BonfireScoring.lit_indices(out, t, run.rule_ctx()).is_empty():
		out.clear()
	return out


# --- Where hints point -------------------------------------------------------------

## Screen rect (HUD space) for a hint anchor (BonfireTutorial.HINTS).
func anchor_rect(anchor: StringName, ctx: Dictionary) -> Rect2:
	var t := table
	var bhud := t.bhud
	match anchor:
		&"hand":
			return _rect_of([t.hand_spot(0), t.hand_spot(1)])
		&"lit_dice", &"tray":
			var pts: Array[Vector3] = []
			for d in t.throw_dice:
				pts.append(d.global_position)
			return _rect_of(pts)
		&"refused_die", &"wild_die":
			var i := int(ctx.get("die", -1))
			if i >= 0 and i < t.throw_dice.size():
				return _rect_of([t.throw_dice[i].global_position])
		&"pot_preview":
			return bhud.countup.row.get_global_rect() if bhud.countup.is_playing() else bhud.throw_label.get_global_rect()
		&"pulsing_card", &"stamped_card", &"unclaimed_cards", &"bonus_leave", &"bonus_card", &"lost_card":
			var id := StringName(ctx.get("card", &""))
			if anchor == &"bonus_leave" and bhud.leave_button.visible:
				return bhud.leave_button.get_global_rect()
			if bhud.portrait_goal.visible:
				return bhud.portrait_goal.get_global_rect()
			if bhud.bounty_cards.has(id):
				return (bhud.bounty_cards[id] as Control).get_global_rect()
			return bhud.checklist_panel.get_global_rect()
		&"buttons":
			return bhud.bank_button.get_global_rect().merge(bhud.throw_button.get_global_rect())
		&"risk":
			# Beside the Throw button (the risk line under the pot says the same).
			return bhud.throw_button.get_global_rect()
		&"mult":
			return bhud.mult_label.get_global_rect()
		&"embers":
			return bhud.points_label.get_global_rect()
		&"soul":
			return t.reliquary_rect()
		&"rules":
			return bhud.rules_panel.get_global_rect()
	return Rect2()


## The screen rect around these table points (die-sized margin).
func _rect_of(points: Array[Vector3]) -> Rect2:
	var r := Rect2()
	var first := true
	for p in points:
		var sp := table.camera.cam.unproject_position(p + Vector3(0, table.tuning.die_size * 0.5, 0))
		if first:
			r = Rect2(sp, Vector2.ZERO)
			first = false
		else:
			r = r.expand(sp)
	return r.grow(table.tuning.die_size * 200.0) if not first else Rect2()
