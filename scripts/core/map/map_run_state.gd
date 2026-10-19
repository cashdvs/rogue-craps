## Shared state of a Bonfire run (MapRun): the screen, floor, map, boss,
## table goal and rules, reward / shop / rest offers, the seeded RNG, and
## the Seal helpers the reward, shop and rest screens all use. MapRun (flow)
## extends MapRunShop (shop + rest), which extends this.
class_name MapRunState
extends RefCounted

enum Screen { MAP, TABLE, EVENT, SHOP, REST, REWARD, RUN_WON, RUN_OVER }
const NT := MapGenData.NodeType

signal screen_changed(screen: Screen)

var data: RunData
var progress: RunProgress
var run_seed: int = 0
var floor_index: int = 0
var map: RunMap
var screen: Screen = Screen.MAP

## This floor's boss (its cheat), drawn on entering the floor and shown on the map.
var boss: RunRuleData
## Floor 3: the boss's extra Elite twist (else null).
var boss_twist: RunRuleData

## Table / Elite / Boss being played.
var goal: TableGoal
var table_type: NT = NT.TABLE
## Elite: its twist; Boss: cheat (+ twist). Passed to the table in the setup.
var rules: Array[RunRuleData] = []
var boss_misses: int = 0
## Tables (any kind) cleared this run, for the end summary.
var tables_cleared: int = 0
## Why the run ended: &"soul" (Soul ran out), &"boss" (missed the boss and
## its re-sit), &"contract" (last boss beaten without every piece), &"won".
var end_reason: StringName = &""

## Reward screen: Seal options (combo ids, or rare Seal ids) and Elite dice.
var seal_options: Array[StringName] = []
var dice_options: Array[SpecialDieData] = []

var event: EventData
var _events_seen: Array[StringName] = []

## Shop offers (bought ones become null / &"").
var shop_dice: Array[SpecialDieData] = []
var shop_mods: Array[FaceModData] = []
var shop_seals: Array[StringName] = []
var shop_seals_bought: int = 0
## The guaranteed rare Seal offer (P4); &"" once bought or when off.
var shop_premium_seal: StringName = &""
var shop_rerolls: int = 0
## Free (event) rerolls spent this shop visit; only seeds the new stock.
var shop_free_rerolls: int = 0
## Soul Draughts bought this run (never reset: the price rises per run).
var soul_draughts_bought: int = 0
## Rest: the face mod the free carve offers.
var rest_mod: FaceModData


## The FloorData of the floor being played.
func floor_data() -> FloorData:
	return data.floors[floor_index]


func _rng(purpose: StringName, extra: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([run_seed, floor_index, map.current_id if map != null else -1, purpose, extra])
	return r


func _set_screen(s: Screen) -> void:
	screen = s
	screen_changed.emit(s)


static func _pick_rule(pool: Array[RunRuleData], rng: RandomNumberGenerator) -> RunRuleData:
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else null


func _seal_offers(rng: RandomNumberGenerator, n: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var pool: Array[StringName] = data.seal_combos.duplicate()
	while out.size() < n and not pool.is_empty():
		if not data.rare_seals.is_empty() and rng.randf() < data.rare_seal_chance:
			var r: StringName = data.rare_seals[rng.randi_range(0, data.rare_seals.size() - 1)]
			if not out.has(r):
				out.append(r)
				continue
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


## Is `id` a rare Seal (Black, Transference, Ashen) rather than a combo?
func is_rare_seal(id: StringName) -> bool:
	return data.rare_seals.has(id)


## Can Seal `id` be used right now with these choices? Rare Seals take
## params: Transference {"from", "to"}, Ashen {"from", "to"}; Black none.
func seal_usable(id: StringName, params: Dictionary = {}) -> bool:
	match id:
		&"black":
			return progress.most_banked() != &""
		&"transference":
			var f: StringName = params.get("from", &"")
			return progress.seal_bonus(f).y > 0 and data.seal_combos.has(params.get("to", &"")) and params.get("to") != f
		&"ashen":
			var f: StringName = params.get("from", &"")
			var i: int = data.seal_combos.find(f)
			var j: int = data.seal_combos.find(params.get("to", &""))
			return progress.seal_level(f) > 0 and i >= 0 and j > i
	return data.seal_combos.has(id)


func _grant_seal(id: StringName, params: Dictionary) -> bool:
	if not seal_usable(id, params):
		return false
	match id:
		&"black":
			progress.black_seal()
		&"transference":
			progress.transference(params["from"], params["to"], data.transference_max_mult)
		&"ashen":
			progress.ashen_seal(params["from"], params["to"])
		_:
			progress.add_seal_levels(id, 1)
	return true


## A face a new mod can go on: unmodded, or Blank (carving over a curse).
func free_face(pick: Vector2i) -> bool:
	return pick.x >= 0 and pick.x < progress.dice.size() and pick.y >= 0 and pick.y < progress.dice[pick.x].faces.size() \
		and progress.dice[pick.x].faces[pick.y] in [&"", RunDie.BLANK]


## Combos with at least one Seal level.
func owned_seals() -> Array[StringName]:
	var out: Array[StringName] = []
	for c in data.seal_combos:
		if progress.seal_level(c) > 0:
			out.append(c)
	return out

