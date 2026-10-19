## Headless test: DiceIds (scripts/data/dice_ids.gd) is unique, snake_case and self-consistent,
## and every die id used by main's resources/dice is in the map. See docs/DICE_IDS.md.
##
## Run:
##   godot --headless --path . --script res://tests/test_dice_ids.gd
extends SceneTree

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
	_test_resources("res://resources/dice")
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


func _test_helpers() -> void:
	_check(DiceIds.canonical(&"ferryman_d2") == &"ferryman", "ferryman_d2 -> ferryman")
	_check(DiceIds.canonical(&"keg") == &"powder_keg", "keg -> powder_keg")
	_check(DiceIds.canonical(&"nope") == &"", "unknown id -> empty")
	_check(DiceIds.shape_of(&"ferryman") == &"coin", "ferryman is a coin")
	_check(DiceIds.asset_key(&"ferryman") == &"ferryman_coin", "asset key ferryman_coin")
	_check(DiceIds.asset_key(&"mirror") == &"mirror_d6", "asset key mirror_d6 matches main's art")
	_check(DiceIds.face_key(&"verdict", 20) == &"verdict_20", "face key verdict_20")
	_check(DiceIds.face_key(&"keg", 3) == &"powder_keg_3", "face key powder_keg_3")
	_check(DiceIds.display_name(&"verdict") == "Verdict", "display name")
	_check(not DiceIds.is_snake_case("Verdict") and not DiceIds.is_snake_case("a__b"), "snake_case rejects bad ids")


## Every `id = &"..."` in a die resource under [param dir] must be a canonical die id.
func _test_resources(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		_check(false, "open " + dir)
		return
	for sub in da.get_directories():
		_test_resources(dir + "/" + sub)
	for f in da.get_files():
		if not f.ends_with(".tres"):
			continue
		var path := dir + "/" + f
		var res := load(path)
		if res == null or not ("id" in res):
			continue
		_check(DiceIds.is_die(res.id), "%s id %s is in DiceIds.ALL" % [path, res.id])
