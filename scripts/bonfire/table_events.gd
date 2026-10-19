## The table's event surface: plain signals the VFX / audio side listens to
## without editing table code. The table owns one (Table3D.events, so
## `table.events`) and emits each signal at the same moment as the matching
## sfx call (those sfx calls stay for now; listeners replace them later).
##
##   table.events.bust.connect(func(soul_loss: int) -> void: ...)
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
## pot's points and its mult (Hot Hand bonus included).
signal combo_potted(combo_id: StringName, die_ids: Array, points: int, mult: int)
## Hot Hand: every die scored, all come back. count: Hot Hands this hand.
signal hot_hand(count: int)
## A picked die was refused: it can't join the combo ("doesn't score").
signal no_score()
## The hand burned. soul_loss: Soul it cost (after the rules, e.g. the
## Bloodletter's x2).
signal bust(soul_loss: int)
## A bank: the points it added.
signal banked(points: int)
## A bounty's CLAIMED stamp lands (one per bounty, in stamp order).
signal bounty_claimed(bounty_id: StringName)
## The table is cleared (the TABLE CLEARED banner, or Leave table on a clear).
signal table_cleared()
## A boss cheat changed dice after they settled (e.g. Madame Shuffle's
## reroll): its rule id and the dice it touched.
signal boss_cheat(cheat_id: StringName, die_ids: Array)
## A face mod scored during the count-up, as the count reaches its die.
## row_id: the mod id (its row in the mods table). tier: the pot's score
## tier (0-4, JuicePlan.tier). intensity: 0..1 (tier / 4). hit_ms: when it
## hit, Time.get_ticks_msec(), so a listener can line up with the count.
signal mod_triggered(row_id: StringName, tier: int, die_id: int, intensity: float, hit_ms: int)


func _init() -> void:
	name = "TableEvents"
