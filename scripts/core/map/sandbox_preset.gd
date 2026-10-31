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


## Event id -> node type; an unknown id push_errors and falls back to a
## regular Table (`event` is set to &"table" so the fallback shows).
func node_type() -> NT:
	var types := {&"table": NT.TABLE, &"elite": NT.ELITE, &"boss": NT.BOSS, &"shop": NT.SHOP}
	if not types.has(event):
		push_error("SandboxPreset: unknown --sandbox=%s (use %s); opening a regular table." % [event, EVENTS])
		event = &"table"
	return types[event]


## The run, already on this preset's event screen.
func build(data: RunData) -> MapRun:
	var run := MapRun.new(data, seed_value)
	var t := node_type()
	run.sandbox_floor(clampi(floor_num, 1, data.floors.size()) - 1)
	var forced: RunRuleData = null
	if boss_id != &"":
		if ResourceLoader.exists(RULES_DIR % boss_id):
			forced = load(RULES_DIR % boss_id) as RunRuleData
		else:
			push_error("SandboxPreset: unknown --boss=%s; using the seeded boss." % boss_id)
	var id := run.map.boss_id if t == NT.BOSS else _first_of(run.map, t)
	if id < 0:  # this floor's map rolled none: take any row-0 node
		id = run.map.row_nodes(0)[0].id
	run.enter_for_sandbox(t, id, forced)
	return run


static func _first_of(map: RunMap, t: NT) -> int:
	var ids := map.nodes.keys()
	ids.sort()
	for id in ids:
		if map.nodes[id].type == t:
			return id
	return -1
