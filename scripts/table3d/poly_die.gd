## Non-d6 dice with their own mesh (PM ruling, Oct 19): a convex-hull
## collider built from the 3D Artist's mobile-LOD mesh (DieHullData, about
## 12-72 points, mirror-symmetric like the mesh), d6 mass, and the face read
## from the value -> local direction table: the slot whose direction points
## most nearly world-up (the top face; the Caltrop d4 reads its top VERTEX,
## since it rests on a face and lands point-up).
## Shape ids: &"d4" (Caltrop), &"d8" (Lantern), &"d10" (Tithe), &"d12"
## (Midnight), &"d20" (Verdict), &"talus" (Knucklebone's astragalus: 4
## resting faces 1/3/4/6 on local +Z/+Y/-Y/-Z, never on its knobbed ends),
## &"keg" (Powder Keg body: a 6-stave barrel with domed ends rolling on
## local X, staves printed 1-2-3-1-2-3; its DATA shape stays d6 with faces
## [1, 1, 2, 2, 3, 3], slot k = stave k of the table).
## The coin has its own procedural hull (CoinPhysics).
class_name PolyDie
extends RefCounted

## Visual / collider half-extent cap (PM ruling): no non-d6 die may reach
## further than this from its centre along any axis.
const MAX_HALF_EXTENT: float = 0.050
## Felt rolling resistance (1/s, DiceSim._poly_on_felt) on a hull die that is
## low on the felt and spinning slower than ROLL_DAMP_MAX_SPIN (rad/s).
const FELT_ROLL_DAMP: float = 6.0
const ROLL_DAMP_MAX_SPIN: float = 4.0
## A hull die whose spin grows by more than this factor from one physics
## step to the next is creeping (rolling over a stave or edge), so it is
## not at rest yet even when under the rest thresholds.
const CREEP_GROWTH: float = 1.03
## A hull die whose spin climbs back to this many times its slowest spin
## since it came to rest is rocking over a ridge, not at rest.
const CREEP_REBOUND: float = 1.5


static func has_shape(shape: StringName) -> bool:
	return DieHullData.SHAPES.has(shape)


## Is the shape's art mesh in this repo (PR #102)? Until it is, the table
## keeps playing these dice on the d6 cube, so the collider matches what
## the player sees.
static func has_mesh(shape: StringName) -> bool:
	return mesh_path(shape) != ""


## The shape's mobile mesh in res://art/models/dice/, under its old or new
## (DICE_IDS rename in #102) file name; "" if neither is here.
static func mesh_path(shape: StringName) -> String:
	if not has_shape(shape):
		return ""
	for f in DieHullData.SHAPES[shape]["sources"]:
		var p := "res://art/models/dice/" + String(f)
		if ResourceLoader.exists(p):
			return p
	return ""


## Which body shape a TableDie gets on the table: its own, or the cube.
## The Knucklebone (special) is the talus whatever its data shape says.
static func body_shape_for(td: TableDie) -> StringName:
	if td == null:
		return &"d6"
	if td.special == &"knucklebone":
		return &"talus"
	if td.id == &"powder_keg" or td.special == &"powder_keg" or td.run_die_id == &"powder_keg":
		# Data shape d6 ([1, 1, 2, 2, 3, 3]); the body is the barrel.
		return &"keg"
	return td.shape


## A rare die's own art body (DiceIds.body_key: a rare's model, or its stand-in
## until 3D Artist ships it), as res://art/models/dice/<key>.glb. Only d6
## bodies for now: they keep the cube collider and face read, so the shaped
## (d4 / d8 ...) meshes stay with the hull path above. "" = keep the cube.
static func art_body_path(die_id: StringName) -> String:
	if not DiceIds.is_die(die_id):
		return ""
	if not DiceIds.RARE_ART_BODIES.has(DiceIds.asset_key(die_id)):
		return ""  # Rares only; the other dice keep the procedural cube.
	var key := DiceIds.body_key(die_id)
	if not String(key).ends_with("_d6"):
		return ""
	var p := "res://art/models/dice/%s.glb" % key
	return p if ResourceLoader.exists(p) else ""


