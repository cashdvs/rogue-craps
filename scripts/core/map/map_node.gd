## One node on a generated floor map: where it sits, what it is, and which
## nodes on the next row it leads to. Plain data, made by MapGenerator.
class_name MapNode
extends RefCounted

var id: int = 0
var row: int = 0
var col: int = 0
var type: MapGenData.NodeType = MapGenData.NodeType.TABLE
## ids of nodes on row + 1 this node connects to, sorted.
var next: Array[int] = []
## ids of nodes on row - 1 that lead here, sorted.
var prev: Array[int] = []


func _init(node_id: int, r: int, c: int) -> void:
	id = node_id
	row = r
	col = c
