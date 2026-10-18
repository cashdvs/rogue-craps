## Pure Bonfire scoring and bounty detection (no nodes, no state).
##   score_selection(faces): a pot scores as exactly ONE combo: the
##     highest-ranked combo that EXACTLY matches the potted dice;
##     points = (base + sum of faces) x (mult + mult_bonus).
##   lit_indices(faces): dice that are part of ANY combo in the throw.
##   can_extend(sel, faces): the selection can still grow into a combo.
##   bounty_contains / bounty_ticks: which bounties a set of dice contains.
class_name BonfireScoring
extends RefCounted


static func _counts(faces: Array) -> Array[int]:
	var c: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for f in faces:
		c[clampi(int(f), 1, 6)] += 1
	return c


## Sorted counts of the faces that appear (e.g. [3, 2] for a full house).
static func _shape(faces: Array) -> Array[int]:
	var s: Array[int] = []
	for v in _counts(faces):
		if v > 0:
			s.append(v)
	s.sort()
	s.reverse()
	return s


static func _is_run(faces: Array, length: int) -> bool:
	if faces.size() != length:
		return false
	var s := faces.duplicate()
	s.sort()
	for i in range(1, s.size()):
		if int(s[i]) != int(s[i - 1]) + 1:
			return false
	return true


## Does `faces` EXACTLY form combo `c`?
static func matches(c: BonfireCombo, faces: Array) -> bool:
	match c.kind:
		BonfireCombo.Kind.SINGLE:
			return faces.size() == 1 and c.single_faces.has(int(faces[0]))
		BonfireCombo.Kind.N_OF_A_KIND:
			return faces.size() == c.n and _shape(faces) == [c.n]
		BonfireCombo.Kind.RUN:
			return _is_run(faces, c.n)
		BonfireCombo.Kind.TWO_PAIR:
			return faces.size() == 4 and _shape(faces) == [2, 2]
		BonfireCombo.Kind.FULL_HOUSE:
			return faces.size() == 5 and _shape(faces) == [3, 2]
	return false


## The highest-ranked combo exactly matching `faces` (null if none).
static func match_combo(faces: Array, t: BonfireTuning) -> BonfireCombo:
	if faces.is_empty():
		return null
	for k in range(t.combos.size() - 1, -1, -1):
		if matches(t.combos[k], faces):
			return t.combos[k]
	return null


static func score_selection(faces: Array, t: BonfireTuning, mult_bonus: int = 0) -> Dictionary:
	var c := match_combo(faces, t)
	var sum := 0
	for f in faces:
		sum += int(f)
	if c == null:
		return {"valid": false, "all_used": false, "points": 0, "combo": &"", "name": "", "base": 0, "faces_sum": sum, "mult": 0}
	var mult := c.mult + mult_bonus
	return {"valid": true, "all_used": true, "points": (c.base + sum) * mult, "combo": c.id, "name": c.display_name,
		"base": c.base, "faces_sum": sum, "mult": mult}


## "(base + faces) x mult = N" for the HUD.
static func formula(s: Dictionary) -> String:
	if not s.get("valid", false):
		return ""
	return "%s  (%d + %d) x %d = %d" % [s["name"], s["base"], s["faces_sum"], s["mult"], s["points"]]


## Every subset of the throw (as index arrays) that exactly forms a combo.
static func matching_subsets(faces: Array, t: BonfireTuning) -> Array:
	var out: Array = []
	var n := faces.size()
	for mask in range(1, 1 << n):
		var idx: Array[int] = []
		var sub: Array = []
		for i in n:
			if mask & (1 << i):
				idx.append(i)
				sub.append(faces[i])
		if match_combo(sub, t) != null:
			out.append(idx)
	return out


static func lit_indices(faces: Array, t: BonfireTuning) -> Array[int]:
	var lit: Array[int] = []
	for s in matching_subsets(faces, t):
		for i in s:
			if not lit.has(i):
				lit.append(i)
	lit.sort()
	return lit


## True if the selected indices are part of some combo subset of the throw.
static func can_extend(sel: Array, faces: Array, t: BonfireTuning) -> bool:
	if sel.is_empty():
		return true
	for s in matching_subsets(faces, t):
		var ok := true
		for i in sel:
			if not (s as Array).has(i):
				ok = false
				break
		if ok:
			return true
	return false


## Best single-pot score available in the throw (0 = bust).
static func best_points(faces: Array, t: BonfireTuning, mult_bonus: int = 0) -> int:
	var best := 0
	for s in matching_subsets(faces, t):
		var sub: Array = []
		for i in s:
			sub.append(faces[i])
		best = maxi(best, int(score_selection(sub, t, mult_bonus)["points"]))
	return best


# --- Bounties --------------------------------------------------------------------

## Does `faces` CONTAIN the bounty's pattern (extra dice are fine)?
static func bounty_contains(b: BountyData, faces: Array) -> bool:
	var c := _counts(faces)
	match b.kind:
		BountyData.Kind.N_OF_A_KIND:
			for f in range(1, 7):
				if (b.face == 0 or b.face == f) and c[f] >= b.n:
					return true
			return false
		BountyData.Kind.RUN, BountyData.Kind.STRAIGHT_5:
			var need := 5 if b.kind == BountyData.Kind.STRAIGHT_5 else b.n
			var run := 0
			for f in range(1, 7):
				run = run + 1 if c[f] > 0 else 0
				if run >= need:
					return true
			return false
		BountyData.Kind.TWO_PAIR:
			var pairs := 0
			for f in range(1, 7):
				if c[f] >= 2:
					pairs += 1
			return pairs >= 2
		BountyData.Kind.FULL_HOUSE:
			for f in range(1, 7):
				if c[f] >= 3:
					for g in range(1, 7):
						if g != f and c[g] >= 2:
							return true
			return false
	return false


## Ids of the bounties `faces` contains.
static func bounty_ticks(bounties: Array, faces: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for b: BountyData in bounties:
		if bounty_contains(b, faces):
			out.append(b.id)
	return out
