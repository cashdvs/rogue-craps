## Caltrop d4 geometry (design/nonstandard_dice.md §10): a d4 lands POINT
## up, so its face value is read from the vertex that points up, not from
## a face. Each vertex carries one value (slot k = vertex k). Not wired into
## the sim yet: the d4 still plays on the d6 cube until it has its own mesh
## and collider; this is the reading rule they will use.
class_name D4Geometry
extends RefCounted

## Unit directions of a regular tetrahedron's 4 vertices in the die's local
## space: vertex 1 on +Y, the other three below it, 120 deg apart.
static var VERTICES: Array[Vector3] = [
	Vector3(0, 1, 0),
	Vector3(sqrt(8.0 / 9.0), -1.0 / 3.0, 0),
	Vector3(-sqrt(2.0 / 9.0), -1.0 / 3.0, sqrt(2.0 / 3.0)),
	Vector3(-sqrt(2.0 / 9.0), -1.0 / 3.0, -sqrt(2.0 / 3.0)),
]


## The slot (1..4) whose vertex points most nearly straight up for a die
## with basis b (resting on the felt, one vertex is straight up).
static func up_slot(b: Basis) -> int:
	var ob := b.orthonormalized()
	var best := 1
	var best_dot := -INF
	for k in VERTICES.size():
		var d := (ob * VERTICES[k]).dot(Vector3.UP)
		if d > best_dot:
			best_dot = d
			best = k + 1
	return best


## A basis that puts vertex `slot` straight up (for remapping a shown face,
## like DieVisual.remap_basis does for cubes).
static func basis_for_slot(slot: int) -> Basis:
	var v := VERTICES[clampi(slot, 1, 4) - 1]
	if v.is_equal_approx(Vector3.UP):
		return Basis.IDENTITY
	var axis := v.cross(Vector3.UP).normalized()
	return Basis(axis, v.angle_to(Vector3.UP))
