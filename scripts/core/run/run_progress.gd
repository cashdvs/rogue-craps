## Everything that persists between nodes on a Bonfire run: Soul, Embers,
## the handful of dice (with face mods), Seal levels per combo (plus the
## rare Seals' moves), combos banked, and contract pieces.
##
## Pure logic: events, rests, the shop and table results all change it
## through these methods; views listen to `changed`.
class_name RunProgress
extends RefCounted

signal changed()
## Emitted once when Soul reaches 0 (the run ends).
signal run_ended()

var data: RunData
var soul: int
var max_soul: int
var embers: int
var dice: Array[RunDie] = []
## Combo id -> Seal levels gained (0 = base combo from bonfire_tuning.tres).
var seal_levels: Dictionary[StringName, int] = {}
## Combo id -> base / mult moved by Transference (x = base, y = mult).
var seal_moves: Dictionary[StringName, Vector2i] = {}
## Combo id -> times banked this run (Black Seal). The table reports these.
var banked: Dictionary[StringName, int] = {}
var contract_pieces: int = 0
var _next_die_id: int = 0


func _init(run_data: RunData) -> void:
	data = run_data
	max_soul = data.max_soul
	soul = data.starting_soul
	embers = data.starting_embers
	for i in data.starting_dice:
		dice.append(_new_die(&""))


func is_over() -> bool:
	return soul <= 0


## Change Soul, clamped to 0..max_soul. Returns the real change.
func change_soul(delta: int) -> int:
	var before: int = soul
	soul = clampi(soul + delta, 0, max_soul)
	if soul != before:
		changed.emit()
		if soul <= 0:
			run_ended.emit()
	return soul - before


func change_embers(delta: int) -> int:
	var before: int = embers
	embers = maxi(embers + delta, 0)
	if embers != before:
		changed.emit()
	return embers - before


func can_add_die() -> bool:
	return dice.size() < data.max_dice


func special_die(id: StringName) -> SpecialDieData:
	for d in data.special_dice:
		if d.id == id:
			return d
	return null


func shape_data(id: StringName) -> DieShape:
	for s in data.shapes:
		if s.id == id:
			return s
	return null


## What die i is, for prices and names: its special die, else its shape
## (null for a plain d6).
func die_def(die_i: int) -> SpecialDieData:
	if die_i < 0 or die_i >= dice.size():
		return null
	var d := dice[die_i]
	if d.special_id != &"":
		return special_die(d.special_id)
	return shape_data(d.shape) if d.shape != &"d6" else null


## "Bone", "Mirror Die", "Coin", ...
func die_name(die_i: int) -> String:
	var def := die_def(die_i)
	return def.display_name if def != null else "Bone"


## Price of `mod` on die i: +mod_price_step_percent per mod already on it.
func mod_price(mod: FaceModData, die_i: int) -> int:
	var n: int = 0
	if die_i >= 0 and die_i < dice.size():
		n = dice[die_i].modded_faces().size() - dice[die_i].faces.count(RunDie.BLANK)
	return mod.price * (100 + data.mod_price_step_percent * n) / 100


## Embers a die sells for (special dice: half their price; plain dice: 0).
func sell_value(die_i: int) -> int:
	var d := die_def(die_i)
	return d.price * data.die_sell_percent / 100 if d != null else 0


## Sell die i (never below the starting handful). Returns the Embers paid.
func sell_die(die_i: int) -> int:
	if die_i < 0 or die_i >= dice.size() or dice.size() <= data.starting_dice:
		return -1
	var v := sell_value(die_i)
	dice.remove_at(die_i)
	change_embers(v)
	changed.emit()
	return v


## Add a die by offer id: a special die id, or a die shape id (a plain die
## of that shape, e.g. &"coin").
func add_die(special: StringName) -> bool:
	if not can_add_die():
		return false
	var sh := shape_data(special)
	if sh != null and special != &"d6":
		var d := _new_die(&"", sh.id, sh.face_count())
		for i in sh.faces.size():
			d.faces[i] = StringName(sh.preset_mods.get(sh.faces[i], &""))
		dice.append(d)
	else:
		dice.append(_new_die(special if special != &"d6" else &""))
	changed.emit()
	return true


