## How likely the next throw is to burn (bust: nothing lights), worked out
## EXACTLY by trying every way the cold dice can land (design section 4:
## "Throw 2 cold dice: 1 in 3 burns").
##
## For each die we list its faces with their roll chance (TableDie.weights,
## uniform if empty), so Heavy weights, face mods (Blank, Wild, Step...),
## special dice and table rules all count, because every outcome is checked
## with the same BonfireScoring the table uses (ctx = BonfireRun.rule_ctx(),
## e.g. Cold Sixes' cold_values or The Straight Man's excluded combos).
##
## Rules that change faces after the dice settle are listed in `effects`:
##   {"kind": &"shuffle", "count": k}  Madame Shuffle: ONE random lit die
##       (each lit die equally likely) is rerolled with its own weights, k
##       times, each time picking among the dice lit at that moment (rule
##       issue #70, RuleMadameShuffle). Exact.
##   {"kind": &"mirror"}  Mirror dice copy the NEAREST other die. Where the
##       dice will stop isn't known before the throw, so each Mirror is
##       counted as copying one of the other dice, each equally likely.
## A Kindling face armed for this throw means it can't burn (chance 0).
class_name BustRisk
extends RefCounted


## dice: Array of TableDie (null = a plain Bone die). ctx: BonfireScoring
## ctx. Returns {"burn": 0..1, "dice": n, "text": "1 in 3"}.
static func chance(dice: Array, t: BonfireTuning, ctx: Dictionary = {}, effects: Array = [], kindling: bool = false) -> Dictionary:
	var n := dice.size()
	if n == 0 or kindling:
		return {"burn": 0.0, "dice": n, "text": odds_text(0.0)}
	var per_die: Array = []
	for td in dice:
		per_die.append(_outcomes(td))
	var memo := {}
	var slots: Array[int] = []
	slots.resize(n)
	var burn := 0.0
	if effects.is_empty() and _all_alike(dice):
		burn = _walk_multiset(0, 0, 1.0, slots, dice, per_die[0], t, ctx, memo)
	else:
		burn = _walk(0, 1.0, slots, dice, per_die, t, ctx, effects, memo)
	return {"burn": burn, "dice": n, "text": odds_text(burn)}


## True if every die is the same die (the same TableDie, or all plain d6):
## the order of the landed faces then doesn't matter.
static func _all_alike(dice: Array) -> bool:
	for td in dice:
		if td != dice[0]:
			return false
	return true


## Identical dice, no face-changing rules: each multiset of faces once, with
## its multinomial weight (5 plain d6: 252 cases instead of 7776).
static func _walk_multiset(i: int, from: int, p: float, slots: Array[int], dice: Array, outs: Array,
		t: BonfireTuning, ctx: Dictionary, memo: Dictionary) -> float:
	var n := slots.size()
	if i == n:
		var ways := 1.0
		var run_len := 1
		for k in range(1, n + 1):
			ways *= k
		for k in range(1, n + 1):
			if k < n and slots[k] == slots[k - 1]:
				run_len += 1
			else:
				for m in range(2, run_len + 1):
					ways /= m
				run_len = 1
		return p * ways * (1.0 if _burns(slots, [], dice, t, ctx, memo) else 0.0)
	var sum := 0.0
	for k in range(from, outs.size()):
		slots[i] = int(outs[k][0])
		sum += _walk_multiset(i + 1, k, p * float(outs[k][1]), slots, dice, outs, t, ctx, memo)
	return sum


## [[slot, chance], ...] for one die.
static func _outcomes(td: TableDie) -> Array:
	var out: Array = []
	if td == null:
		for s in range(1, 7):
			out.append([s, 1.0 / 6.0])
		return out
	var k := td.faces.size()
	var total := 0.0
	var use_w := td.weights.size() == k
	if use_w:
		for w in td.weights:
			total += maxf(w, 0.0)
	for s in range(1, k + 1):
		var p := (maxf(td.weights[s - 1], 0.0) / total) if (use_w and total > 0.0) else 1.0 / float(k)
		if p > 0.0:
			out.append([s, p])
	return out


