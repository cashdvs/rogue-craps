## Dev sandbox (Cash, Oct 31): build a MapRun that opens straight on one
## event (shop, Table, Elite, Boss) of a chosen floor, with the run's
## starting 5-die bag and the real table_goals_v1 target from FloorData.
## Pure logic; SandboxScreen and tests call it. Debug builds only.
class_name SandboxPreset
extends RefCounted

const NT := MapGenData.NodeType
const EVENTS: Array[StringName] = [&"table", &"elite", &"boss", &"shop"]
const RULES_DIR := "res://resources/map/rules/%s.tres"

var event: StringName = &"table"
var floor_num: int = 1
## &"" = the floor's seeded boss draw.
var boss_id: StringName = &""
var seed_value: int = 1


## Read --sandbox=, --boss=, --floor=, --seed= from user args. Returns null
## when there is no --sandbox flag.
static func from_args(args: PackedStringArray) -> SandboxPreset:
	var p := SandboxPreset.new()
	var found := false
	for a in args:
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"sandbox":
				found = true
				p.event = StringName(kv[1])
			"boss":
				p.boss_id = StringName(kv[1])
			"floor":
				p.floor_num = clampi(kv[1].to_int(), 1, 3)
			"seed":
				p.seed_value = kv[1].to_int()
	return p if found else null


## Boss ids on this floor's pool (FloorData.boss_cheats).
static func boss_ids(data: RunData, floor_n: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for r in data.floors[clampi(floor_n, 1, data.floors.size()) - 1].boss_cheats:
		out.append(r.resource_path.get_file().get_basename() as StringName)
	return out


## The run, already on this preset's event screen.
func build(data: RunData) -> MapRun:
	var run := MapRun.new(data, seed_value)
	var f := clampi(floor_num, 1, data.floors.size()) - 1
	if f != 0:
		run._start_floor(f)
	if boss_id != &"" and ResourceLoader.exists(RULES_DIR % boss_id):
		run.boss = load(RULES_DIR % boss_id) as RunRuleData
	var t: NT = {&"table": NT.TABLE, &"elite": NT.ELITE, &"boss": NT.BOSS, &"shop": NT.SHOP}.get(event, NT.TABLE)
	var id := run.map.boss_id if t == NT.BOSS else _first_of(run.map, t)
	if id < 0:  # this floor's map rolled none: take any row-0 node
		id = run.map.row_nodes(0)[0].id
	run.map.current_id = id
	run.map.visited.append(id)
	if t == NT.SHOP:
		run._roll_shop()
		run._set_screen(MapRunState.Screen.SHOP)
	else:
		run.table_type = t
		run.goal = run.make_goal(t)
		run._set_screen(MapRunState.Screen.TABLE)
	return run


static func _first_of(map: RunMap, t: NT) -> int:
	var ids := map.nodes.keys()
	ids.sort()
	for id in ids:
		if map.nodes[id].type == t:
			return id
	return -1
