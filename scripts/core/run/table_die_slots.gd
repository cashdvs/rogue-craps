## TableDie helper for RunProgress: the 6-slot d6 fallback used until the
## table reads TableDie.shape.
class_name TableDieSlots
extends RefCounted


## Until TableDie has a `shape` (Godot Dev's shape commit) the table rolls
## and labels a 6-slot d6 mesh, so a die with fewer faces is sent as 6 slots
## with the same odds: each value (with its mod and weight) on 6/N physical
## slots, e.g. Ferryman's Coin -> faces 5,5,5,0,0,0 (Tails scores 0; the
## table's label clamps it to show 1). The Powder Keg is already 6 faces.
## Face counts that don't divide 6 (d4, d8+, Knucklebone; all disabled)
## are left N-sized.
static func to_d6_slots(td: TableDie) -> void:
	var n := td.faces.size()
	if n == 6 or n == 0 or 6 % n != 0:
		return
	var rep := 6 / n
	var faces: Array[int] = []
	var mods: Array = []
	var weights: Array[float] = []
	for i in 6:
		var k := i / rep
		faces.append(td.faces[k])
		mods.append(td.mods[k])
		if td.weights.size() == n:
			weights.append(td.weights[k])
	td.faces = faces
	td.mods.assign(mods)
	td.weights = weights
