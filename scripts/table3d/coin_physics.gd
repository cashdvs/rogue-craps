## Coin physics (Ferryman's Coin, design/nonstandard_dice.md §10): the
## numbers and the small bits of math a 2-faced die needs that a cube
## doesn't. DiceSim (the physics bodies), DieVisual (the visible coin) and
## Bonfire3D (the flip at launch) all use these, so the coin is described in
## ONE place.
##
## Local axes (3D Artist's ferryman_d2.glb, confirmed): the coin is a flat
## cylinder centred on the origin with its round faces on local +Y / -Y.
##   +Y = HEADS = face slot 1 (TableDie.faces[0])
##   -Y = TAILS = face slot 2 (TableDie.faces[1])
## The face VALUE comes from TableDie.faces (the run sends coin [1, 5]); the
## Ferryman's Heads / Tails rule keys off the SLOT, never the value.
class_name CoinPhysics
extends RefCounted

## Size from the 3D Artist's mesh: 0.100 m across, 0.024 m thick (bevel
## ignored for the collider).
const RADIUS: float = 0.05
const THICKNESS: float = 0.024
## Mass relative to a d6 (TuningData.die_mass 0.02 kg -> 0.01 kg). The coin
## is symmetric with its centre of mass at the origin (Godot's default).
const MASS_FACTOR: float = 0.5
## A coin resting with its face more than this far from flat is "cocked"
## (leaning on a die or a rail) and gets nudged; 90 deg = standing on its
## edge. EDGE_DEG is the "on its edge" band: within 15 deg of vertical.
const COCKED_DEG: float = 14.0
const EDGE_DEG: float = 15.0
## Felt rolling resistance (1/s) on a coin rolling on its rim (DiceSim).
const FELT_ROLL_DAMP: float = 8.0
## Face slots.
const HEADS: int = 1
const TAILS: int = 2
## DieVisual.FACE_AXES ids of the coin's two faces (+Y is cube face 1, -Y is
## cube face 6), so the cube face-remap math works on a coin unchanged.
const AXIS_ID_HEADS: int = 1
const AXIS_ID_TAILS: int = 6


## The physics collider: a thin CylinderShape3D on local Y.
static func make_shape() -> CylinderShape3D:
	var c := CylinderShape3D.new()
	c.radius = RADIUS
	c.height = THICKNESS
	return c


## Heads (1) or tails (2) for a coin with basis b: whichever face normal
## points up. Exactly on edge counts as heads (the sim never leaves it there).
static func face_slot(b: Basis) -> int:
	return HEADS if (b.orthonormalized() * Vector3.UP).dot(Vector3.UP) >= 0.0 else TAILS


## DieVisual.FACE_AXES id for a coin slot (1 -> 1 = +Y, 2 -> 6 = -Y).
static func axis_id(slot: int) -> int:
	return AXIS_ID_TAILS if slot == TAILS else AXIS_ID_HEADS


## The coin slot for a DieVisual.FACE_AXES id (6 -> tails, anything else heads).
static func slot_for_axis_id(axis: int) -> int:
	return TAILS if axis == AXIS_ID_TAILS else HEADS


## How far the coin's face is from lying flat, in degrees (0 = flat on
## either face, 90 = standing on its edge).
static func tilt_deg(b: Basis) -> float:
	var n := b.orthonormalized() * Vector3.UP
	return rad_to_deg(acos(clampf(absf(n.dot(Vector3.UP)), 0.0, 1.0)))


## Standing on its edge (within EDGE_DEG of vertical).
static func is_on_edge(b: Basis) -> bool:
	return tilt_deg(b) >= 90.0 - EDGE_DEG


## The nearest flat pose: heads or tails up, whichever is closer. A coin
## exactly on its edge (no closer face) picks a side with `rng` (the edge
## "reroll"), so it can never be laid down on its rim.
static func flat_basis(b: Basis, rng: RandomNumberGenerator = null) -> Basis:
	var ob := b.orthonormalized()
	var n := ob * Vector3.UP
	var d := n.dot(Vector3.UP)
	var target := Vector3.UP if d > 0.0 else Vector3.DOWN
	if absf(d) < 0.001 and rng != null:
		target = Vector3.UP if rng.randf() < 0.5 else Vector3.DOWN
	if n.is_equal_approx(-target):
		return (Basis(ob.x.normalized(), PI) * ob).orthonormalized()
	return (Basis(Quaternion(n.normalized(), target)) * ob).orthonormalized()


## The end-over-end flip axis for a coin whose face normal is `normal`,
## thrown along horizontal `dir`: the horizontal line across the throw (so
## it tumbles head over heels toward the target), pushed into the coin's own
## plane so it spins about a diameter, never about its face normal (that
## would only spin it like a top). `jitter_rad` tilts it a little at random.
static func flip_axis(normal: Vector3, dir: Vector3, rng: RandomNumberGenerator, jitter_rad: float) -> Vector3:
	var n := normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.001:
		flat = Vector3.FORWARD
	var across := Vector3.UP.cross(flat.normalized())
	if rng != null and jitter_rad > 0.0:
		across = across.rotated(Vector3.UP, rng.randf_range(-jitter_rad, jitter_rad))
	var axis := across - n * across.dot(n)
	if axis.length() < 0.001:
		# The coin is standing across the throw: any diameter will do.
		axis = n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT)
	return axis.normalized()


## A random flip phase: `start` turned by a random angle about `axis`. The
## coin starts at any point of its flip, so where it lands is not decided by
## how it sat in the hand.
static func random_phase(start: Transform3D, axis: Vector3, rng: RandomNumberGenerator) -> Transform3D:
	if axis.length() < 0.001:
		return start
	var r := Basis(axis.normalized(), rng.randf_range(0.0, TAU))
	return Transform3D((r * start.basis).orthonormalized(), start.origin)