func _new_die(special: StringName, shape_id: StringName = &"d6", face_count: int = 6) -> RunDie:
	var d := RunDie.new(special, shape_id, face_count)
	var kind: StringName = special if special != &"" else (shape_id if shape_id != &"d6" else &"bone")
	d.id = StringName("%s_%d" % [kind, _next_die_id])
	_next_die_id += 1
	return d


func die_index(id: StringName) -> int:
	for i in dice.size():
		if dice[i].id == id:
			return i
	return -1


## Remove dice for good (a shattered Cracked die), face mods and all. Never
## below RunData.cracked_min_dice (the table enforces that ruling; this is a
## guard): extra removals are ignored with a warning. Returns how many went.
func remove_dice(ids: Array) -> int:
	var n := 0
	for id in ids:
		var i := die_index(StringName(id))
		if i >= 0 and dice.size() <= data.cracked_min_dice:
			push_warning("RunProgress.remove_dice: ignoring '%s'; the handful can't drop below %d dice." % [id, data.cracked_min_dice])
			continue
		if i >= 0:
			dice.remove_at(i)
			n += 1
	if n > 0:
		changed.emit()
	return n


## Every (die, face) holding a real mod (Blank doesn't count: it's a curse).
func modded_faces() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in dice.size():
		for f in dice[d].modded_faces():
			if dice[d].faces[f] != RunDie.BLANK:
				out.append(Vector2i(d, f))
	return out


func has_face_mod() -> bool:
	return not modded_faces().is_empty()


func set_face(die_i: int, face_i: int, mod_id: StringName) -> bool:
	if die_i < 0 or die_i >= dice.size() or face_i < 0 or face_i >= dice[die_i].faces.size():
		return false
	dice[die_i].faces[face_i] = mod_id
	changed.emit()
	return true


func seal_level(combo: StringName) -> int:
	return seal_levels.get(combo, 0)


func add_seal_levels(combo: StringName, levels: int) -> void:
	if combo == &"" or levels == 0:
		return
	seal_levels[combo] = maxi(seal_level(combo) + levels, 0)
	changed.emit()


## Count banked pots, one entry per pot (TableOutcome.banked_combos).
func record_banks(combos: Array) -> void:
	for c in combos:
		record_bank(StringName(c))


func record_bank(combo: StringName) -> void:
	if combo != &"":
		banked[combo] = banked.get(combo, 0) + 1


## The combo banked most this run; &"" if none. Ties go to the higher-ranked
## combo (later in RunData.seal_combos, e.g. run3 beats pair). Single isn't
## a Seal combo, so banked singles never count.
func most_banked() -> StringName:
	var best: StringName = &""
	var best_n: int = 0
	for c in data.seal_combos:
		var n: int = banked.get(c, 0)
		if n > 0 and n >= best_n:
			best = c
			best_n = n
	return best


## Base / mult the Seals add to `combo` on top of its starting values.
func seal_bonus(combo: StringName) -> Vector2i:
	var lv: int = seal_level(combo)
	var m: Vector2i = seal_moves.get(combo, Vector2i.ZERO)
	return Vector2i(lv * int(data.seal_base_step.get(combo, 0)) + m.x, lv * int(data.seal_mult_step.get(combo, 0)) + m.y)


## Transference Seal: move up to transference_max_mult mult, and the matching
## base (the source's base per mult), from one combo to another. A combo
## never goes below its starting values. Returns the mult moved (0 = refused).
func transference(from: StringName, to: StringName, mult: int) -> int:
	if from == to or not data.seal_combos.has(from) or not data.seal_combos.has(to):
		return 0
	var b := seal_bonus(from)
	var moved: int = mini(mini(mult, data.transference_max_mult), b.y)
	if moved <= 0:
		return 0
	var per: int = int(data.seal_base_step.get(from, 0)) / maxi(int(data.seal_mult_step.get(from, 1)), 1)
	var base: int = mini(moved * per, b.x)
	seal_moves[from] = seal_moves.get(from, Vector2i.ZERO) - Vector2i(base, moved)
	seal_moves[to] = seal_moves.get(to, Vector2i.ZERO) + Vector2i(base, moved)
	changed.emit()
	return moved


