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
## table_ahead: a regular Table is still reachable on this floor
## (EventPicker.table_ahead); without one a next-table twist is greyed out.
static func can_choose(choice: EventChoiceData, p: RunProgress, table_ahead: bool = true) -> bool:
	return why_not(choice, p, table_ahead) == ""


## Should the event screen leave this choice out entirely (Game Designer)?
## True when a GIVE_DIE effect gives a die shape with enabled = false; no
## other die is substituted. Hidden choices can't be taken and don't count
## toward an event being worth offering.
static func is_hidden(choice: EventChoiceData, p: RunProgress) -> bool:
	for e in choice.effects:
		if e.kind == K.GIVE_DIE:
			var sh := p.shape_data(e.die)
			if sh != null and not sh.enabled:
				return true
	return false


## "" if the choice is allowed, else a short reason for the tooltip.
static func why_not(choice: EventChoiceData, p: RunProgress, table_ahead: bool = true) -> String:
	if is_hidden(choice, p):
		return "Not available yet."
	var soul_cost: int = 0
	var ember_cost: int = 0
	for e in choice.effects:
		if e.kind == K.SOUL and e.amount < 0:
			soul_cost -= e.amount
		elif e.kind == K.EMBERS and e.amount < 0:
			ember_cost -= e.amount
		elif e.kind == K.ADD_FACE_MOD and _all_free(p).is_empty():
			return "No blank face left to carve."
		elif e.kind == K.MAX_SOUL and e.amount < 0 and p.max_soul + e.amount < 1:
			return "Not enough max Soul."
		elif e.kind == K.GIVE_DIE and not p.can_add_die():
			return "Your bag is full (%d dice)." % p.data.max_dice
		elif e.kind == K.SELL_DIE and not p.can_lose_die():
			return "You need %d+ dice to give one up." % (p.data.starting_dice + 1)
		elif e.kind == K.NEXT_TABLE_TWIST and not table_ahead:
			return "No Table left on this floor."
	if _only_heals(choice) and p.soul >= p.max_soul:
		return "Your Soul is already full."
	if soul_cost > 0 and p.soul <= soul_cost:
		return "Not enough Soul."
	if ember_cost > p.embers:
		return "Not enough Embers."
	if choice.requires_face_mod and not p.has_removable_mod():
		return "You have no face mod to give."
	return ""


## Tooltip lines (strings_v1 §10) explaining a choice's lasting effects:
## a max-Soul cut and an event twist.
static func tips(choice: EventChoiceData) -> Array[String]:
	var out: Array[String] = []
	for e in choice.effects:
		if e.kind == K.MAX_SOUL and e.amount < 0:
			out.append("A lower max Soul also lowers your Soul to match.")
		elif e.kind == K.NEXT_TABLE_TWIST:
			out.append("An event twist applies to your next Table, not Elites or Bosses.")
			out.append("An unplayed event twist ends when you leave the floor.")
	return out


## Embers selling die `die_i` through SELL_DIE effect `e` pays: its sell
## value plus the effect's bonus.
static func sell_payout(e: EventEffectData, p: RunProgress, die_i: int) -> int:
	return p.sell_value(die_i) + e.amount


## How many (die, face) picks the view must collect before apply().
static func picks_needed(choice: EventChoiceData) -> int:
	var n: int = 0
	for e in choice.effects:
		if e.needs_pick():
			n += 1
	return n


## Is (die, face) a legal pick for effect `e`? ADD: a face with no mod on
## it (Blank can be carved over); REMOVE: a face holding a real mod that
## isn't a rare's locked pre-carved face.
static func pick_ok(e: EventEffectData, p: RunProgress, pick: Vector2i) -> bool:
	if e.kind == K.SELL_DIE:
		return pick.x >= 0 and pick.x < p.dice.size() and pick.y >= 0 and pick.y < p.dice[pick.x].faces.size()
	if e.kind == K.REMOVE_FACE_MOD:
		return p.removable_faces().has(pick)
	return pick.x >= 0 and pick.x < p.dice.size() and pick.y >= 0 and pick.y < p.dice[pick.x].faces.size() \
		and p.dice[pick.x].faces[pick.y] in [&"", RunDie.BLANK]


## Apply the choice. Returns a log (one line per effect) or ["refused: ..."].
static func apply(choice: EventChoiceData, p: RunProgress, rng: RandomNumberGenerator,
		picks: Array[Vector2i] = [], table_ahead: bool = true) -> Array[String]:
	var why: String = why_not(choice, p, table_ahead)
	if why != "":
		return ["refused: " + why]
	# Check every pick up front so a bad pick changes nothing.
	# Two picks of the same kind can't share a face (the second would
	# overwrite the first, or find nothing to remove).
	var k: int = 0
	var used: Dictionary = {}
	for e in choice.effects:
		if e.needs_pick():
			if k >= picks.size() or not pick_ok(e, p, picks[k]):
				return ["refused: pick a valid face"]
			var key := [e.kind, picks[k] if e.kind != K.SELL_DIE else Vector2i(picks[k].x, 0)]
			if used.has(key):
				return ["refused: pick a different face for each"]
			used[key] = true
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
			K.MAX_SOUL:
				lines.append("Max Soul %+d (%d)" % [p.change_max_soul(e.amount), p.max_soul])
			K.GIVE_DIE:
				if p.add_die(e.die if e.die != &"" else DiceIds.DIE_BONE):
					lines.append("gained %s" % p.die_name(p.dice.size() - 1))
				else:
					lines.append("bag full")
			K.SELL_DIE:
				var d: int = -1
				if e.needs_pick():
					d = picks[next_pick].x
					next_pick += 1
				elif p.can_lose_die():
					d = rng.randi_range(0, p.dice.size() - 1)
				if d < 0 or not p.can_lose_die():
					lines.append("no die to sell")
					continue
				var name := p.die_name(d)
				var paid := p.sell_die(d)
				var bonus := p.change_embers(e.amount) if e.amount != 0 else 0
				lines.append("sold %s: Embers %+d" % [name, paid + bonus])
			K.FREE_SHOP_REROLL:
				p.free_rerolls += maxi(e.amount, 0)
				p.changed.emit()
				lines.append("%d free shop reroll%s (%d banked)" % [e.amount, "" if e.amount == 1 else "s", p.free_rerolls])
			K.NEXT_TABLE_TWIST:
				p.next_table_twist = e.rule
				p.changed.emit()
				lines.append("next table: %s" % (e.rule.display_name if e.rule != null else "no twist"))
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


## The choice's only gain is Soul (anything else it does is a cost), e.g.
## the Altar's "give a face mod, +15 Soul": pointless at full Soul.
static func _only_heals(choice: EventChoiceData) -> bool:
	var heals := false
	for e in choice.effects:
		if e.kind == K.SOUL and e.amount > 0:
			heals = true
		elif not ((e.kind == K.EMBERS or e.kind == K.SOUL) and e.amount <= 0) and e.kind != K.REMOVE_FACE_MOD:
			return false
	return heals


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
		pool = p.removable_faces()
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
