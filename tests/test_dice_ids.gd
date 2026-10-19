## Headless test: DiceIds (scripts/data/dice_ids.gd) is unique, snake_case and self-consistent,
## every die id used by main's resources/dice is in the map, and die ids don't collide with
## face-mod ids (resources/mods). See docs/DICE_IDS.md.
##
## Run:
##   godot --headless --path . --script res://tests/test_dice_ids.gd
extends SceneTree

## Die resources with an `id` on main: the 9 in resources/dice/special (standard_d6.tres has no id).
## An empty or unreadable folder must fail, not pass with zero checks.
const MIN_DIE_RESOURCES := 9
## Face mods on main (resources/mods): blank, blood, ember_pip, gilded, heavy, hellfire, kindling,
## stair, step, twin, wild.
const MIN_FACE_MODS := 11

## Every alias DiceIds.ALIASES must hold, spelled out so removing or retargeting one fails.
const EXPECTED_ALIASES: Dictionary = {
	&"standard": &"bone", &"standard_d6": &"bone",
	&"ferrymans_coin": &"ferryman", &"ferryman_d2": &"ferryman",
	&"keg": &"powder_keg", &"powder_keg_d3": &"powder_keg",
	&"knucklebone_talus": &"knucklebone",
	&"caltrop_d4": &"caltrop", &"lantern_d8": &"lantern", &"tithe_d10": &"tithe",
	&"midnight_d12": &"midnight", &"verdict_d20": &"verdict",
}

var _fails: int = 0
var _checks: int = 0


