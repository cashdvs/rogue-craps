## A generated floor map plus where the player is on it. Pure logic (no
## nodes): the map view only draws this and forwards clicks to travel_to().
##
## Before the first move you stand below the map and can pick any node on
## row 0; after that only the current node's `next` nodes are reachable.
class_name RunMap
extends RefCounted

signal moved(node_id: int)

var rows: int = 0
var columns: int = 0
## id -> MapNode. Node ids are row * columns + col; the boss is rows * columns.
var nodes: Dictionary[int, MapNode] = {}
var boss_id: int = -1
var current_id: int = -1
var visited: Array[int] = []


func node(id: int) -> MapNode:
	return nodes.get(id, null)


func current() -> MapNode:
	return node(current_id)


func row_nodes(r: int) -> Array[MapNode]:
	var out: Array[MapNode] = []
	for id in nodes.keys():
		if nodes[id].row == r:
			out.append(nodes[id])
	out.sort_custom(func(a: MapNode, b: MapNode) -> bool: return a.col < b.col)
	return out


## Node ids you may travel to right now.
func reachable() -> Array[int]:
	if current_id < 0:
		var out: Array[int] = []
		for n in row_nodes(0):
			out.append(n.id)
		return out
	return current().next.duplicate()


func can_travel(id: int) -> bool:
	return reachable().has(id)


func travel_to(id: int) -> bool:
	if not can_travel(id):
		return false
	current_id = id
	visited.append(id)
	moved.emit(id)
	return true


func at_boss() -> bool:
	return current_id == boss_id


## Every node id in the graph that can be reached from row 0 (sanity check).
func connected_to_boss(id: int) -> bool:
	var stack: Array[int] = [id]
	var seen: Dictionary = {}
	while not stack.is_empty():
		var n: int = stack.pop_back()
		if n == boss_id:
			return true
		if seen.has(n):
			continue
		seen[n] = true
		stack.append_array(node(n).next)
	return false