## Every combination of landed slots, die by die.
static func _walk(i: int, p: float, slots: Array[int], dice: Array, per_die: Array, t: BonfireTuning,
		ctx: Dictionary, effects: Array, memo: Dictionary) -> float:
	if i == slots.size():
		return p * _burn_after_effects(slots.duplicate(), 0, dice, per_die, t, ctx, effects, memo, [])
	var sum := 0.0
	for o: Array in per_die[i]:
		slots[i] = int(o[0])
		sum += _walk(i + 1, p * float(o[1]), slots, dice, per_die, t, ctx, effects, memo)
	return sum


## The chance (0..1) that these landed slots burn, after the face-changing
## rules from effects[e] on. `values_override` (per die, 0 = none) holds
## values a Mirror copied.
static func _burn_after_effects(slots: Array[int], e: int, dice: Array, per_die: Array, t: BonfireTuning,
		ctx: Dictionary, effects: Array, memo: Dictionary, copied: Array) -> float:
	if e >= effects.size():
		return 1.0 if _burns(slots, copied, dice, t, ctx, memo) else 0.0
	var fx: Dictionary = effects[e]
	match StringName(fx.get("kind", &"")):
		&"shuffle":
			return _shuffle(slots, int(fx.get("count", 1)), [], e, dice, per_die, t, ctx, effects, memo, copied)
		&"mirror":
			return _mirror(slots, e, dice, per_die, t, ctx, effects, memo, copied)
	return _burn_after_effects(slots, e + 1, dice, per_die, t, ctx, effects, memo, copied)


static func _shuffle(slots: Array[int], left: int, done: Array, e: int, dice: Array, per_die: Array, t: BonfireTuning,
		ctx: Dictionary, effects: Array, memo: Dictionary, copied: Array) -> float:
	if left <= 0:
		return _burn_after_effects(slots, e + 1, dice, per_die, t, ctx, effects, memo, copied)
	# Which dice light right now (same scoring the table uses)?
	var sd: Array = []
	for i in slots.size():
		var td: TableDie = dice[i]
		var copied_here := i < copied.size() and copied[i] != null and int(copied[i]) > 0
		var m: FaceModData = null if (td == null or copied_here) else td.mod_at(slots[i])
		sd.append(BonfireScoring.make_die(_value(dice, i, slots[i], copied), m, _special(dice, i)))
	var choices: Array[int] = []
	for i in BonfireScoring.lit_indices(sd, t, ctx):
		if not done.has(i):
			choices.append(i)
	if choices.is_empty():
		return _burn_after_effects(slots, e + 1, dice, per_die, t, ctx, effects, memo, copied)
	# She picks one of them, each equally likely, and rerolls it.
	var sum := 0.0
	for pick in choices:
		var d2 := done.duplicate()
		d2.append(pick)
		for o: Array in per_die[pick]:
			var s2 := slots.duplicate()
			s2[pick] = int(o[0])
			var c2 := copied.duplicate()
			if c2.size() > pick:
				c2[pick] = 0
			sum += float(o[1]) / float(choices.size()) * _shuffle(s2, left - 1, d2, e, dice, per_die, t, ctx, effects, memo, c2)
	return sum


static func _mirror(slots: Array[int], e: int, dice: Array, per_die: Array, t: BonfireTuning,
		ctx: Dictionary, effects: Array, memo: Dictionary, copied: Array) -> float:
	# Each Mirror copies one of the landed non-Mirror dice, equally likely.
	var mirrors: Array[int] = []
	var others: Array[int] = []
	for i in slots.size():
		if _special(dice, i) == &"mirror":
			mirrors.append(i)
		else:
			others.append(i)
	if mirrors.is_empty() or others.is_empty():
		return _burn_after_effects(slots, e + 1, dice, per_die, t, ctx, effects, memo, copied)
	var landed: Array[int] = []
	for i in slots.size():
		landed.append(_value(dice, i, slots[i], copied))
	return _mirror_rec(0, mirrors, others, landed, slots, e, dice, per_die, t, ctx, effects, memo, copied)


