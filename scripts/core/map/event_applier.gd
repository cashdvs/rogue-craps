## Runs an event choice's effects on a RunProgress (events §2). Pure logic,
## seeded: random targets use the RNG it's given.
##
## Picked targets: the view asks the player for one (die, face) per effect
## where effect.needs_pick(), in order, and passes them as `picks`.
class_name EventApplier
extends RefCounted

const K := EventEffectData.Kind
const T := EventEffectData.Target


## Greyed-out check: costs payable (Soul cost must leave you alive),
## required face mod owned, and somewhere to carve a new mod.
static func can_choose(choice: EventChoiceData, p: RunProgress) -> bool:
	return why_not(choice, p) == ""


## "" if the choice is allowed, else a short reason for the tooltip.
static func why_not(choice: EventChoiceData, p: RunProgress) -> String:
	var soul_cost: int = 0
	var ember_cost: int = 0
	for e in choice.effects:
		if e.kind == K.SOUL and e.amount < 0:
			soul_cost -= e.amount
		elif e.kind == K.EMBERS and e.amount < 0:
			ember_cost -= e.amount
		elif e.kind == K.ADD_FACE_MOD and _all_free(p).is_empty():
			return "No blank face left to carve."
	if soul_cost > 0 and p.soul <= soul_cost:
		return "Not enough Soul."
	if ember_cost > p.embers:
		return "Not enough Embers."
	if choice.requires_face_mod and not p.has_face_mod():
		return "You have no face mod to give."
	return ""


## How many (die, face) picks the view must collect before apply().
static func picks_needed(choice: EventChoiceData) -> int:
	var n: int = 0
	for e in choice.effects:
		if e.needs_pick():
			n += 1
	return n


## Is (die, face) a legal pick for effect `e`? ADD: a face with no mod on
## it (Blank can be carved over); REMOVE: a face holding a real mod.
static func pick_ok(e: EventEffectData, p: RunProgress, pick: Vector2i) -> bool:
	if e.kind == K.REMOVE_FACE_MOD:
		return p.modded_faces().has(pick)
	return pick.x >= 0 and pick.x < p.dice.size() and pick.y >= 0 and pick.y < 6 \
		and p.dice[pick.x].faces[pick.y] in [&"", RunDie.BLANK]


## Apply the choice. Returns a log (one line per effect) or ["refused: ..."].
static func apply(choice: EventChoiceData, p: RunProgress, rng: RandomNumberGenerator,
		picks: Array[Vector2i] = []) -> Array[String]:
	var why: String = why_not(choice, p)
	if why != "":
		return ["refused: " + why]
	# Check every pick up front so a bad pick changes nothing.
	var k: int = 0
	for e in choice.effects:
		if e.needs_pick():
			if k >= picks.size() or not pick_ok(e, p, picks[k]):
				return ["refused: pick a valid face"]
			k += 1
	var lines: Array[String] = []
	var next_pick: int = 0
	var last: Vector2i = Vector2i(-1, -1)
	for e in choice.effects:
		match e.kind:
			K.SOUL:
				lines.append("Soul %+d" % p.change_soul(e.amount))
			K.EMBERS:
				lines.append("Embers %+d" % p.change_embers(e.amount))
			K.SEAL_LEVEL:
				p.add_seal_levels(e.seal, e.amount)
				lines.append("%s Seal +%d (Lv%d)" % [e.seal, e.amount, p.seal_level(e.seal)])
			K.ADD_FACE_MOD, K.REMOVE_FACE_MOD:
				var at: Vector2i = Vector2i(-1, -1)
				if e.needs_pick():
					at = picks[next_pick]
					next_pick += 1
				else:
					at = _random_target(e, p, rng, last)
				if at.x < 0:
					lines.append("no valid face")
					continue
				if e.kind == K.ADD_FACE_MOD:
					p.set_face(at.x, at.y, e.mod.id)
					lines.append("%s on die %d face %d" % [e.mod.display_name, at.x + 1, at.y + 1])
				else:
					lines.append("removed %s from die %d face %d" % [p.dice[at.x].faces[at.y], at.x + 1, at.y + 1])
					p.set_face(at.x, at.y, &"")
				last = at
	return lines


static func _all_free(p: RunProgress) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in p.dice.size():
		for f in p.dice[d].free_faces():
			out.append(Vector2i(d, f))
	return out


static func _random_target(e: EventEffectData, p: RunProgress, rng: RandomNumberGenerator,
		last: Vector2i) -> Vector2i:
	var pool: Array[Vector2i] = []
	if e.kind == K.REMOVE_FACE_MOD:
		pool = p.modded_faces()
	elif e.target == T.RANDOM_OTHER_SAME_DIE:
		if last.x < 0:
			return Vector2i(-1, -1)
		for f in p.dice[last.x].faces.size():
			if f != last.y and p.dice[last.x].faces[f] == &"":
				pool.append(Vector2i(last.x, f))
	else:
		# A random die that still has a free face, then a random free face on it.
		var dice_ok: Array[int] = []
		for d in p.dice.size():
			if not p.dice[d].free_faces().is_empty():
				dice_ok.append(d)
		if dice_ok.is_empty():
			return Vector2i(-1, -1)
		var d: int = dice_ok[rng.randi_range(0, dice_ok.size() - 1)]
		for f in p.dice[d].free_faces():
			pool.append(Vector2i(d, f))
	if pool.is_empty():
		return Vector2i(-1, -1)
	return pool[rng.randi_range(0, pool.size() - 1)]