## Black Seal: +1 level to the most-banked combo. False if nothing banked yet.
func black_seal() -> bool:
	var c := most_banked()
	if c == &"":
		return false
	add_seal_levels(c, 1)
	return true


## Ashen Seal: reset `from` to Lv1 and move its levels to `to`, which must be
## the same or a rarer combo (later in seal_combos). Returns the levels moved.
func ashen_seal(from: StringName, to: StringName) -> int:
	var i: int = data.seal_combos.find(from)
	var j: int = data.seal_combos.find(to)
	var lv: int = seal_level(from)
	if i < 0 or j < 0 or j < i or from == to or lv <= 0:
		return 0
	seal_levels[from] = 0
	add_seal_levels(to, lv)
	return lv


## A contract piece (one per boss): +contract_max_soul max Soul, heal to full.
func gain_contract_piece() -> void:
	contract_pieces += 1
	max_soul += data.contract_max_soul
	soul = max_soul
	changed.emit()


## The handful as the Bonfire table throws it: each RunDie as a TableDie with
## its run die id, special kind (TableDie.special), the special die's face
## values / weights, its per-face mods, and Heavy faces weighted
## RunData.heavy_weight (the table doesn't read Heavy itself).
func table_dice() -> Array[TableDie]:
	var lib: Array = data.face_mods.duplicate()
	var blank: FaceModData = load("res://resources/mods/blank.tres")
	if not lib.has(blank):
		lib.append(blank)
	var out: Array[TableDie] = []
	for d in dice:
		var sd := special_die(d.special_id)
		var sh := shape_data(d.shape) if d.shape != &"d6" else null
		var def: SpecialDieData = sd if sd != null else sh
		var td := TableDie.from_mod_ids(d.faces, lib, def.id if def != null else &"bone",
			def.display_name if def != null else "Bone", sd.id if sd != null else &"")
		td.run_die_id = d.id
		if def != null:
			td.faces = def.faces.duplicate()
			td.weights = def.weights.duplicate()
		# N-sided: faces / weights / mods sized to the shape (TableDie.shape
		# arrives with Godot Dev's shape commit; until then the table plays d6).
		td.mods.resize(td.faces.size())
		for i in td.faces.size():
			td.mods[i] = _mod_from(lib, d.faces[i] if i < d.faces.size() else &"")
		if "shape" in td:
			td.set("shape", d.shape)
		var heavy := false
		for m in td.mods:
			heavy = heavy or (m != null and (m as FaceModData).effect == FaceModData.Effect.HEAVY)
		if heavy:
			if td.weights.size() != td.faces.size():
				td.weights.clear()
				for i in td.faces.size():
					td.weights.append(1.0)
			for i in td.faces.size():
				var m: FaceModData = td.mods[i]
				if m != null and m.effect == FaceModData.Effect.HEAVY:
					td.weights[i] *= data.heavy_weight
		out.append(td)
	return out


func _mod_from(lib: Array, id: StringName) -> FaceModData:
	if id == &"":
		return null
	for m in lib:
		if m != null and (m as FaceModData).id == id:
			return m
	return null


## A copy of `base` with Seal levels added to each combo's base and mult
## (build content: Pair +5/+1 per level, ...). The table plays this copy.
func leveled_tuning(base: BonfireTuning) -> BonfireTuning:
	var t := base.duplicate() as BonfireTuning
	var combos: Array[BonfireCombo] = []
	for c in base.combos:
		var copy := c.duplicate() as BonfireCombo
		var b := seal_bonus(c.id)
		copy.base += b.x
		copy.mult += b.y
		combos.append(copy)
	t.combos = combos
	t.starting_soul = soul
	return t
