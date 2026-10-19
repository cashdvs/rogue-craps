## Mirror Die: "rolls 1-6 normally, then takes the face of the nearest die
## still in the tray (ties go to the lower face). If no other die is in the
## tray, its own roll stands. The copy counts as a natural face." The tray =
## the dice of this throw (potted dice are out of it); only non-Mirror dice
## are copied (several Mirrors each copy the landed non-Mirror dice; a
## Mirror with no other die keeps its roll). Nearest by settled
## position; the copy shows the Mirror's own face with that value (so its
## own mod there, if any), and happens before anything lights. Several
## Mirrors copy the rolls as they landed.
class_name DieMirror
extends TableRule


func on_throw_landed(_run: BonfireRun, th: TableThrow) -> void:
	var landed := th.values.duplicate()
	for i in th.size():
		if th.special(i) != &"mirror":
			continue
		var best := -1
		var best_d := INF
		for j in th.size():
			if j == i or th.special(j) == &"mirror":
				continue
			var dist := 0.0
			if th.positions.size() == th.size():
				dist = th.positions[i].distance_to(th.positions[j])
			if best < 0 or dist < best_d - 0.0001 or (absf(dist - best_d) <= 0.0001 and landed[j] < landed[best]):
				best = j
				best_d = dist
		if best >= 0 and landed[best] != th.values[i]:
			th.set_value(i, landed[best], id)
