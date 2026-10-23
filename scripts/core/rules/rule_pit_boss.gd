## The Pit Boss (boss): "Each hand, one number from 2 to 6 never lights." A value drawn at
## the start of every hand (seeded) never lights or scores that hand; it is
## shown on the felt. params.faces (default 1-6): the values it draws from.
class_name RulePitBoss
extends TableRule

var locked: int = 0


func on_hand_start(run: BonfireRun) -> void:
	var pool: Array = param("faces", [1, 2, 3, 4, 5, 6])
	locked = int(pool[run.rng.randi_range(0, pool.size() - 1)])


func can_light(_run: BonfireRun, value: int) -> bool:
	return value != locked


func info_line(_run: BonfireRun) -> String:
	return "%s Locked this hand: %d." % [description, locked]


func felt_text(_run: BonfireRun) -> String:
	return "LOCKED  %d" % locked
