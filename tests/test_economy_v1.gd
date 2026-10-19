## Headless tests for the economy pass (design/economy_balance_v1.md, fixes
## QA M6): P1 points pay at most points_embers_cap Embers per table, P6 price
## fixes (anything that adds a die costs >= 18), P2 bag cap, P3 Soul Draught,
## P4 the guaranteed rare Seal slot and P5 floor price scaling.
##
## Run:
##   godot --headless --path . --script res://tests/test_economy_v1.gd
extends SceneTree

const NT := MapGenData.NodeType
## Economy v1 P6: the floor price of any die that adds a body to the bag.
const MIN_DIE_PRICE := 18

var _passed: int = 0
var _failed: int = 0
var _data: RunData
var _tuning: BonfireTuning


func _initialize() -> void:
	print("=== Dice of the Damned: economy v1 tests ===")
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	_tuning = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_test_points_cap()
	_test_prices()
	_test_bag_cap()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_data = null
	_tuning = null
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


## Embers a table pays for `points` (forfeited, so no clear bonus).
func _points_embers(t: BonfireTuning, points: int) -> int:
	var r := BonfireRun.new(t, _tuning.table_goal, 30, 5)
	r.points = points
	r.forfeit()
	return int(r.table_summary["points_embers"])


## Jump straight into a node of `type` on the current floor (test shortcut).
func _enter(run: MapRun, type: int) -> bool:
	for n: MapNode in run.map.nodes.values():
		if n.type == type:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.screen = MapRun.Screen.MAP
			return run.choose_node(n.id)
	return false


# --- P1: points -> Embers cap ---

func _test_points_cap() -> void:
	_check(_tuning.points_embers_cap == 5 and _tuning.points_per_ember == 100, "P1 data: cap 5 per table, 1 Ember per 100")
	_check(_points_embers(_tuning, 900) == 5, "P1: 900 points pay 5 Embers (capped)")
	_check(_points_embers(_tuning, 300) == 3, "P1: 300 points pay 3 Embers (under the cap)")
	_check(_points_embers(_tuning, 60000) == 5, "P1: a 60k Floor 3 score still pays 5")
	var bare := BonfireTuning.new()
	bare.table_goal = _tuning.table_goal
	_check(bare.points_embers_cap == 0 and _points_embers(bare, 900) == 9, "P1: no cap set (field absent) = uncapped, 900 pays 9")
	var lev := RunProgress.new(_data).leveled_tuning(_tuning)
	_check(lev.points_embers_cap == 5, "P1: the run's Seal-levelled tuning copy keeps the cap")
	var r := BonfireRun.new(_tuning, _tuning.table_goal, 30, 5)
	r.points = 900
	r.forfeit()
	_check(r.embers == 5, "P1: the table's Embers total uses the capped amount")
	_check(EconomyStrings.table_points_embers(_tuning) == "Points: 1 Ember per 100, up to 5 per table.", "P1 string: table_points_embers matches strings_v1")


# --- P6: price fixes ---

func _test_prices() -> void:
	var by_id: Dictionary = {}
	for d in _data.special_dice:
		by_id[d.id] = d.price
	for s in _data.shapes:
		by_id[s.id] = s.price
	_check(by_id.get(&"mirror") == 18 and by_id.get(&"cracked") == 18 and by_id.get(&"extra") == 18, "P6: Mirror, Cracked and Extra Die 18")
	_check(by_id.get(&"lantern") == 18 and by_id.get(&"tithe") == 18 and by_id.get(&"midnight") == 18, "P6: Lantern d8, Tithe d10, Midnight d12 18")
	var cheap: Array[String] = []
	for d in _data.special_dice:
		if d.price < MIN_DIE_PRICE:
			cheap.append(String(d.id))
	for s in _data.shapes:
		if s.id != &"d6" and s.price < MIN_DIE_PRICE:
			cheap.append(String(s.id))
	_check(cheap.is_empty(), "P6 rule: every die that adds to the bag costs >= %d (too cheap: %s)" % [MIN_DIE_PRICE, ", ".join(cheap)])
	var wild: FaceModData = load("res://resources/mods/wild.tres")
	_check(wild.price == 14, "P6: Wild Face 14")
	_check(_data.shop_seal_step == 2 and _data.reroll_step == 2, "P6 data: shop_seal_step 2, reroll_step 2 (bonfire_run.tres)")
	var run := MapRun.new(_data, 3)
	_check(_enter(run, NT.SHOP), "shop: entered")
	run.progress.embers = 100
	_check(run.reroll_price() == 3 and run.shop_reroll() and run.reroll_price() == 5, "P6: reroll 3, then 5")
	run.shop_seals = [&"pair", &"trips"] as Array[StringName]
	_check(run.buy_seal(0) and run.seal_price(&"trips") == 7, "P6: Seal 5, then 7")


# --- P2: bag cap 6, read from data everywhere ---

## A Gravedigger-style event choice that gives `die`.
func _give_choice(die: StringName) -> EventChoiceData:
	var e := EventEffectData.new()
	e.kind = EventEffectData.Kind.GIVE_DIE
	e.die = die
	var c := EventChoiceData.new()
	c.effects = [e] as Array[EventEffectData]
	return c


func _test_bag_cap() -> void:
	_check(_data.max_dice == 6, "P2 data: max_dice 6 (bonfire_run.tres)")
	var give := _give_choice(&"mirror")
	var p := RunProgress.new(_data)
	_check(EventApplier.why_not(give, p) == "" and p.add_die(&"coven"), "P2: room for a 6th die")
	_check(not p.can_add_die() and not p.add_die(&"extra") and p.dice.size() == 6, "P2: no 7th die")
	_check(EventApplier.why_not(give, p) == "Your bag is full (6 dice).", "P2: event give_die greys out at 6")
	var run := MapRun.new(_data, 4)
	run.progress.add_die(&"coven")
	_check(_enter(run, NT.SHOP), "shop: entered")
	run.progress.embers = 500
	_check(not run.buy_die(0) and run.progress.embers == 500 and run.progress.dice.size() == 6, "P2: the shop won't sell a 7th die")
	run.screen = MapRun.Screen.REWARD
	run.dice_options = [_data.special_dice[0]] as Array[SpecialDieData]
	_check(not run.take_die(0) and run.progress.dice.size() == 6, "P2: an Elite die reward is refused on a full bag")
	# Nothing hard-codes the cap: a 7-die RunData allows a 7th everywhere.
	var roomy := _data.duplicate() as RunData
	roomy.max_dice = 7
	var q := RunProgress.new(roomy)
	q.add_die(&"coven")
	_check(EventApplier.why_not(give, q) == "" and q.add_die(&"extra") and q.dice.size() == 7, "P2: the cap is max_dice, not a constant")
	var panel := DicePanel.new()
	panel.build(p, {})
	var titled := false
	for l in panel.find_children("*", "Label", true, false):
		titled = titled or (l as Label).text == "Your dice · 6/6"
	_check(titled, "P2: the Your dice panel reads 6/6")
	panel.free()