## The first mesh in the art body's .glb (null if none).
static func art_body_mesh(die_id: StringName) -> Mesh:
	var p := art_body_path(die_id)
	if p == "":
		return null
	var scene := load(p) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate()
	var found: Mesh = null
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		found = (n as MeshInstance3D).mesh
		break
	if found == null and inst is MeshInstance3D:
		found = (inst as MeshInstance3D).mesh
	inst.free()
	return found


static func hull(shape: StringName) -> PackedVector3Array:
	return DieHullData.SHAPES[shape]["hull"]


static func make_shape(shape: StringName) -> ConvexPolygonShape3D:
	var c := ConvexPolygonShape3D.new()
	c.points = hull(shape)
	return c


static func dirs(shape: StringName) -> Array:
	return DieHullData.SHAPES[shape]["dirs"]


## Printed value per slot (slot k = values[k - 1]).
static func values(shape: StringName) -> Array:
	return DieHullData.SHAPES[shape]["values"]


static func read_mode(shape: StringName) -> StringName:
	return DieHullData.SHAPES[shape]["read"]


## The slot (1-based) pointing up for basis b.
static func up_slot(shape: StringName, b: Basis) -> int:
	var ob := b.orthonormalized()
	var best := 1
	var best_y := -INF
	var d := dirs(shape)
	for k in d.size():
		var y := (ob * (d[k] as Vector3)).y
		if y > best_y:
			best_y = y
			best = k + 1
	return best


## Degrees between the up slot's direction and straight up (0 = resting
## cleanly on a face; large = on an edge or point).
static func tilt_deg(shape: StringName, b: Basis) -> float:
	var ob := b.orthonormalized()
	var v := ob * (dirs(shape)[up_slot(shape, ob) - 1] as Vector3)
	return rad_to_deg(acos(clampf(v.normalized().y, -1.0, 1.0)))


## The nearest basis with the up slot's direction exactly up.
static func flat_basis(shape: StringName, b: Basis) -> Basis:
	var ob := b.orthonormalized()
	var v := (ob * (dirs(shape)[up_slot(shape, ob) - 1] as Vector3)).normalized()
	if v.is_equal_approx(Vector3.UP):
		return ob
	return (Basis(Quaternion(v, Vector3.UP)) * ob).orthonormalized()


## Height of the centre above the felt in pose b (lowest hull point on it).
static func rest_height(shape: StringName, b: Basis) -> float:
	var ob := b.orthonormalized()
	var low := INF
	for p in hull(shape):
		low = minf(low, (ob * p).y)
	return -low


## Largest distance of a hull point from the centre (footprint radius).
static func radius(shape: StringName) -> float:
	var r := 0.0
	for p in hull(shape):
		r = maxf(r, p.length())
	return r


## Largest |x|, |y| or |z| of the hull (against MAX_HALF_EXTENT).
static func half_extent(shape: StringName) -> float:
	var h := 0.0
	for p in hull(shape):
		h = maxf(h, maxf(absf(p.x), maxf(absf(p.y), absf(p.z))))
	return h


## The mesh's own half-extent (from its AABB, recorded by the generator).
static func mesh_half_extent(shape: StringName) -> float:
	return float(DieHullData.SHAPES[shape]["mesh_half_extent"])


## Turns a die that physically landed with basis `b` so slot `want` is up
## instead (the seeded result, like DieVisual.remap_basis for cubes): a
## rotation in the die's own frame taking want's direction onto the landed
## one, turned about it to the best match of the whole direction set (a
## symmetry of the solid, so the die looks the same, just relabelled).
static func remap_basis(shape: StringName, b: Basis, want: int) -> Basis:
	var ob := b.orthonormalized()
	var d := dirs(shape)
	var landed := d[up_slot(shape, ob) - 1] as Vector3
	var wv := d[clampi(want, 1, d.size()) - 1] as Vector3
	var q0 := Basis(Quaternion(wv.normalized(), landed.normalized())) if not wv.is_equal_approx(landed) else Basis.IDENTITY
	var best := q0
	var best_err := INF
	for k in 360:
		var q := Basis(landed.normalized(), TAU * float(k) / 360.0) * q0
		var err := 0.0
		for a in d:
			var m := q * (a as Vector3)
			var near := INF
			for c in d:
				near = minf(near, m.distance_squared_to(c as Vector3))
			err += near
		if err < best_err:
			best_err = err
			best = q
	return (ob * best).orthonormalized()
