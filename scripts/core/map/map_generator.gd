## Builds a seeded RunMap from MapGenData (Slay the Spire style; map spec 1).
##
## 1. Roll the lane count, then walk `paths` paths from row 0 to the last row.
##    Each step moves at most `max_step` lanes sideways, never crosses an
##    edge already drawn, and a node never links to more than `max_links`.
## 2. Every cell a path touched becomes a node; path steps become edges.
##    All last-row nodes lead to a single Boss node.
## 3. Types are picked row by row by weight, rerolled until they obey the
##    local rules (earliest rows, no Shop -> Shop / Rest -> Rest).
## 4. Repairs for the floor-wide rules: a Shop is placed on any path that
##    has none in the guarantee rows, then Tables become Elites until there
##    are min_elites. If a rule still fails, the whole map is rerolled.
## Same data + same seed = the same map. Only the seeded RNG is used.
class_name MapGenerator
extends RefCounted

const NT := MapGenData.NodeType


static func generate(data: MapGenData, seed_value: int) -> RunMap:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var m: RunMap = null
	for attempt in data.max_attempts:
		m = _build(data, rng)
		_type_nodes(data, m, rng)
		_repair_shops(data, m, rng)
		_repair_elites(data, m, rng)
		if violations(data, m).is_empty():
			return m
	push_warning("MapGenerator: no valid map in %d attempts (seed %d)" % [data.max_attempts, seed_value])
	return m


static func _build(data: MapGenData, rng: RandomNumberGenerator) -> RunMap:
	var m := RunMap.new()
	m.rows = data.rows
	m.columns = rng.randi_range(data.min_lanes, data.max_lanes)
	var cols: int = m.columns
	# edges[r] = Array of [from_col, to_col] between row r and r + 1.
	var edges: Array = []
	for r in data.rows - 1:
		edges.append([])
	var used: Dictionary = {}
	var starts: Array[int] = []
	for p in data.paths:
		var c: int = rng.randi_range(0, cols - 1)
		# The first two paths start apart so the map always branches at once.
		if p == 1 and cols > 1 and starts.has(c):
			c = (c + 1 + rng.randi_range(0, cols - 2)) % cols
		starts.append(c)
		used[Vector2i(0, c)] = true
		for r in data.rows - 1:
			var to: int = rng.randi_range(maxi(0, c - data.max_step), mini(cols - 1, c + data.max_step))
			if _crosses(edges[r], c, to):
				to = c
			var outs: Array[int] = _targets(edges[r], c)
			if not outs.has(to) and outs.size() >= data.max_links:
				to = outs[rng.randi_range(0, outs.size() - 1)]
			if not edges[r].has([c, to]):
				edges[r].append([c, to])
			c = to
			used[Vector2i(r + 1, c)] = true
	for cell: Vector2i in used.keys():
		var id: int = cell.x * cols + cell.y
		m.nodes[id] = MapNode.new(id, cell.x, cell.y)
	for r in data.rows - 1:
		for e: Array in edges[r]:
			_link(m, r * cols + int(e[0]), (r + 1) * cols + int(e[1]))
	m.boss_id = data.rows * cols
	var boss := MapNode.new(m.boss_id, data.rows, (cols - 1) / 2)
	boss.type = NT.BOSS
	m.nodes[m.boss_id] = boss
	for n in m.row_nodes(data.rows - 1):
		_link(m, n.id, m.boss_id)
	return m


static func _targets(row_edges: Array, from_col: int) -> Array[int]:
	var out: Array[int] = []
	for e: Array in row_edges:
		if int(e[0]) == from_col:
			out.append(int(e[1]))
	return out


## Would an edge a -> b cross an existing edge in this row gap?
static func _crosses(row_edges: Array, a: int, b: int) -> bool:
	for e: Array in row_edges:
		var c: int = e[0]
		var d: int = e[1]
		if (a < c and b > d) or (a > c and b < d):
			return true
	return false


static func _link(m: RunMap, from_id: int, to_id: int) -> void:
	var f: MapNode = m.node(from_id)
	var t: MapNode = m.node(to_id)
	if not f.next.has(to_id):
		f.next.append(to_id)
		f.next.sort()
	if not t.prev.has(from_id):
		t.prev.append(from_id)
		t.prev.sort()


static func _type_nodes(data: MapGenData, m: RunMap, rng: RandomNumberGenerator) -> void:
	var weights := PackedFloat32Array()
	for t in NT.size():
		weights.append(data.weight_of(t) if t != NT.BOSS else 0.0)
	_type_pre_boss(data, m)
	for r in data.rows:
		if data.forced_pre_boss(r):
			continue
		for n in m.row_nodes(r):
			n.type = data.fallback_type
			if r == 0:
				n.type = data.first_row_type
				continue
			for i in data.max_type_tries:
				var t: int = rng.rand_weighted(weights)
				if t >= 0 and allowed(data, m, n, t):
					n.type = t
					break


