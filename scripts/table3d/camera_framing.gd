## Framing measurements for the game camera (viewport / stretched px), shared
## by the framing tests and tools/measure_camera_framing.gd.
##  - headroom: how far above the far rail top (y 0.11) the frame's top edge
##    reaches at the dealer's depth (Smiles stands at (-0.42, -0.47, -0.86)
##    behind the far rail; art/dealer-smiles README "Placement").
##  - die size: the projected size of a resting die at the felt rest spots.
##  - margins: how far a set of points sits inside the viewport edges.
class_name CameraFraming
extends RefCounted

## Rail top (Table3DBuilder: tube center 0.02 + radius 0.09).
const RAIL_TOP_Y: float = 0.11
## Smiles' spot behind the far rail (x, z).
const DEALER_XZ := Vector2(-0.42, -0.86)
## The far rail's centre line (z) and the plaques (board kit anchors).
const FAR_RAIL_Z: float = -0.61
const TARGET_PLATE := Vector3(0.0, 0.11, -0.61)
const TOTAL_PLATE := Vector3(0.0, 0.11, 0.61)
## Hearth brazier + goal plaque: all geometry under 0.25 m above the rail
## top (art/board-hearth README), so its top is ~0.36 m.
const BRAZIER_TOP := Vector3(0.0, 0.36, -0.61)


## World y where the frame's top edge crosses the vertical line at (x, z),
## found by bisection on the projected screen y (0 = top edge).
static func top_y_at(cam: Camera3D, x: float, z: float) -> float:
	var lo := -1.0
	var hi := 6.0
	for i in 50:
		var mid := (lo + hi) * 0.5
		var p := Vector3(x, mid, z)
		if cam.is_position_behind(p) or cam.unproject_position(p).y < 0.0:
			hi = mid
		else:
			lo = mid
	return lo


## Headroom (m) above the far rail top at the dealer's depth.
static func headroom(cam: Camera3D) -> float:
	return top_y_at(cam, DEALER_XZ.x, DEALER_XZ.y) - RAIL_TOP_Y


## Headroom (m) above the far rail top, measured right over the far rail.
static func headroom_at_rail(cam: Camera3D) -> float:
	return top_y_at(cam, DEALER_XZ.x, FAR_RAIL_Z) - RAIL_TOP_Y


## The felt rest spots (a grid over the felt, plus the hand) at die height.
static func rest_spots(die: float) -> Array[Vector3]:
	var out: Array[Vector3] = [Vector3(0.86, die * 0.5, 0.36)]
	for x in [-0.8, -0.4, 0.0, 0.4, 0.8]:
		for z in [-0.4, -0.12, 0.12, 0.4]:
			out.append(Vector3(x, die * 0.5, z))
	return out


## Projected die size (px, smaller of width/height) at each spot.
static func die_sizes(cam: Camera3D, spots: Array[Vector3], die: float) -> Array[float]:
	var out: Array[float] = []
	for p in spots:
		var s := DieVisual.projected_size(cam, Transform3D(Basis.IDENTITY, p), die)
		out.append(minf(s.x, s.y))
	return out


## Mean and min of die_sizes over the rest spots, and the felt centre.
static func die_stats(cam: Camera3D, die: float) -> Dictionary:
	var v := die_sizes(cam, rest_spots(die), die)
	var sum := 0.0
	var mn := INF
	for x in v:
		sum += x
		mn = minf(mn, x)
	var c := DieVisual.projected_size(cam, Transform3D(Basis.IDENTITY, Vector3(0.0, die * 0.5, 0.0)), die)
	return {"mean": sum / v.size(), "min": mn, "center": minf(c.x, c.y)}


## Points that must stay in frame: the whole felt, the rails' outer
## silhouette (near rail incl. corners), the TotalPlate, the TargetPlate and
## the brazier top.
static func must_points() -> Array[Vector3]:
	var fh := Table3DBuilder.FELT_HALF
	var r := Table3DBuilder.RAIL_RADIUS
	var ry := Table3DBuilder.RAIL_Y
	var pts: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pts.append(Vector3(sx * fh.x, 0.0, sz * fh.y))  # felt corners
			# rail corner spheres: outer silhouette
			pts.append(Vector3(sx * (fh.x + r * 2.0), ry, sz * (fh.y + r)))
			pts.append(Vector3(sx * (fh.x + r), ry, sz * (fh.y + r * 2.0)))
			pts.append(Vector3(sx * (fh.x + r), ry + r, sz * (fh.y + r)))
	for x in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		pts.append(Vector3(x * fh.x, ry, fh.y + r * 2.0))  # near rail, outer side
		pts.append(Vector3(x * fh.x, ry - r * 0.5, fh.y + r * 2.0))
	pts.append(TOTAL_PLATE)
	pts.append(TOTAL_PLATE + Vector3(0, 0.06, 0.04))
	pts.append(TARGET_PLATE)
	pts.append(BRAZIER_TOP)
	return pts


## Smallest distance (px) of any point inside the viewport edge (negative =
## off screen).
static func margin(cam: Camera3D, pts: Array[Vector3]) -> float:
	var vs := cam.get_viewport().get_visible_rect().size
	var m := INF
	for p in pts:
		if cam.is_position_behind(p):
			return -INF
		var sp := cam.unproject_position(p)
		m = minf(m, minf(minf(sp.x, vs.x - sp.x), minf(sp.y, vs.y - sp.y)))
	return m