func _check(ok: bool, msg: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		push_error("FAIL: " + msg)
		print("FAIL: ", msg)


func _init() -> void:
	_test_ids()
	_test_aliases()
	_test_helpers()
	_test_asset_only_keys()
	var n := _test_resources("res://resources/dice")
	_check(n >= MIN_DIE_RESOURCES,
		"checked >= %d die resources with an id (got %d)" % [MIN_DIE_RESOURCES, n])
	_test_face_mod_collisions("res://resources/mods")
	print("test_dice_ids: %d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _test_ids() -> void:
	for s in DiceIds.SHAPES:
		_check(DiceIds.is_snake_case(String(s)), "shape id snake_case: %s" % s)
		_check(int(DiceIds.SHAPES[s]) >= 2, "shape %s has >= 2 faces" % s)
	for d in DiceIds.ALL:
		_check(DiceIds.is_snake_case(String(d)), "die id snake_case: %s" % d)
		_check(not DiceIds.SHAPES.has(d), "die id %s is not also a shape id" % d)
		_check(DiceIds.SHAPES.has(DiceIds.ALL[d]["shape"]), "die %s has a known shape" % d)
		_check(String(DiceIds.ALL[d]["name"]) != "", "die %s has a display name" % d)
	var names := {}
	for d in DiceIds.ALL:
		names[DiceIds.ALL[d]["name"]] = true
	_check(names.size() == DiceIds.ALL.size(), "display names are unique")
	var keys := {}
	for d in DiceIds.ALL:
		keys[DiceIds.asset_key(d)] = true
	_check(keys.size() == DiceIds.ALL.size(), "asset keys are unique")


func _test_aliases() -> void:
	for a in DiceIds.ALIASES:
		_check(not DiceIds.ALL.has(a), "alias %s is not a canonical id" % a)
		_check(DiceIds.ALL.has(DiceIds.ALIASES[a]), "alias %s points at a canonical id" % a)
	_check(DiceIds.ALIASES.size() == EXPECTED_ALIASES.size(),
		"ALIASES has exactly %d entries (got %d)" % [EXPECTED_ALIASES.size(), DiceIds.ALIASES.size()])
	for a in EXPECTED_ALIASES:
		var want: StringName = EXPECTED_ALIASES[a]
		_check(DiceIds.ALIASES.get(a, &"") == want, "ALIASES[%s] == %s" % [a, want])
		_check(DiceIds.canonical(a) == want, "canonical(%s) -> %s" % [a, want])
		_check(DiceIds.shape_of(a) == DiceIds.shape_of(want), "shape_of(%s) == shape_of(%s)" % [a, want])


## Asset-only keys (retired / showcase models) have no die id and never shadow one.
func _test_asset_only_keys() -> void:
	for k in [&"knucklebone_d6", &"gilded_d6", &"hellfire_d6"]:
		_check(DiceIds.ASSET_ONLY_KEYS.has(k), "%s is listed as asset-only" % k)
	var asset_keys := {}
	for d in DiceIds.ALL:
		asset_keys[DiceIds.asset_key(d)] = true
	for k in DiceIds.ASSET_ONLY_KEYS:
		_check(DiceIds.is_snake_case(String(k)), "asset-only key snake_case: %s" % k)
		_check(not DiceIds.ALL.has(k), "asset-only key %s is not a die id" % k)
		_check(not DiceIds.ALIASES.has(k), "asset-only key %s is not an alias" % k)
		_check(DiceIds.canonical(k) == &"", "canonical(%s) is empty" % k)
		_check(not asset_keys.has(k), "asset-only key %s is no die's asset key" % k)


func _test_helpers() -> void:
	_check(DiceIds.canonical(&"ferryman_d2") == &"ferryman", "ferryman_d2 -> ferryman")
	_check(DiceIds.canonical(&"keg") == &"powder_keg", "keg -> powder_keg")
	_check(DiceIds.canonical(&"nope") == &"", "unknown id -> empty")
	_check(DiceIds.shape_of(&"ferryman") == &"coin", "ferryman is a coin")
	_check(DiceIds.asset_key(&"ferryman") == &"ferryman_coin", "asset key ferryman_coin")
	_check(DiceIds.asset_key(&"mirror") == &"mirror_d6", "asset key mirror_d6 matches main's art")
	_check(DiceIds.face_key(&"verdict", 20) == &"verdict_20", "face key verdict_20")
	_check(DiceIds.face_key(&"keg", 3) == &"powder_keg_3", "face key powder_keg_3")
	_check(DiceIds.face_key(&"nope", 20) == &"", "face key of an unknown die is empty")
	_check(DiceIds.shape_of(&"nope") == &"" and DiceIds.asset_key(&"nope") == &""
		and DiceIds.display_name(&"nope") == "", "other helpers return empty for an unknown die")
	_check(DiceIds.shape_of(&"powder_keg") == &"d6", "powder_keg shape is d6")
	_check(DiceIds.asset_key(&"powder_keg") == &"powder_keg_d6", "asset key powder_keg_d6")
	_check(DiceIds.canonical(&"powder_keg_d3") == &"powder_keg", "powder_keg_d3 -> powder_keg")
	_check(DiceIds.is_shape(&"d3"), "d3 remains a valid shape (no die today)")
	_check(DiceIds.shape_of(&"knucklebone") == &"talus", "knucklebone shape is talus")
	_check(DiceIds.canonical(&"standard") == &"bone", "standard -> bone")
	_check(DiceIds.display_name(&"verdict") == "Verdict", "display name")
	_check(not DiceIds.is_snake_case("Verdict") and not DiceIds.is_snake_case("a__b"), "snake_case rejects bad ids")


## Every `id = &"..."` in a die resource under [param dir] must be a canonical die id.
## Returns how many resources with an id it checked (recursively).
func _test_resources(dir: String) -> int:
	var da := DirAccess.open(dir)
	if da == null:
		_check(false, "open " + dir)
		return 0
	var n := 0
	for sub in da.get_directories():
		n += _test_resources(dir + "/" + sub)
	for f in da.get_files():
		if not f.ends_with(".tres"):
			continue
		var path := dir + "/" + f
		var res := load(path)
		if res == null or not ("id" in res):
			continue
		n += 1
		_check(DiceIds.is_die(res.id), "%s id %s is in DiceIds.ALL" % [path, res.id])
	return n


## Die ids, aliases and shape ids must not collide with face-mod ids: SfxManager.play_mod_trigger
## takes die ids and face-mod ids in one namespace.
func _test_face_mod_collisions(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		_check(false, "open " + dir)
		return
	var mods := {}
	for f in da.get_files():
		if not f.ends_with(".tres"):
			continue
		var res := load(dir + "/" + f)
		if res == null or not ("id" in res):
			continue
		mods[StringName(res.id)] = dir + "/" + f
	_check(mods.size() >= MIN_FACE_MODS,
		"found >= %d face-mod ids in %s (got %d)" % [MIN_FACE_MODS, dir, mods.size()])
	for m in mods:
		_check(not DiceIds.ALL.has(m), "face mod %s (%s) is not a die id" % [m, mods[m]])
		_check(not DiceIds.ALIASES.has(m), "face mod %s is not a die alias" % m)
		_check(not DiceIds.SHAPES.has(m), "face mod %s is not a shape id" % m)
