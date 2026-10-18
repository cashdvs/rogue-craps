## Pure Bonfire scoring and bounty detection (no nodes, no state).
##   score_selection(dice): a pot scores as exactly ONE combo: the
##     highest-ranked combo that EXACTLY matches the potted dice;
##     points = (base + sum of faces) x (mult + mult_bonus) x mod factors.
##     Each die is an int (plain face) or {value, mod: FaceModData}.
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


## A die for scoring: its face value and that face's mod (FaceModData or
## null). Plain ints are accepted anywhere a die is (value, no mod).
static func make_die(value: int, mod: FaceModData = null) -> Dictionary:
	return {"value": value, "mod": mod}


static func _die(x: Variant) -> Dictionary:
	if x is Dictionary:
		return x
	return {"value": int(x), "mod": null}


static func _effect(d: Dictionary) -> int:
	var m: FaceModData = d.get("mod")
	return -1 if m == null else int(m.effect)


## Face mods (FaceModData, spec in scripts/data/face_mod_data.gd):
##   BLANK: never lights or scores (a pot containing it is illegal).
##   TWIN: counts as two dice of its value (combo shape and faces sum).
##   WILD: counts as any value 1-6; the value giving the best legal combo
##     (most points, then highest rank) is used.
##   MULT_FACTOR (Hellfire x1.5): the pot's mult x mult_factor. Several such
##     faces in one pot stack MULTIPLICATIVELY (two Hellfires = x2.25),
##     applied after the Hot Hand bonus; points are rounded down.
## Returns {valid, all_used, points, combo, name, base, faces_sum, mult
## (int, combo + bonus), factor (float), values (the effective values used,
## Twins doubled, Wilds assigned)}.
static func score_selection(dice: Array, t: BonfireTuning, mult_bonus: int = 0) -> Dictionary:
	var bad := {"valid": false, "all_used": false, "points": 0, "combo": &"", "name": "", "base": 0, "faces_sum": 0,
		"mult": 0, "factor": 1.0, "values": []}
	if dice.is_empty():
		return bad
	var vals: Array[int] = []
	var wilds := 0
	var factor := 1.0
	for x in dice:
		var d := _die(x)
		var v := int(d["value"])
		match _effect(d):
			FaceModData.Effect.BLANK:
				return bad
			FaceModData.Effect.WILD:
				wilds += 1
			FaceModData.Effect.TWIN:
				vals.append(v)
				vals.append(v)
			FaceModData.Effect.MULT_FACTOR:
				vals.append(v)
				factor *= (d["mod"] as FaceModData).mult_factor
			_:
				vals.append(v)
	var best := bad
	var best_rank := -1
	for assign in _wild_assignments(wilds):
		var all: Array[int] = vals.duplicate()
		all.append_array(assign)
		var c := match_combo(all, t)
		if c == null:
			continue
		var sum := 0
		for f in all:
			sum += f
		var mult := c.mult + mult_bonus
		var pts := floori((c.base + sum) * mult * factor + 0.000001)
		var rank := t.combos.find(c)
		if pts > int(best["points"]) or (pts == int(best["points"]) and rank > best_rank) or not best["valid"]:
			best = {"valid": true, "all_used": true, "points": pts, "combo": c.id, "name": c.display_name,
				"base": c.base, "faces_sum": sum, "mult": mult, "factor": factor, "values": all}
			best_rank = rank
	return best


## Every multiset of `n` values 1-6 (order doesn't matter for combos).
static func _wild_assignments(n: int) -> Array:
	var out: Array = []
	var cur: Array[int] = []
	_assign_rec(n, 1, cur, out)
	return out


static func _assign_rec(n: int, from: int, cur: Array[int], out: Array) -> void:
	if cur.size() == n:
		out.append(cur.duplicate())
		return
	for v in range(from, 7):
		cur.append(v)
		_assign_rec(n, v, cur, out)
		cur.pop_back()


## "(base + faces) x mult = N" for the HUD ("x1.5" shown when a mod factor applies).
static func formula(s: Dictionary) -> String:
	if not s.get("valid", false):
		return ""
	var f := float(s.get("factor", 1.0))
	var ftxt := "" if is_equal_approx(f, 1.0) else (" x%s" % str(snappedf(f, 0.01)))
	return "%s  (%d + %d) x %d%s = %d" % [s["name"], s["base"], s["faces_sum"], s["mult"], ftxt, s["points"]]


## Every subset of the throw (as index arrays) that exactly forms a combo.
static func matching_subsets(dice: Array, t: BonfireTuning) -> Array:
	var out: Array = []
	var n := dice.size()
	for mask in range(1, 1 << n):
		var idx: Array[int] = []
		var sub: Array = []
		for i in n:
			if mask & (1 << i):
				idx.append(i)
				sub.append(dice[i])
		if score_selection(sub, t)["valid"]:
			out.append(idx)
	return out


## Dice that are part of ANY combo in the throw (a Wild lights if any value
## makes it part of one; a Blank never lights).
static func lit_indices(dice: Array, t: BonfireTuning) -> Array[int]:
	var lit: Array[int] = []
	for s in matching_subsets(dice, t):
		for i in s:
			if not lit.has(i):
				lit.append(i)
	lit.sort()
	return lit


## True if the selected indices are part of some combo subset of the throw.
static func can_extend(sel: Array, dice: Array, t: BonfireTuning) -> bool:
	if sel.is_empty():
		return true
	for s in matching_subsets(dice, t):
		var ok := true
		for i in sel:
			if not (s as Array).has(i):
				ok = false
				break
		if ok:
			return true
	return false


## Best single-pot score available in the throw (0 = bust).
static func best_points(dice: Array, t: BonfireTuning, mult_bonus: int = 0) -> int:
	var best := 0
	for s in matching_subsets(dice, t):
		var sub: Array = []
		for i in s:
			sub.append(dice[i])
		best = maxi(best, int(score_selection(sub, t, mult_bonus)["points"]))
	return best


## The values a set of dice shows for bounty checks: Twins count twice,
## Blanks and Wilds are left out (a potted Wild's value comes from the
## scored combo instead; see BonfireRun).
static func plain_values(dice: Array) -> Array[int]:
	var out: Array[int] = []
	for x in dice:
		var d := _die(x)
		match _effect(d):
			FaceModData.Effect.BLANK, FaceModData.Effect.WILD:
				pass
			FaceModData.Effect.TWIN:
				out.append(int(d["value"]))
				out.append(int(d["value"]))
			_:
				out.append(int(d["value"]))
	return out


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
