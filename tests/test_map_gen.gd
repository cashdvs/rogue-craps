## Headless tests for the floor map: MapGenerator rules over many seeds
## (shape, connectivity, no crossing edges, type constraints, determinism)
## and RunMap travel (reachable nodes, visited, boss).
##
## Run:
##   godot --headless --path . --script res://tests/test_map_gen.gd
extends SceneTree

const NT := MapGenData.NodeType
const SEEDS: int = 500

var _passed: int = 0
var _failed: int = 0
var _data: MapGenData


func _initialize() -> void:
	print("=== Dice of the Damned: map generation tests ===")
	_data = load("res://resources/map/floor_1_map.tres") as MapGenData
	_check(_data != null and _data.is_valid(), "data: floor 1 map rules load and are valid")
	if _data == null:
		quit(1)
		return
	_test_shape()
	_test_types()
	_test_determinism()
	_test_travel()
	_test_custom_rules()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_data = null
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _test_shape() -> void:
	var boss_ok: bool = true
	var linked: bool = true
	var reach: bool = true
	var no_cross: bool = true
	var branches: bool = true
	var steps: bool = true
	var lanes: bool = true
	var links: bool = true
	for s in SEEDS:
		var m := MapGenerator.generate(_data, s)
		var boss := m.node(m.boss_id)
		boss_ok = boss_ok and boss.type == NT.BOSS and boss.next.is_empty() and boss.row == _data.rows \
			and boss.prev.size() == m.row_nodes(_data.rows - 1).size()
		branches = branches and m.row_nodes(0).size() >= 2
		lanes = lanes and m.columns >= 3 and m.columns <= 4
		for n: MapNode in m.nodes.values():
			if n.id != m.boss_id:
				linked = linked and not n.next.is_empty()
				links = links and (n.row == _data.rows - 1 or n.next.size() <= 2)
				for t in n.next:
					steps = steps and (t == m.boss_id or absi(m.node(t).col - n.col) <= _data.max_step)
			if n.row > 0:
				linked = linked and not n.prev.is_empty()
			else:
				reach = reach and m.connected_to_boss(n.id)
		for r in _data.rows - 1:
			var e: Array = []
			for n in m.row_nodes(r):
				for t in n.next:
					e.append([n.col, m.node(t).col])
			for a: Array in e:
				for b: Array in e:
					if (a[0] < b[0] and a[1] > b[1]):
						no_cross = false
	_check(lanes, "shape: 3-4 lanes per floor")
	_check(links, "shape: each node links to 1-2 nodes on the next row")
	_check(boss_ok, "shape: one Boss as row 8, every top-row node leads to it (%d seeds)" % SEEDS)
	_check(branches, "shape: at least two starting nodes")
	_check(linked, "shape: every node has a way in and a way out")
	_check(reach, "shape: every start reaches the boss")
	_check(steps, "shape: paths step at most max_step columns")
	_check(no_cross, "shape: no crossing edges")


