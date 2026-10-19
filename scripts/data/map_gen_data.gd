## Rules for generating one floor's branching map (Slay the Spire style):
## rows of nodes joined by paths, each node a type picked by weight under a
## few constraints. Data only: edit resources/map/floor_1_map.tres to tune.
## MapGenerator reads this; nothing here is random by itself.
class_name MapGenData
extends Resource

## Node types on the map. The boss is always alone on the last row.
enum NodeType { TABLE, ELITE, EVENT, SHOP, REST, BOSS }

@export_group("Shape")
## Rows of choosable nodes below the boss row (map spec 1: 7, boss is row 8).
@export var rows: int = 7
## Lanes (grid columns) per floor, rolled between these (spec 1: 3-4).
@export var min_lanes: int = 3
@export var max_lanes: int = 4
## Most nodes one node links to on the next row (spec 1: 1-2).
@export var max_links: int = 2
## Paths walked from the bottom row to the top; more paths = more branching.
@export var paths: int = 4
## How far a path may step sideways per row (1 = to a neighbouring column).
@export var max_step: int = 1

@export_group("Types")
## Pick weight per NodeType for the mixed rows, index = NodeType (TABLE,
## ELITE, EVENT, SHOP, REST, BOSS). Spec 1: Table 45, Elite 12, Event 22,
## Shop 12, Rest 9. BOSS stays 0: the boss is placed by rule.
@export var type_weights: PackedFloat32Array = PackedFloat32Array([45, 12, 22, 12, 9, 0])
## Every node on the first row is this type (a plain table to start).
@export var first_row_type: NodeType = NodeType.TABLE
## The row right before the boss is all Rest stops.
@export var rest_before_boss: bool = true
## Earliest row (0-based) an Elite Table may appear on (spec: no Elite before row 3).
@export var elite_min_row: int = 2
## Earliest row a Shop may appear on (0-based).
@export var shop_min_row: int = 1
## Earliest row a Rest may appear on besides the pre-boss row (0-based).
@export var rest_min_row: int = 1
## Every path from the start to the boss passes a Shop on rows
## shop_guarantee_from..shop_guarantee_to (0-based; spec: rows 3-6). -1 = off.
@export var shop_guarantee_from: int = 2
@export var shop_guarantee_to: int = 5
## At least this many Elites on the floor (spec: 2).
@export var min_elites: int = 2
## Whole-map rerolls if the repairs above can't satisfy every rule.
@export var max_attempts: int = 50
## Types that may never follow themselves along a path (e.g. no Shop -> Shop).
@export var no_repeat_types: PackedInt32Array = PackedInt32Array([NodeType.ELITE, NodeType.SHOP, NodeType.REST])
## Tries to find a type that obeys the rules before falling back to fallback_type.
@export var max_type_tries: int = 20
@export var fallback_type: NodeType = NodeType.TABLE


func weight_of(t: NodeType) -> float:
	return type_weights[t] if t < type_weights.size() else 0.0


func is_valid() -> bool:
	return rows >= 2 and min_lanes >= 1 and max_lanes >= min_lanes and max_links >= 1 and paths >= 1 and max_step >= 0 and max_type_tries >= 1
