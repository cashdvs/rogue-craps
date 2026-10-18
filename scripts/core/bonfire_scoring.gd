## Pure Bonfire scoring (no nodes, no state). Numbers come from BonfireTuning.
##   score_selection(faces) -> {points, valid, all_used}: a selection is valid
##     only if EVERY die in it contributes (no dead dice) and it scores > 0.
##   lit_indices(faces): which dice of a throw can score (they catch fire).
##   groups(faces): how lit dice pot together: a 2/3/4/6 set (3+ of a kind) is
##     one group, 1s and 5s are singles, a run is one group of all five.
class_name BonfireScoring
extends RefCounted


static func _counts(faces: Array) -> Array[int]:
	var c: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for f in faces:
		c[clampi(int(f), 1, 6)] += 1
	return c


## Points for a run, or 0 if `faces` isn't exactly 1-5 or 2-6.
static func run_points(faces: Array, t: BonfireTuning) -> int:
	if faces.size() != 5:
		return 0
	var c := _counts(faces)
	var low := true
	var high := true
	for f in range(1, 6):
		low = low and c[f] == 1
	for f in range(2, 7):
		high = high and c[f] == 1
	if low:
		return t.run_low
	if high:
		return t.run_high
	return 0


static func score_selection(faces: Array, t: BonfireTuning) -> Dictionary:
	if faces.is_empty():
		return {"points": 0, "valid": false, "all_used": true}
	var run := run_points(faces, t)
	if run > 0:
		return {"points": run, "valid": true, "all_used": true}
	var c := _counts(faces)
	var points := 0
	var all_used := true
	for f in range(1, 7):
		var n := c[f]
		if n == 0:
			continue
		if n >= 3:
			points += t.kind_value(f, n)
		elif f == 1:
			points += n * t.single_one
		elif f == 5:
			points += n * t.single_five
		else:
			all_used = false
	return {"points": points, "valid": all_used and points > 0, "all_used": all_used}


## Pot groups in a throw: Array of Array[int] (die indices). Dice not in any
## group are cold.
static func groups(faces: Array, t: BonfireTuning) -> Array:
	var out: Array = []
	if run_points(faces, t) > 0:
		var all: Array[int] = []
		for i in faces.size():
			all.append(i)
		out.append(all)
		return out
	var c := _counts(faces)
	for f in range(1, 7):
		var idx: Array[int] = []
		for i in faces.size():
			if int(faces[i]) == f:
				idx.append(i)
		if idx.is_empty():
			continue
		if f == 1 or f == 5:
			for i in idx:
				out.append([i] as Array[int])
		elif c[f] >= 3:
			out.append(idx)
	return out


static func lit_indices(faces: Array, t: BonfireTuning) -> Array[int]:
	var lit: Array[int] = []
	for g in groups(faces, t):
		for i in g:
			lit.append(i)
	lit.sort()
	return lit


## Best score this throw could make (0 = bust).
static func best_points(faces: Array, t: BonfireTuning) -> int:
	var sel: Array = []
	for i in lit_indices(faces, t):
		sel.append(faces[i])
	return int(score_selection(sel, t)["points"]) if not sel.is_empty() else 0