func _test_types() -> void:
	var first: bool = true
	var rest_row: bool = true
	var min_rows: bool = true
	var repeats: bool = true
	var seen: Dictionary = {}
	var shops: bool = true
	var elites: bool = true
	var valid: bool = true
	for s in SEEDS:
		var m := MapGenerator.generate(_data, s)
		shops = shops and _every_path_has_shop(m, m.row_nodes(0), 2, 5)
		elites = elites and MapGenerator.count_type(m, NT.ELITE) >= 2
		valid = valid and MapGenerator.violations(_data, m).is_empty()
		for n: MapNode in m.nodes.values():
			seen[n.type] = true
			if n.row == 0:
				first = first and n.type == NT.TABLE
			if n.row == _data.rows - 1:
				rest_row = rest_row and n.type == NT.REST
			if n.type == NT.ELITE:
				min_rows = min_rows and n.row >= _data.elite_min_row
			if n.type == NT.SHOP:
				min_rows = min_rows and n.row >= _data.shop_min_row
			if n.type == NT.REST and n.row != _data.rows - 1:
				min_rows = min_rows and n.row >= _data.rest_min_row
			if _data.no_repeat_types.has(n.type):
				for t in n.next:
					repeats = repeats and m.node(t).type != n.type
	_check(_data.rows == 7 and _data.type_weights == PackedFloat32Array([45, 12, 22, 12, 9, 0]),
		"data: 7 rows + boss; weights Table 45 / Elite 12 / Event 22 / Shop 12 / Rest 9")
	_check(shops, "types: every path passes a Shop in rows 3-6 (%d seeds)" % SEEDS)
	_check(elites, "types: at least 2 Elites per floor")
	_check(valid, "types: generator reports no violations")
	_check(first, "types: row 1 is all Tables")
	_check(rest_row, "types: row 7 is all Rest")
	_check(min_rows, "types: no Elite before row 3")
	_check(repeats, "types: no Shop->Shop or Rest->Rest (or Elite->Elite) along a path")
	_check(seen.size() == NT.size(), "types: all six types appear across seeds")


func _ids(m: RunMap) -> Array:
	var out: Array = []
	for id in m.nodes.keys():
		var n: MapNode = m.nodes[id]
		out.append([n.id, n.type, n.next])
	out.sort()
	return out


func _test_determinism() -> void:
	_check(_ids(MapGenerator.generate(_data, 7)) == _ids(MapGenerator.generate(_data, 7)), "seed: same seed -> same map")
	var differs: bool = false
	for s in range(1, 10):
		if _ids(MapGenerator.generate(_data, s)) != _ids(MapGenerator.generate(_data, 0)):
			differs = true
	_check(differs, "seed: other seeds give other maps")


func _test_travel() -> void:
	var m := MapGenerator.generate(_data, 3)
	var starts := m.reachable()
	_check(starts.size() == m.row_nodes(0).size() and m.current_id == -1, "travel: start can pick any row-0 node")
	_check(not m.travel_to(m.boss_id), "travel: can't jump to the boss")
	var moves: int = 0
	while not m.at_boss():
		var r := m.reachable()
		if r.is_empty() or not m.travel_to(r[r.size() - 1]):
			break
		moves += 1
	_check(m.at_boss() and moves == _data.rows + 1 and m.visited.size() == moves, "travel: a path reaches the boss in rows + 1 moves")
	_check(m.reachable().is_empty(), "travel: nothing after the boss")
	var m2 := MapGenerator.generate(_data, 3)
	m2.travel_to(starts[0])
	var other_row0: bool = starts.size() > 1 and not m2.can_travel(starts[1])
	_check(other_row0, "travel: can't move sideways on the same row")


func _test_custom_rules() -> void:
	var d := _data.duplicate() as MapGenData
	d.type_weights = PackedFloat32Array([0, 0, 0, 1, 0, 0])
	d.rest_before_boss = false
	d.min_elites = 0
	var m := MapGenerator.generate(d, 11)
	var ok: bool = true
	for n: MapNode in m.nodes.values():
		if n.type == NT.SHOP:
			for t in n.next:
				ok = ok and m.node(t).type != NT.SHOP
	_check(ok, "rules: shop-only weights still never chain shops (fallback type fills in)")
	var top_rest: bool = true
	for n in m.row_nodes(d.rows - 1):
		top_rest = top_rest and n.type != NT.REST
	_check(top_rest, "rules: rest_before_boss off -> no forced Rest row")


## Independent check (not the generator's own): DFS every path, rows from..to 0-based.
func _every_path_has_shop(m: RunMap, starts: Array[MapNode], from: int, to: int) -> bool:
	for n in starts:
		if n.row >= from and n.row <= to and n.type == NT.SHOP:
			continue
		if n.id == m.boss_id:
			return false
		var kids: Array[MapNode] = []
		for id in n.next:
			kids.append(m.node(id))
		if not _every_path_has_shop(m, kids, from, to):
			return false
	return true