static func _mirror_rec(k: int, mirrors: Array[int], others: Array[int], landed: Array[int], slots: Array[int], e: int,
		dice: Array, per_die: Array, t: BonfireTuning, ctx: Dictionary, effects: Array, memo: Dictionary, copied: Array) -> float:
	if k == mirrors.size():
		return _burn_after_effects(slots, e + 1, dice, per_die, t, ctx, effects, memo, copied)
	var sum := 0.0
	var m := mirrors[k]
	for j in others:
		var s2 := slots.duplicate()
		var c2 := copied.duplicate()
		c2.resize(slots.size())
		var td: TableDie = dice[m]
		var slot := td.slot_for_value(landed[j]) if td != null else landed[j]
		if slot > 0:
			s2[m] = slot
			c2[m] = 0
		else:
			c2[m] = landed[j]  # the Mirror shows a value it has no face for
		sum += _mirror_rec(k + 1, mirrors, others, landed, s2, e, dice, per_die, t, ctx, effects, memo, c2) / float(others.size())
	return sum


static func _special(dice: Array, i: int) -> StringName:
	var td: TableDie = dice[i]
	return td.special if td != null else &""


static func _value(dice: Array, i: int, slot: int, copied: Array) -> int:
	if i < copied.size() and copied[i] != null and int(copied[i]) > 0:
		return int(copied[i])
	var td: TableDie = dice[i]
	return td.value_at(slot) if td != null else slot


## True if nothing in this landed throw can light. Order doesn't matter
## (except for Mirror, already applied), so equal throws share one check.
static func _burns(slots: Array[int], copied: Array, dice: Array, t: BonfireTuning, ctx: Dictionary, memo: Dictionary) -> bool:
	var sd: Array = []
	var keys: PackedStringArray = []
	for i in slots.size():
		var td: TableDie = dice[i]
		var v := _value(dice, i, slots[i], copied)
		var copied_here := i < copied.size() and copied[i] != null and int(copied[i]) > 0
		var m: FaceModData = null if (td == null or copied_here) else td.mod_at(slots[i])
		var sp := _special(dice, i)
		sd.append(BonfireScoring.make_die(v, m, sp))
		keys.append("%d|%s|%s" % [v, str(m.get_instance_id()) if m != null else "", sp])
	keys.sort()
	var key := ",".join(keys)
	if memo.has(key):
		return memo[key]
	var b := not _any_combo(sd, t, ctx)
	memo[key] = b
	return b


## Like BonfireScoring.lit_indices(...).is_empty() == false, but stops at
## the first combo found.
static func _any_combo(dice: Array, t: BonfireTuning, ctx: Dictionary) -> bool:
	var n := dice.size()
	for mask in range(1, 1 << n):
		var sub: Array = []
		for i in n:
			if mask & (1 << i):
				sub.append(dice[i])
		if BonfireScoring.score_selection(sub, t, 0, ctx)["valid"]:
			return true
	return false


## "1 in 3", "2 in 3", "8%", "<1%", or "can't burn".
static func odds_text(p: float) -> String:
	if p <= 0.0000001:
		return "can't burn"
	if p >= 0.9999999:
		return "always burns"
	for d in range(2, 13):
		for k in range(1, d):
			if absf(float(k) / float(d) - p) < 0.002:
				return "%d in %d" % [k, d]
	if p < 0.01:
		return "<1%"
	return "%d%%" % roundi(p * 100.0)


## The rethrow prompt: "Throw 2 cold dice: 1 in 3 burns".
static func prompt(n: int, risk: Dictionary, hot: bool = false) -> String:
	var odds := String(risk.get("text", ""))
	var what := ("Hot Hand: throw all %d dice" % n) if hot else ("Throw %d cold %s" % [n, "die" if n == 1 else "dice"])
	if odds == "can't burn" or odds == "always burns":
		return "%s: %s" % [what, odds]
	return "%s: %s burns" % [what, odds]
