## Everything that persists between nodes on a Bonfire run: Soul, Embers,
## the handful of dice (with face mods), Seal levels per combo (plus the
## rare Seals' moves), combos banked, and contract pieces.
##
## Pure logic: events, rests, the shop and table results all change it
## through these methods; views listen to `changed`. Seal levels, rare
## Seals and banked combos live in RunSeals (the base class).
class_name RunProgress
extends RunSeals

## Emitted once when Soul reaches 0 (the run ends).
signal run_ended()

var soul: int
var max_soul: int
var embers: int
var dice: Array[RunDie] = []
var contract_pieces: int = 0
## Every Ember gained this run (spending doesn't lower it), for the end summary.
var embers_earned: int = 0
## Free shop rerolls from events (spent before paid ones; they stack).
var free_rerolls: int = 0
## A twist an event put on the next table (MapRun.make_goal uses and clears it).
var next_table_twist: RunRuleData
var _next_die_id: int = 0


func _init(run_data: RunData) -> void:
	data = run_data
	max_soul = data.max_soul
	soul = data.starting_soul
	embers = data.starting_embers
	for i in data.starting_dice:
		dice.append(_new_die(&""))


## True once Soul is 0 (the run is lost).
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


## Change Embers (never below 0); gains count toward embers_earned. Returns the real change.
func change_embers(delta: int) -> int:
	var before: int = embers
	embers = maxi(embers + delta, 0)
	embers_earned += maxi(embers - before, 0)
	if embers != before:
		changed.emit()
	return embers - before


## Room for another die (bag below RunData.max_dice)?
func can_add_die() -> bool:
	return dice.size() < data.max_dice


## The SpecialDieData with this id, or null.
func special_die(id: StringName) -> SpecialDieData:
	for d in data.special_dice:
		if d.id == id:
			return d
	return null


## The DieShape with this id, or null.
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
		var d := dice[die_i]
		var sh := shape_data(d.shape) if d.shape != &"d6" else null
		for f in d.modded_faces():
			if d.faces[f] != RunDie.BLANK and not (sh != null and sh.is_preset(f, d.faces[f])):
				n += 1
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


## Index of the die with run id `id`, or -1.
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


## Owns at least one real face mod (Blank doesn't count).
func has_face_mod() -> bool:
	return not modded_faces().is_empty()


## Put mod `mod_id` (&"" = clear) on face face_i of die die_i. False if out of range.
func set_face(die_i: int, face_i: int, mod_id: StringName) -> bool:
	if die_i < 0 or die_i >= dice.size() or face_i < 0 or face_i >= dice[die_i].faces.size():
		return false
	dice[die_i].faces[face_i] = mod_id
	changed.emit()
	return true


## Max Soul +/- delta, never below 1. A raise also heals delta (Game
## Designer); a cut trims Soul to the new max. Returns the real change.
func change_max_soul(delta: int) -> int:
	var before := max_soul
	max_soul = maxi(1, max_soul + delta)
	soul = mini(soul + maxi(max_soul - before, 0), max_soul)
	changed.emit()
	return max_soul - before


## Can a die be sold or given up (the bag stays at the starting size or more)?
func can_lose_die() -> bool:
	return dice.size() > data.starting_dice


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
	var lib := _table_lib()
	var shaped := "shape" in TableDie.new()
	var out: Array[TableDie] = []
	for d in dice:
		out.append(_table_die(d, lib, shaped))
	return out


## Die i as the table gets it once TableDie has `shape` (Godot Dev's spec):
## faces / weights / mods sized to the shape, e.g. Ferryman's Coin =
## special &"ferryman", faces [heads, tails], weights [1, 1], shape &"coin".
func shaped_table_die(die_i: int) -> TableDie:
	return _table_die(dice[die_i], _table_lib(), true)


func _table_lib() -> Array:
	var lib: Array = data.face_mods.duplicate()
	var blank: FaceModData = load("res://resources/mods/blank.tres")
	if not lib.has(blank):
		lib.append(blank)
	return lib


func _table_die(d: RunDie, lib: Array, shaped: bool) -> TableDie:
	var sd := special_die(d.special_id)
	var sh := shape_data(d.shape) if d.shape != &"d6" else null
	var def: SpecialDieData = sd if sd != null else sh
	var td := TableDie.from_mod_ids(d.faces, lib, def.id if def != null else &"bone",
		def.display_name if def != null else "Bone", sd.id if sd != null else (sh.table_special if sh != null else &""))
	td.run_die_id = d.id
	if def != null:
		td.faces = def.faces.duplicate()
		td.weights = def.weights.duplicate()
	td.mods.resize(td.faces.size())
	for i in td.faces.size():
		td.mods[i] = _mod_from(lib, d.faces[i] if i < d.faces.size() else &"")
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
	if "shape" in td:
		td.set("shape", d.shape)
	if not shaped:
		_to_d6_slots(td)
	return td


## Until TableDie has a `shape` (Godot Dev's shape commit) the table rolls
## and labels a 6-slot d6 mesh, so a Coin / d3 is sent as 6 slots with the
## same odds: each value (with its mod and weight) on 6/N physical slots,
## e.g. Ferryman's Coin -> 5,5,5,1,1,1 (the Powder Keg is already 6 faces).
## Face counts that don't divide 6 (d4, d8+, Knucklebone; all disabled)
## are left N-sized.
func _to_d6_slots(td: TableDie) -> void:
	var n := td.faces.size()
	if n == 6 or n == 0 or 6 % n != 0:
		return
	var rep := 6 / n
	var faces: Array[int] = []
	var mods: Array = []
	var weights: Array[float] = []
	for i in 6:
		var k := i / rep
		faces.append(td.faces[k])
		mods.append(td.mods[k])
		if td.weights.size() == n:
			weights.append(td.weights[k])
	td.faces = faces
	td.mods.assign(mods)
	td.weights = weights


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