## The forced row before the boss: all Rest, or (pre_boss_mix) even ids
## Shop and odd ids Rest, fixed so the row has at least one of each. Typed
## first, so the row below sees it in the no-repeat checks.
static func _type_pre_boss(data: MapGenData, m: RunMap) -> void:
	var row: Array = m.row_nodes(data.rows - 1)
	if not data.forced_pre_boss(data.rows - 1) or row.is_empty():
		return
	for n: MapNode in row:
		n.type = NT.REST if not data.pre_boss_mix or n.id % 2 == 1 else NT.SHOP
	if data.pre_boss_mix and row.size() > 1:
		row.sort_custom(func(a: MapNode, b: MapNode) -> bool: return a.id < b.id)
		var types: Array = row.map(func(n: MapNode) -> int: return n.type)
		if not types.has(NT.SHOP):
			row[0].type = NT.SHOP
		elif not types.has(NT.REST):
			row[-1].type = NT.REST


## Does type `t` obey the local rules at node `n`? Checks both neighbours,
## so it also works when a repair retypes a node after its children.
static func allowed(data: MapGenData, m: RunMap, n: MapNode, t: int) -> bool:
	if t == NT.BOSS or n.row == 0 or data.forced_pre_boss(n.row):
		return false
	if t == NT.ELITE and n.row < data.elite_min_row:
		return false
	if t == NT.SHOP and n.row < data.shop_min_row:
		return false
	if t == NT.REST and n.row < data.rest_min_row:
		return false
	if data.no_repeat_types.has(t):
		for id in n.prev + n.next:
			var o: MapNode = m.node(id)
			if o.type == t and o.id != m.boss_id:
				return false
			# The forced pre-boss row counts even before it's typed.
			if t == NT.REST and data.rest_before_boss and not data.pre_boss_mix and o.row == data.rows - 1:
				return false
	return true


## A path (as node ids) from row 0 to the boss with no Shop in the
## guarantee rows, or [] if every path has one.
static func shopless_path(data: MapGenData, m: RunMap) -> Array[int]:
	if data.shop_guarantee_from < 0:
		return []
	for start in m.row_nodes(0):
		var p: Array[int] = _shopless_from(data, m, start.id)
		if not p.is_empty():
			return p
	return []


static func _shopless_from(data: MapGenData, m: RunMap, id: int) -> Array[int]:
	var n: MapNode = m.node(id)
	if n.row >= data.shop_guarantee_from and n.row <= data.shop_guarantee_to and n.type == NT.SHOP:
		return []
	if id == m.boss_id:
		return [id]
	for t in n.next:
		var rest: Array[int] = _shopless_from(data, m, t)
		if not rest.is_empty():
			var out: Array[int] = [id]
			out.append_array(rest)
			return out
	return []


static func _repair_shops(data: MapGenData, m: RunMap, rng: RandomNumberGenerator) -> void:
	for guard in m.nodes.size():
		var p: Array[int] = shopless_path(data, m)
		if p.is_empty():
			return
		var options: Array[MapNode] = []
		for id in p:
			var n: MapNode = m.node(id)
			if n.row >= data.shop_guarantee_from and n.row <= data.shop_guarantee_to \
					and n.type != NT.ELITE and allowed(data, m, n, NT.SHOP):
				options.append(n)
		if options.is_empty():
			return
		options[rng.randi_range(0, options.size() - 1)].type = NT.SHOP


static func _repair_elites(data: MapGenData, m: RunMap, rng: RandomNumberGenerator) -> void:
	var options: Array[MapNode] = []
	for n: MapNode in m.nodes.values():
		if n.type == NT.TABLE:
			options.append(n)
	options.sort_custom(func(a: MapNode, b: MapNode) -> bool: return a.id < b.id)
	while count_type(m, NT.ELITE) < data.min_elites and not options.is_empty():
		var n: MapNode = options.pop_at(rng.randi_range(0, options.size() - 1))
		if allowed(data, m, n, NT.ELITE):
			n.type = NT.ELITE


static func count_type(m: RunMap, t: int) -> int:
	var k: int = 0
	for n: MapNode in m.nodes.values():
		if n.type == t:
			k += 1
	return k


## Floor-wide rule check; [] means the map is valid.
static func violations(data: MapGenData, m: RunMap) -> Array[String]:
	var out: Array[String] = []
	if not shopless_path(data, m).is_empty():
		out.append("a path has no Shop in the guarantee rows")
	if count_type(m, NT.ELITE) < data.min_elites:
		out.append("fewer than %d Elites" % data.min_elites)
	if data.pre_boss_mix:
		var types: Array = m.row_nodes(data.rows - 1).map(func(n: MapNode) -> int: return n.type)
		if not (types.has(NT.SHOP) and types.has(NT.REST)):
			out.append("the pre-boss row lacks a Shop or a Rest")
	for n: MapNode in m.nodes.values():
		if n.next.size() > data.max_links and n.id != m.boss_id and n.row < data.rows - 1:
			out.append("node %d links to more than %d" % [n.id, data.max_links])
		if data.no_repeat_types.has(n.type):
			for t in n.next:
				if m.node(t).type == n.type:
					out.append("%s -> %s at %d" % [NT.keys()[n.type], NT.keys()[n.type], n.id])
	return out
