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


## Highest face value the table handles (a d20).
const MAX_FACE: int = 20


## How many dice show each value: c[v] for v in 0..MAX_FACE (non-d6 dice,
## design/nonstandard_dice.md §2: numbers are numbers). Values outside
## 0..MAX_FACE are clamped there (a data error, never an index error).
static func _counts(faces: Array) -> Array[int]:
	var c: Array[int] = []
	c.resize(MAX_FACE + 1)
	for f in faces:
		c[clampi(int(f), 0, MAX_FACE)] += 1
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


## `length` distinct values in a row; with `gap` (the Wanderer) one value
## may be skipped once (1-2-4-5 = a run of 4).
static func _is_run(faces: Array, length: int, gap: bool = false) -> bool:
	if faces.size() != length:
		return false
	var s := faces.duplicate()
	s.sort()
	for i in range(1, s.size()):
		if int(s[i]) == int(s[i - 1]):
			return false
	var span := int(s[-1]) - int(s[0])
	return span == length - 1 or (gap and span == length)


## The skipped value of a gapped run (0 = no gap).
static func _run_gap(faces: Array) -> int:
	var s := faces.duplicate()
	s.sort()
	for i in range(1, s.size()):
		if int(s[i]) == int(s[i - 1]) + 2:
			return int(s[i]) - 1
	return 0


## Does `faces` EXACTLY form combo `c`?
static func matches(c: BonfireCombo, faces: Array, gap: bool = false) -> bool:
	match c.kind:
		BonfireCombo.Kind.SINGLE:
			# Faces above 6 light alone too (§3): (5 + face) x 1 with the
			# tuning's Single (base 5, mult 1).
			return faces.size() == 1 and (c.single_faces.has(int(faces[0])) or int(faces[0]) > 6)
		BonfireCombo.Kind.N_OF_A_KIND:
			return faces.size() == c.n and _shape(faces) == [c.n]
		BonfireCombo.Kind.RUN:
			return _is_run(faces, c.n, gap)
		BonfireCombo.Kind.TWO_PAIR:
			return faces.size() == 4 and _shape(faces) == [2, 2]
		BonfireCombo.Kind.FULL_HOUSE:
			return faces.size() == 5 and _shape(faces) == [3, 2]
	return false


## The highest-ranked combo exactly matching `faces` (null if none).
static func match_combo(faces: Array, t: BonfireTuning, excluded: Array = [], gap: bool = false) -> BonfireCombo:
	if faces.is_empty():
		return null
	for k in range(t.combos.size() - 1, -1, -1):
		if excluded.has(t.combos[k].id):
			continue
		if matches(t.combos[k], faces, gap):
			return t.combos[k]
	return null


## A die for scoring: its face value, that face's mod (FaceModData or null)
## and the die's special-die id (&"" = plain Bone; e.g. &"coven"). Plain ints
## are accepted anywhere a die is (value, no mod, no special).
static func make_die(value: int, mod: FaceModData = null, special: StringName = &"") -> Dictionary:
	return {"value": value, "mod": mod, "special": special}


static func _die(x: Variant) -> Dictionary:
	if x is Dictionary:
		return x
	return {"value": int(x), "mod": null, "special": &""}


static func _effect(d: Dictionary) -> int:
	var m: FaceModData = d.get("mod")
	return -1 if m == null else int(m.effect)


static func _is_kind(c: BonfireCombo, kind: BonfireCombo.Kind, n: int = -1) -> bool:
	return c.kind == kind and (n < 0 or c.n == n)


