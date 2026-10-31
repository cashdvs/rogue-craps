## Headless test: the Wild face mark is a brass / cream frame with dark
## corner ticks (no rainbow). Through the real Bonfire3D scene, a d6 with
## Wild on one face. Checks, with the colours written here on purpose:
##   - 8 pieces: 4 frame strips and 4 corner ticks;
##   - the strips keep the old frame geometry (0.88 e square, 0.08 e thick)
##     and go top brass #C9A24A, right cream #EDE3CC, bottom brass, left
##     cream (so the two colours alternate round the frame);
##   - each corner has one dark #1E1712 tick, 0.08 e square, on top of
##     the strips.
##   godot --headless --path . --script res://tests/test_wild_frame.gd
extends SceneTree

const BRASS := Color("#C9A24A")
const CREAM := Color("#EDE3CC")
const TICK := Color("#1E1712")

var _passed: int = 0
var _failed: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var m := FaceModData.new()
	m.id = &"test_wild"
	m.effect = FaceModData.Effect.WILD
	var td := TableDie.new(DiceIds.DIE_BONE, "Bone", DiceIds.shape_of(DiceIds.DIE_BONE))
	td.mods = [m, null, null, null, null, null]
	var st := TableSetup.new()
	st.dice.append(td)
	st.run_mode = false
	st.table_seed = 3
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	root.add_child(s)
	await process_frame
	var d: DieVisual = s.all_dice[0]
	_check(d.faces.get_node("FaceMods").get_children(), d.edge)
	s.queue_free()
	await process_frame
	print("test_wild_frame: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(kids: Array, e: float) -> void:
	check(kids.size() == 8, "Wild: 4 strips + 4 ticks (%d)" % kids.size())
	if kids.size() != 8:
		return
	# Strips: by where they sit in the face's own (u, v) frame.
	var want := {"top": BRASS, "right": CREAM, "bottom": BRASS, "left": CREAM}
	var seen := {}
	var strip_lift := 0.0
	for i in 4:
		var mi := kids[i] as MeshInstance3D
		var b := mi.transform.basis
		var o := mi.transform.origin
		var off := Vector2(o.dot(b.x.normalized()), o.dot(b.y.normalized()))
		var sz: Vector2 = (mi.mesh as QuadMesh).size
		var side := ""
		if absf(off.y) > absf(off.x):
			side = "top" if off.y > 0.0 else "bottom"
			check(sz.is_equal_approx(Vector2(0.88, 0.08) * e), "Wild %s strip keeps its size" % side)
		else:
			side = "right" if off.x > 0.0 else "left"
			check(sz.is_equal_approx(Vector2(0.08, 0.88) * e), "Wild %s strip keeps its size" % side)
		check(absf(maxf(absf(off.x), absf(off.y)) - 0.40 * e) < 0.001, "Wild %s strip on the frame line" % side)
		check(_col(mi).is_equal_approx(want.get(side, TICK)), "Wild %s strip is %s" % [side, "brass" if want.get(side) == BRASS else "cream"])
		seen[side] = true
		strip_lift = o.dot(b.z.normalized())
	check(seen.size() == 4, "Wild: one strip per side (%d)" % seen.size())
	var corners := {}
	for i in range(4, 8):
		var mi := kids[i] as MeshInstance3D
		var b := mi.transform.basis
		var o := mi.transform.origin
		var off := Vector2(o.dot(b.x.normalized()), o.dot(b.y.normalized()))
		check(_col(mi).is_equal_approx(TICK), "Wild tick %d is dark #1E1712" % (i - 3))
		check((mi.mesh as QuadMesh).size.is_equal_approx(Vector2(0.08, 0.08) * e), "Wild tick %d is 0.08 e square" % (i - 3))
		check(absf(absf(off.x) - 0.40 * e) < 0.001 and absf(absf(off.y) - 0.40 * e) < 0.001, "Wild tick %d sits on a corner" % (i - 3))
		check(o.dot(b.z.normalized()) > strip_lift, "Wild tick %d on top of the strips" % (i - 3))
		corners[Vector2(signf(off.x), signf(off.y))] = true
	check(corners.size() == 4, "Wild: a tick on every corner (%d)" % corners.size())


func _col(mi: MeshInstance3D) -> Color:
	return (mi.material_override as StandardMaterial3D).albedo_color
