## The table's event surface: plain signals the VFX / audio side listens to
## without editing table code. The table owns one (Table3D.events, so
## `table.events`) and emits each signal at the moment it happens. The table plays no sound for
## dice_thrown, die_impact, hot_hand, no_score or table_cleared: the
## listener in scripts/fx/ (TableAudio, PR #72) does.
##
##   table.events.bust.connect(func(soul_loss: int, die_ids: Array) -> void: ...)
##
## Die ids are Table3D.event_id(die): the die's place in the starting
## handful, stable for the table (DieVisual.die_id is only the index into
## the dice in play). Signals carry no nodes: table.die_by_id(id) finds one.
class_name TableEvents
extends Node

## A throw left the hand (the throw sound). flick_speed_px_s: the raw flick
## in game (canvas) px/s, the value launch_for() uses.
signal dice_thrown(flick_speed_px_s: float)
## A rolling die hit something (the impact sound, after the per-die speed
## floor and interval filters). kind: &"felt", &"rail", &"backboard",
## &"die", &"chip", &"puck". material: the die's material id.
signal die_impact(kind: StringName, speed_mps: float, material: StringName, die_id: int)
## Every die of the throw has come to rest (the settle sound).
signal dice_settled()
## A die turned lit (glows ember: it can score) or back off (plain, cold or
## potted out). Only on a change.
signal die_lit_changed(die_id: int, lit: bool)
## A pot was committed (rethrow or bank): its combo, the potted dice, the
## pot's points, its mult (Hot Hand bonus included) and its score tier (0-4,
## JuicePlan.tier: the tier the count-up escalates to).
signal combo_potted(combo_id: StringName, die_ids: Array, points: int, mult: int, score_tier: int)
## Hot Hand: every die scored and they fly back to the hand. Fires at fly
## START with the dice (event ids) and the flight time in seconds (0.05 under
## Instant, shorter under reduced motion).
signal hot_hand_fly(die_ids: Array, seconds: float)
## Hot Hand: the dice ARRIVE back in the hand (hot_hand_fly + seconds).
## count: Hot Hands this hand.
signal hot_hand(count: int)
## A picked die was refused: it can't join the combo ("doesn't score").
signal no_score()
## The hand burned. soul_loss: Soul it cost (after the rules, e.g. the
## Bloodletter's x2) and the dice of the busted throw (event ids).
signal bust(soul_loss: int, die_ids: Array)
## A bank: the points it added.
signal banked(points: int)
## A bounty's CLAIMED stamp lands (one per bounty, in stamp order).
signal bounty_claimed(bounty_id: StringName)
## A table begins (new_run: first open, a new setup, a sandbox restart).
## Listeners reset per-table guards here.
signal table_started()
## The table is cleared: the TABLE CLEARED banner (bank that clears it) or
## Leave table. Exactly once per table (between two table_started).
signal table_cleared()
## Table goals (#222): the bank that reaches a target table's goal
## (goal.target > 0). Fires once, just before table_cleared, so the goal
## sting can stand in for the TABLE CLEARED cue. A bounty table (no target)
## sends only table_cleared.
signal goal_reached()
## Table goals (#222): a target table ended short of its target (out of
## hands, or given up). soul_loss: the Soul the miss really cost, after the
## rules (e.g. the Bloodletter's x2), the same number the Soul meter loses.
signal goal_missed(soul_loss: int)
## A boss cheat changed dice after they settled (e.g. Madame Shuffle's
## reroll): its rule id and the dice it touched.
signal boss_cheat(cheat_id: StringName, die_ids: Array)
## Nerve (nerve_v1.md): the player turned die `die_id` (event id) from face
## slot `from_face` to `to_face` (1-based, TableDie slots); dir = +1 up or
## -1 down. An undo emits it again with the faces swapped and dir reversed.
signal die_nudged(die_id: int, from_face: int, to_face: int, dir: int)
## Nerve: a pending nudge was kept for good (NerveState.commit() spent it on
## a pot, rethrow or bank, including a rescue-save). Faces are 1-based face
## slots, like die_nudged. Fires once per spent nudge; never on undo, and
## never when no nudge was pending.
signal nerve_spent(die_id: int, from_face: int, to_face: int)
## A face mod scored during the count-up, as the count reaches its die (its
## first pip). row_id: the mod id (its row in the mods table). tier: the
## pot's score tier (0-4, JuicePlan.tier). intensity: 0..1 (tier / 4).
## hit_ms: when it hit, Time.get_ticks_msec(). anchor: where the effect
## sits, &"pip" (the count-up pip of that die). ctx: {flavor: StringName
## (the effect, e.g. &"mult_factor", &"twin", &"wild"), target_die: int (the
## die it acts on; its own id for face mods), count: int (pips it adds: 2
## for Twin, else 1), direction: int (+1 adds, -1 takes away, 0 neutral)}.
signal mod_triggered(row_id: StringName, tier: int, die_id: int, intensity: float, hit_ms: int, anchor: StringName, ctx: Dictionary)
## Every trigger of a resolve step, in resolve order: land, copies, boss,
## lit check, scoring. Emitted twice per throw that scores:
## - when a throw settles (before any face flips): stages &"land" (die
##   specials acting on landing), &"copies" (Mirror copies), &"boss" (cheat
##   face changes) and &"lit" (the lit check: &"kindling_saved", &"bust",
##   or each die a rule keeps dark). start_s is from this emit: changes all
##   start at 0 and flip for 0.3 s (Bonfire3D.FLIP_TIME); the lit check starts after
##   the flips (FLIP_TIME + 0.08) or at 0 if nothing changed.
## - when a pot is committed, BEFORE its count-up is planned and played:
##   stage &"scoring", one entry per mod face, in pip order. start_s is from
##   the count-up start: the die's pip tick time (pip_s) minus 0.167 s, so an
##   effect lands on the tick; clamped at 0 (the first pip ticks at 0).
##   pip_s = JuicePlan pip time / the count-up clock (test_speed). Normal
##   speed: pip gap, Fast x0.5, Instant all 0. lift_s: when that die's lift
##   starts (index x 0.08 s, 0.14 s on a big pot, / the clock).
## Entry: {stage, row_id, tier, die_id, intensity, anchor, ctx, start_s}
## (+ pip_s, lift_s on scoring). Same ctx keys as mod_triggered.
signal triggers_resolved(triggers: Array)

## The pot selection changed: after a pot or unpot (pick_die), when a throw
## resolves, and after a Nerve nudge or undo. Both arrays hold die event ids
## (Table3D.event_id): the potted dice, and the dice that could join them
## (BonfireRun.can_join). Empty arrays when not picking.
signal selection_changed(potted_ids: Array, joinable_ids: Array)

## Seconds an effect starts before its pip tick (triggers_resolved).
const PIP_LEAD := 0.167


func _init() -> void:
	name = "TableEvents"


## Sends goal_missed when this run's target table ends without reaching its
## goal. Bonfire3D calls it once for each new run. (The run decides the end
## and the Soul it costs; this only passes the news on.)
func watch_goal(run: BonfireRun) -> void:
	run.table_event.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind != &"table_end" or run.goal.target <= 0:
			return
		# FAILED, or RUN_OVER because the miss took the last Soul.
		var lost := int(run.table_summary.get("timeout_soul", 0))
		if data.get("state") == BonfireRun.State.FAILED or lost > 0:
			goal_missed.emit(lost))