## Scores ONE pot: the highest-paying combo the dice EXACTLY form.
## points = floor((base + stair + faces) x (mult + mult_bonus + adds) x factor)
##
## Face mods (FaceModData, spec in scripts/data/face_mod_data.gd):
##   BLANK: never lights or scores (a pot containing it is illegal).
##   TWIN: counts as two dice of its value (combo shape and faces sum).
##   WILD: counts as any value 1-6.
##   STEP: counts as its value or +-1, but the +-1 only for a RUN combo.
##   Wild / Step values are chosen for the most points (then highest rank).
##   MULT_FACTOR (Hellfire x1.5): x mult_factor; several stack
##     MULTIPLICATIVELY (two Hellfires = x2.25).
##   MULT_ADD (Ember Pip +2, Blood +4): + amount mult. Blood's soul_cost is
##     summed into "soul_cost" (the run charges it when the pot is potted).
##     With ctx soul: the cost after ctx blood_cost (a Callable, e.g. the
##     Bloodletter's x2); if paying it would take the last Soul, nothing is
##     paid and the Blood faces give no mult ("blood_refused").
##   Curse faces (is_curse, e.g. Blank) stay on under ctx no_mods.
##   STAIR: if the combo is a RUN, + amount base per die in that run (each
##     Stair face adds it).
##   EMBER (Gilded): + amount Embers when potted (summed into "embers").
##   KINDLING: "kindling" = true (the run arms its next-rethrow-can't-bust).
##   HEAVY: roll weight only (the run's side); nothing here.
## Special dice (numbers in BonfireTuning, "Special dice"):
##   twin_flame: Pair or Two Pair containing it: + twin_flame_mult mult.
##   coven: Trips or Full House containing it: x coven_factor.
##   cracked: x cracked_factor on its pot (shattering is the run's job).
##   blood_pact: + 1 mult per blood_pact_soul_step missing Soul
##     (ctx soul / max_soul).
##   wanderer: a run containing it may skip one value once (1-2-4-5 = Run
##     of 4); the skipped value adds nothing. Step applies first.
##     "bounty_values" closes the gap for run bounties.
##   last_breath: potted from a rethrow (ctx is_rethrow) of 1..
##     last_breath_max_dice dice (ctx throw_size): x last_breath_factor.
## Returns {valid, all_used, points, combo, name, base (incl. stair),
## stair, faces_sum, mult (combo + bonus + adds), adds, factor, values (the
## effective values used), soul_cost, embers, kindling, specials}.
## `ctx` (optional; table rules fill most of it, see TableRule):
##   no_mods: bool - every face counts as plain (The Collector);
##   cold_values: Array[int] - dice showing these values never light or score,
##     and a Wild / Step can't become one (Cold Sixes, The Pit Boss);
##   excluded_combos: Array[StringName] - these combos don't count (The
##     Straight Man); min_dice: int - a pot needs at least this many dice
##     (Greedy Pot); soul / max_soul / throw_size / is_rethrow (special dice).
static func score_selection(dice: Array, t: BonfireTuning, mult_bonus: int = 0, ctx: Dictionary = {}) -> Dictionary:
	var bad := {"valid": false, "all_used": false, "points": 0, "combo": &"", "name": "", "base": 0, "stair": 0, "faces_sum": 0,
		"mult": 0, "adds": 0, "factor": 1.0, "values": [], "soul_cost": 0, "embers": 0, "kindling": false, "specials": [],
		"gapped": false, "bounty_values": [], "blood_refused": false}
	if dice.is_empty() or dice.size() < int(ctx.get("min_dice", 1)):
		return bad
	var no_mods: bool = ctx.get("no_mods", false)
	var cold: Array = ctx.get("cold_values", [])
	var excluded: Array = ctx.get("excluded_combos", [])
	var vals: Array[int] = []
	var steps: Array[int] = []
	var wilds := 0
	var factor := 1.0
	var adds := 0
	var blood_adds := 0
	var stairs := 0
	var soul_cost := 0
	var embers := 0
	var kindling := false
	var specials: Array[StringName] = []
	for x in dice:
		var d := _die(x)
		var v := int(d["value"])
		var sp := StringName(d.get("special", &""))
		if sp != &"":
			specials.append(sp)
		var m: FaceModData = d.get("mod")
		var eff := -1 if no_mods and not (m != null and m.is_curse) else _effect(d)
		if eff != FaceModData.Effect.WILD and eff != FaceModData.Effect.STEP and cold.has(v):
			return bad
		# A face with no number (value 0 or less, e.g. a data Blank) never scores.
		if v < 1 and eff != FaceModData.Effect.WILD:
			return bad
		match eff:
			FaceModData.Effect.BLANK:
				return bad
			FaceModData.Effect.WILD:
				wilds += 1
			FaceModData.Effect.STEP:
				steps.append(v)
			FaceModData.Effect.TWIN:
				vals.append(v)
				vals.append(v)
			FaceModData.Effect.MULT_FACTOR:
				vals.append(v)
				factor *= m.mult_factor
			FaceModData.Effect.MULT_ADD:
				vals.append(v)
				adds += m.amount
				if m.soul_cost > 0:
					blood_adds += m.amount
				soul_cost += m.soul_cost
			FaceModData.Effect.STAIR:
				vals.append(v)
				stairs += m.amount
			FaceModData.Effect.EMBER:
				vals.append(v)
				embers += m.amount
			FaceModData.Effect.KINDLING:
				vals.append(v)
				kindling = true
			_:
				vals.append(v)
	var blood_refused := false
	if soul_cost > 0 and ctx.has("soul"):
		var bc: Variant = ctx.get("blood_cost")
		var cost := int((bc as Callable).call(soul_cost)) if bc is Callable else soul_cost
		if int(ctx["soul"]) - cost < 1:
			blood_refused = true
			adds -= blood_adds
			soul_cost = 0
		else:
			soul_cost = cost
	var gap_ok := specials.has(&"wanderer")
	var best := bad
	var best_rank := -1
	# Wild / Step reach (§5): values 1-6, higher only up to the highest face
	# a die in the tray can show (ctx wild_max, e.g. 8 with a Lantern d8).
	var top := maxi(int(ctx.get("wild_max", 6)), 6)
	var step_opts := _step_options(steps, cold, top)
	for assign in _wild_assignments(wilds, cold, top):
		for st: Array in step_opts:
			var all: Array[int] = vals.duplicate()
			all.append_array(assign)
			var stepped := false
			for k in st.size():
				all.append(int(st[k]))
				stepped = stepped or int(st[k]) != steps[k]
			var c := match_combo(all, t, excluded, gap_ok)
			if c == null or (stepped and c.kind != BonfireCombo.Kind.RUN):
				continue
			var sum := 0
			for f in all:
				sum += f
			var stair := stairs * all.size() if c.kind == BonfireCombo.Kind.RUN else 0
			var a := adds
			var f := factor
			for sp in specials:
				match sp:
					&"twin_flame":
						if _is_kind(c, BonfireCombo.Kind.N_OF_A_KIND, 2) or c.kind == BonfireCombo.Kind.TWO_PAIR:
							a += t.twin_flame_mult
					&"coven":
						if _is_kind(c, BonfireCombo.Kind.N_OF_A_KIND, 3) or c.kind == BonfireCombo.Kind.FULL_HOUSE:
							f *= t.coven_factor
					&"cracked":
						f *= t.cracked_factor
					&"blood_pact":
						var missing := maxi(int(ctx.get("max_soul", 0)) - int(ctx.get("soul", 0)), 0)
						a += missing / maxi(t.blood_pact_soul_step, 1)
					&"last_breath":
						var n := int(ctx.get("throw_size", 0))
						if bool(ctx.get("is_rethrow", false)) and n >= 1 and n <= t.last_breath_max_dice:
							f *= t.last_breath_factor
			var mult := c.mult + mult_bonus + a
			var pts := floori((c.base + stair + sum) * mult * f + 0.000001)
			var rank := t.combos.find(c)
			var gv := _run_gap(all) if c.kind == BonfireCombo.Kind.RUN and gap_ok else 0
			if pts > int(best["points"]) or (pts == int(best["points"]) and rank > best_rank) or not best["valid"]:
				best = {"valid": true, "all_used": true, "points": pts, "combo": c.id, "name": c.display_name,
					"base": c.base + stair, "stair": stair, "faces_sum": sum, "mult": mult, "adds": a, "factor": f,
					"values": all, "soul_cost": soul_cost, "embers": embers, "kindling": kindling, "specials": specials,
					"gapped": gv > 0, "bounty_values": _close_gap(all, gv), "blood_refused": blood_refused}
				best_rank = rank
	return best


