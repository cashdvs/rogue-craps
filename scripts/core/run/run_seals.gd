## Seal levels per combo, the rare Seals' moves (Transference, Black,
## Ashen) and the combos banked this run. RunProgress extends this.
class_name RunSeals
extends RefCounted

signal changed()

var data: RunData
## Combo id -> Seal levels gained (0 = base combo from bonfire_tuning.tres).
var seal_levels: Dictionary[StringName, int] = {}
## Combo id -> base / mult moved by Transference (x = base, y = mult).
var seal_moves: Dictionary[StringName, Vector2i] = {}
## Combo id -> times banked this run (Black Seal). The table reports these.
var banked: Dictionary[StringName, int] = {}


## Seal levels gained on `combo` (0 = none; the first Seal is Lv1).
func seal_level(combo: StringName) -> int:
	return seal_levels.get(combo, 0)


## Add (or remove) Seal levels on `combo`, never below 0.
func add_seal_levels(combo: StringName, levels: int) -> void:
	if combo == &"" or levels == 0:
		return
	seal_levels[combo] = maxi(seal_level(combo) + levels, 0)
	changed.emit()


## Count banked pots, one entry per pot (TableOutcome.banked_combos).
func record_banks(combos: Array) -> void:
	for c in combos:
		record_bank(StringName(c))


## Count one banked pot of `combo` (Black Seal).
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