## A gapped run's values with the gap closed (values above it moved down 1),
## so it ticks the run bounty of its length.
static func _close_gap(vals: Array, gap_value: int) -> Array:
	var out: Array = []
	for v in vals:
		out.append(int(v) - 1 if gap_value > 0 and int(v) > gap_value else int(v))
	return out


## Every choice of value for each Step face: its value or +-1 (1..top, not
## cold; top = 6 unless a wider die is in the tray).
static func _step_options(steps: Array[int], cold: Array, top: int = 6) -> Array:
	var out: Array = [[]]
	for v in steps:
		var next: Array = []
		for prefix: Array in out:
			for o in [v, v - 1, v + 1]:
				if o >= 1 and o <= maxi(top, v) and not cold.has(o):
					var p := prefix.duplicate()
					p.append(o)
					next.append(p)
		out = next
	return out


## Every multiset of `n` values 1..top not in `cold` (order doesn't matter).
## top is the Wild cap (§5): 6, or the highest face a die in the tray shows.
static func _wild_assignments(n: int, cold: Array = [], top: int = 6) -> Array:
	var out: Array = []
	var cur: Array[int] = []
	_assign_rec(n, 1, cur, out, cold, clampi(top, 1, MAX_FACE))
	return out


static func _assign_rec(n: int, from: int, cur: Array[int], out: Array, cold: Array, top: int = 6) -> void:
	if cur.size() == n:
		out.append(cur.duplicate())
		return
	for v in range(from, top + 1):
		if cold.has(v):
			continue
		cur.append(v)
		_assign_rec(n, v, cur, out, cold, top)
		cur.pop_back()


## "(base + faces) x mult = N" for the HUD ("x1.5" shown when a mod factor applies).
static func formula(s: Dictionary) -> String:
	if not s.get("valid", false):
		return ""
	var f := float(s.get("factor", 1.0))
	var ftxt := "" if is_equal_approx(f, 1.0) else (" x%s" % str(snappedf(f, 0.01)))
	return "%s  (%d + %d) x %d%s = %d" % [s["name"], s["base"], s["faces_sum"], s["mult"], ftxt, s["points"]]


## Every subset of the throw (as index arrays) that exactly forms a combo.
static func matching_subsets(dice: Array, t: BonfireTuning, ctx: Dictionary = {}) -> Array:
	var out: Array = []
	var n := dice.size()
	for mask in range(1, 1 << n):
		var idx: Array[int] = []
		var sub: Array = []
		for i in n:
			if mask & (1 << i):
				idx.append(i)
				sub.append(dice[i])
		if score_selection(sub, t, 0, ctx)["valid"]:
			out.append(idx)
	return out


## Dice that are part of ANY combo in the throw (a Wild lights if any value
## makes it part of one; a Blank never lights).
static func lit_indices(dice: Array, t: BonfireTuning, ctx: Dictionary = {}) -> Array[int]:
	var lit: Array[int] = []
	for s in matching_subsets(dice, t, ctx):
		for i in s:
			if not lit.has(i):
				lit.append(i)
	lit.sort()
	return lit


## True if the selected indices are part of some combo subset of the throw.
static func can_extend(sel: Array, dice: Array, t: BonfireTuning, ctx: Dictionary = {}) -> bool:
	if sel.is_empty():
		return true
	for s in matching_subsets(dice, t, ctx):
		var ok := true
		for i in sel:
			if not (s as Array).has(i):
				ok = false
				break
		if ok:
			return true
	return false


## Best single-pot score available in the throw (0 = bust).
static func best_points(dice: Array, t: BonfireTuning, mult_bonus: int = 0, ctx: Dictionary = {}) -> int:
	var best := 0
	for s in matching_subsets(dice, t, ctx):
		var sub: Array = []
		for i in s:
			sub.append(dice[i])
		best = maxi(best, int(score_selection(sub, t, mult_bonus, ctx)["points"]))
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
				if int(d["value"]) >= 1:
					out.append(int(d["value"]))
	return out


# --- Bounties --------------------------------------------------------------------

## Does `faces` CONTAIN the bounty's pattern (extra dice are fine)?
static func bounty_contains(b: BountyData, faces: Array) -> bool:
	var c := _counts(faces)
	match b.kind:
		BountyData.Kind.N_OF_A_KIND:
			for f in range(1, MAX_FACE + 1):
				if (b.face == 0 or b.face == f) and c[f] >= b.n:
					return true
			return false
		BountyData.Kind.RUN, BountyData.Kind.STRAIGHT_5:
			var need := 5 if b.kind == BountyData.Kind.STRAIGHT_5 else b.n
			var run := 0
			for f in range(1, MAX_FACE + 1):
				run = run + 1 if c[f] > 0 else 0
				if run >= need:
					return true
			return false
		BountyData.Kind.TWO_PAIR:
			var pairs := 0
			for f in range(1, MAX_FACE + 1):
				if c[f] >= 2:
					pairs += 1
			return pairs >= 2
		BountyData.Kind.FULL_HOUSE:
			for f in range(1, MAX_FACE + 1):
				if c[f] >= 3:
					for g in range(1, MAX_FACE + 1):
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
