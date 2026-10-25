## Headless test: Ashmouth taunt puffs (scripts/fx/ashmouth_puff_fx.gd).
## Builds a stand-in rig with the 3D Artist's socket paths and a "taunt"
## clip, then drives the AnimationPlayer and checks the beats, looks and
## the mobile / reduced-motion paths.
##
## Run:
##   godot --headless --path . --script res://tests/test_fx_ashmouth_puffs.gd
extends SceneTree

const Fx := preload("res://scripts/fx/ashmouth_puff_fx.gd")

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	print("=== Dice of the Damned: Ashmouth puffs ===")
	_test_beats()
	_test_other_clips()
	_test_speed_and_replay()
	_test_looks()
	_test_mobile_and_reduced()
	_test_missing_sockets()
	_test_cloud_size()
	_test_soot_colour_dir()
	await _test_outlives_dealer()
	await _test_fallback_root()
	_test_ash_over_rail()
	_test_soot_cap()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _rig(with_sockets: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "Ashmouth"
	var model := Node3D.new()
	model.name = "Model"
	root.add_child(model)
	var smiles := Node3D.new()
	smiles.name = "Smiles"
	model.add_child(smiles)
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	smiles.add_child(skel)
	if with_sockets:
		for pair: Array in [["FireboxDoorAttach", "FireboxDoor"], ["PipeMouthAttach", "PipeMouth"]]:
			var att := Node3D.new()
			att.name = pair[0]
			skel.add_child(att)
			var m := Marker3D.new()
			m.name = pair[1]
			att.add_child(m)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	for clip: String in ["taunt", "idle"]:
		var a := Animation.new()
		a.length = 1.6
		lib.add_animation(clip, a)
	ap.add_animation_library("", lib)
	model.add_child(ap)
	return root


const BOARD_SRC := "extends Node3D\nvar fx_root: Node3D\n"
var _board: Node3D


## A stand-in board (Table3D-style `fx_root`) in the tree; the dealer goes under it.
func _board_node() -> Node3D:
	if _board == null or not is_instance_valid(_board):
		var gs := GDScript.new()
		gs.source_code = BOARD_SRC
		gs.reload()
		_board = Node3D.new()
		_board.set_script(gs)
		_board.name = "Board"
		var fxr := Node3D.new()
		fxr.name = "Fx"
		_board.add_child(fxr)
		_board.set("fx_root", fxr)
		root.add_child(_board)
	return _board


func _fx(rig: Node3D, mobile := false, reduced := false, in_tree := true) -> Fx:
	var fx: Fx = Fx.new()
	fx.detect_renderer = false
	fx.mobile = mobile
	fx.reduced_motion = reduced
	rig.add_child(fx)
	if in_tree:
		_board_node().add_child(rig)
	fx.setup(rig)
	fx.set_process(false)
	return fx


func _drive(fx: Fx, clip: String, to: float, step := 1.0 / 60.0) -> Array:
	var log: Array = []
	var cb := func(k: StringName) -> void: log.append([k, fx.player.current_animation_position])
	fx.puffed.connect(cb)
	fx.player.play(clip)
	fx.player.advance(0.0)
	var t := 0.0
	while t < to:
		fx.player.advance(step)
		t += step
		fx.tick()
	fx.puffed.disconnect(cb)
	return log


func _test_beats() -> void:
	var root := _rig()
	var fx := _fx(root)
	_check(fx.player != null, "finds the AnimationPlayer under Model")
	_check(fx.emitters.has(&"ash") and fx.emitters.has(&"soot"), "an emitter on each socket")
	_check(fx.emitters[&"ash"].get_parent().name == "FireboxDoor", "ash emitter on FireboxDoor socket")
	_check(fx.emitters[&"soot"].get_parent().name == "PipeMouth", "soot emitter on PipeMouth socket")
	var log := _drive(fx, "taunt", 1.5)
	_check(log.size() == 2, "taunt fires exactly two puffs (got %d)" % log.size())
	if log.size() == 2:
		_check(log[0][0] == &"ash" and log[1][0] == &"soot", "ash first (door), then soot (slam)")
		_check(absf(log[0][1] - 0.19) < 0.02, "ash at 0.19 s (got %.3f)" % log[0][1])
		_check(absf(log[1][1] - 1.2) < 0.02, "soot at 1.2 s (got %.3f)" % log[1][1])
	_check(not bool(fx.emitters[&"soot"].get("emitting")), "socket template stays idle (bursts are copies)")
	_check(_board.get("fx_root").get_child_count() == 2, "two bursts under the board FX root (got %d)" % _board.get("fx_root").get_child_count())
	var early := _drive(fx, "taunt", 0.15)
	_check(early.is_empty(), "no puff before the door opens")
	root.free()


func _test_other_clips() -> void:
	var root := _rig()
	var fx := _fx(root)
	_check(_drive(fx, "idle", 1.5).is_empty(), "idle clip never puffs")
	root.free()


func _test_speed_and_replay() -> void:
	var root := _rig()
	var fx := _fx(root)
	var coarse := _drive(fx, "taunt", 1.5, 0.25)
	_check(coarse.size() == 2, "coarse frames still hit both beats (got %d)" % coarse.size())
	fx.player.stop()
	fx.tick()
	var again := _drive(fx, "taunt", 1.5)
	_check(again.size() == 2, "replayed taunt puffs again (got %d)" % again.size())
	# Restart mid-clip: seek back before the door.
	fx.player.seek(0.05, true)
	fx.player.advance(0.2)
	var n := [0]
	fx.puffed.connect(func(_k: StringName) -> void: n[0] += 1)
	fx.tick()
	_check(n[0] == 1, "seeking back re-arms the door puff")
	root.free()


func _test_looks() -> void:
	var root := _rig()
	var fx := _fx(root)
	for kind: StringName in Fx.PUFFS:
		var spec: Dictionary = Fx.PUFFS[kind]
		var c: Color = spec["color"]
		_check(c.s < 0.12, "%s is grey/soot (sat %.2f)" % [kind, c.s])
		_check(not (c.r > c.g + 0.08 and c.r > c.b + 0.08), "%s not red/fire" % kind)
		_check(not (c.b > c.r + 0.05), "%s not cyan/violet" % kind)
		var e: Node = fx.emitters[kind]
		_check(float(e.get("lifetime")) < 0.6, "%s burst under 0.6 s" % kind)
		_check(bool(e.get("one_shot")), "%s is one-shot" % kind)
		_check(not bool(e.get("emitting")), "%s idle until its beat" % kind)
		var mat := (e as GPUParticles3D).process_material as ParticleProcessMaterial
		var curve := (mat.scale_curve as CurveTexture).curve
		_check(absf(curve.sample(1.0) / curve.sample(0.0) - 1.5) < 0.05, "%s dots grow 1.5x over life" % kind)
		_check(mat.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "%s overlapping dots from a small sphere" % kind)
		var dot := (e as GPUParticles3D).draw_pass_1 as QuadMesh
		var tex := (dot.material as StandardMaterial3D).albedo_texture as GradientTexture2D
		_check(tex != null and tex.gradient.sample(0.7).a < 0.7 and tex.gradient.sample(0.7).a > 0.05, "%s soft dot edge" % kind)
		_check(e is GPUParticles3D, "%s uses GPU particles on Forward+" % kind)
		_check(int(e.get("amount")) <= 16, "%s low count (%d)" % [kind, int(e.get("amount"))])
	_check(Fx.PUFFS[&"ash"]["color"].v > Fx.PUFFS[&"soot"]["color"].v + 0.2, "ash lighter than soot")
	root.free()


func _test_mobile_and_reduced() -> void:
	var root := _rig()
	var fx := _fx(root, true)
	for kind: StringName in Fx.PUFFS:
		var e: Node = fx.emitters[kind]
		_check(e is CPUParticles3D, "%s CPUParticles3D on Compatibility" % kind)
		_check(float(e.get("lifetime")) < 0.6, "%s mobile burst under 0.6 s" % kind)
		_check(int(e.get("amount")) <= 8, "%s mobile count <= 8" % kind)
		_check(fx.particle_count(kind) < int(Fx.PUFFS[kind]["count"]), "%s mobile fewer than PC" % kind)
	root.free()
	var root2 := _rig()
	var fx2 := _fx(root2, false, true)
	for kind: StringName in Fx.PUFFS:
		var full := int(Fx.PUFFS[kind]["count"])
		_check(fx2.particle_count(kind) <= ceili(full * 0.3), "%s reduced motion ~1/3 (%d)" % [kind, fx2.particle_count(kind)])
	var log := _drive(fx2, "taunt", 1.5)
	_check(log.size() == 2, "reduced motion still marks both beats")
	_check(int(fx2.emitters[&"ash"].get("amount")) == fx2.particle_count(&"ash"), "puff applies reduced count")
	root2.free()


func _test_missing_sockets() -> void:
	var root := _rig(false)
	var fx := _fx(root)
	_check(fx.emitters.is_empty(), "no sockets -> no emitters")
	_check(_drive(fx, "taunt", 1.5).is_empty(), "no sockets -> taunt is silent, no crash")
	fx.setup(null)
	_check(true, "setup(null) is safe")
	root.free()


func _test_cloud_size() -> void:
	for kind: StringName in Fx.PUFFS:
		var d := Fx.cloud_diameter(kind)
		_check(d >= 0.10 and d <= 0.12, "%s cloud 10-12 cm (got %.3f)" % [kind, d])
		var spec: Dictionary = Fx.PUFFS[kind]
		_check(float(spec["dot"]) * float(spec["grow"]) >= 0.06, "%s dots large (end %.3f m)" % [kind, float(spec["dot"]) * float(spec["grow"])])
	_check(absf(float(Fx.PUFFS[&"ash"]["life"]) - 0.45) < 0.001 and absf(float(Fx.PUFFS[&"soot"]["life"]) - 0.55) < 0.001, "lifetimes kept 0.45/0.55")
	_check(int(Fx.PUFFS[&"ash"]["count"]) == 14 and int(Fx.PUFFS[&"soot"]["count"]) == 10, "counts kept 14/10")


func _test_soot_colour_dir() -> void:
	var c: Color = Fx.PUFFS[&"soot"]["color"]
	var want := Color("#6E6A64")
	_check(absf(c.r - want.r) < 0.03 and absf(c.g - want.g) < 0.03 and absf(c.b - want.b) < 0.03, "soot ~#6E6A64 (got #%s)" % c.to_html(false))
	_check(c.v >= 0.40, "soot light enough to separate from the dark pipe (v %.2f)" % c.v)
	var d: Vector3 = Fx.PUFFS[&"soot"]["dir"]
	_check(d.y > 0.8 * d.length(), "soot goes mostly up")
	_check(d.z < -0.1 and d.z > -0.6, "soot leans slightly back (z %.2f)" % d.z)


func _test_outlives_dealer() -> void:
	var rig := _rig()
	var fx := _fx(rig)
	rig.global_position = Vector3(0.3, 0.1, -0.5)
	var bursts: Array = []
	fx.burst_spawned.connect(func(_k: StringName, b: Node3D) -> void: bursts.append(b))
	var at := (rig.get_node(Fx.PIPE_SOCKET) as Node3D).global_position
	fx.puff(&"soot")
	_check(bursts.size() == 1, "puff spawns one burst")
	if bursts.is_empty():
		rig.free()
		return
	var b: Node3D = bursts[0]
	_check(b.get_parent() == _board.get("fx_root"), "burst moved to the board FX root")
	_check(b.global_position.distance_to(at) < 0.001, "burst keeps the socket's global position")
	_check(not rig.is_ancestor_of(b), "burst is not inside the dealer scene")
	rig.queue_free()  # dealer freed mid-puff
	await process_frame
	await process_frame
	_check(not is_instance_valid(rig), "dealer scene is gone")
	_check(is_instance_valid(b) and b.is_inside_tree(), "burst survives the dealer being freed")
	_check(is_instance_valid(b) and bool(b.get("emitting")), "burst still emitting after the dealer is freed")
	await create_timer(float(Fx.PUFFS[&"soot"]["life"]) + Fx.FREE_PAD + 0.15).timeout
	_check(not is_instance_valid(b), "burst frees itself after its lifetime")


func _test_fallback_root() -> void:
	var rig := _rig()
	var fx := _fx(rig, false, false, false)
	root.add_child(rig)  # no board ancestor
	var got: Array = []
	fx.burst_spawned.connect(func(_k: StringName, b: Node3D) -> void: got.append(b))
	fx.puff(&"ash")
	var want: Node = current_scene if current_scene != null else root
	_check(got.size() == 1 and got[0].get_parent() == want, "no board: burst goes to current_scene / root")
	rig.free()
	for b in got:
		if is_instance_valid(b):
			b.free()


func _rail(parent: Node, top: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Backboard"
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 0.066, 0.034)
	mi.mesh = bm
	parent.add_child(mi)
	mi.global_position = Vector3(0, top - 0.033, -0.5)
	return mi


func _ash_burst(fx: Fx) -> Node3D:
	var got: Array = []
	var cb := func(_k: StringName, b: Node3D) -> void: got.append(b)
	fx.burst_spawned.connect(cb)
	fx.puff(&"ash")
	fx.burst_spawned.disconnect(cb)
	return got[0] if not got.is_empty() else null


func _test_ash_over_rail() -> void:
	var rig := _rig()
	var fx := _fx(rig)
	rig.global_position = Vector3(-0.42, -0.47, -0.86)
	var door := (rig.get_node(Fx.DOOR_SOCKET) as Node3D).global_position
	# No rail: exported lift.
	var b0 := _ash_burst(fx)
	_check(b0 != null and absf(b0.global_position.y - (door.y + fx.ash_lift)) < 0.001, "no rail: ash at socket + ash_lift")
	_check(absf(fx.ash_lift - 0.47) < 0.001, "documented default ash_lift 0.47 m")
	# Rail on the board (sibling of the dealer): spawn just over the lip at the door XZ.
	var rail := _rail(_board, 0.066)
	var wall := _rail(_board, 2.3)  # tall wall behind the dealer: not the lip
	wall.name = "WallBack"
	wall.global_position.z = -1.6
	var deco := Node3D.new()
	_board.add_child(deco)
	var hidden := _rail(deco, 1.0)  # hidden rail: ignored
	hidden.visible = false
	var b := _ash_burst(fx)
	_check(absf(fx.rail_top_y() - 0.066) < 0.001, "rail lip found from board geometry (%.3f)" % fx.rail_top_y())
	_check(b != null and absf(b.global_position.y - (0.066 + Fx.ASH_RAIL_CLEAR)) < 0.001, "ash spawns just over the rail lip")
	_check(b != null and b.global_position.y >= 0.066 + 0.01, "ash spawn clears the rail lip by >= 1 cm")
	_check(b != null and absf(b.global_position.x - door.x) < 0.001 and absf(b.global_position.z - door.z) < 0.001, "ash keeps the door XZ")
	var d: Vector3 = Fx.PUFFS[&"ash"]["dir"]
	_check(d.y > 0.7 * d.length() and d.z > 0.0, "ash billows up and out (front)")
	_check(float(Fx.PUFFS[&"ash"]["gravity"]) >= 0.0, "ash does not sink back behind the rail")
	# A low rail never pulls the ash below the door.
	rail.global_position.y = door.y - 0.5
	_check(absf(fx.ash_spawn_y(door) - door.y) < 0.001, "low rail: ash never below the socket")
	rail.free()
	wall.free()
	deco.free()
	rig.free()


func _test_soot_cap() -> void:
	var rig := _rig()
	var fx := _fx(rig)
	rig.global_position = Vector3.ZERO
	var pipe := rig.get_node(Fx.PIPE_SOCKET) as Node3D
	pipe.position = Vector3(0, 0.2, 0)
	var cam := Camera3D.new()
	_board.add_child(cam)
	cam.global_position = Vector3(0, 1.6, 1.5)
	cam.look_at(Vector3(0, -0.35, 0.3))
	cam.current = true
	var vp := cam.get_viewport()
	var min_px := fx.soot_top_margin * vp.get_visible_rect().size.y
	_check(absf(fx.soot_top_margin * 780.0 - 8.0) >= 0.0 and fx.soot_top_margin * 780.0 >= 8.0, "margin >= 8 px of a 780 px phone frame")
	# Frame top just above the pipe: cap must kick in.
	cam.fov = 20.0
	var top := fx.frame_top_y(pipe.global_position)
	var got: Array = []
	fx.burst_spawned.connect(func(_k: StringName, b: Node3D) -> void: got.append(b))
	fx.puff(&"soot")
	_check(top < pipe.global_position.y + Fx.cloud_rise(&"soot"), "setup: uncapped soot would leave the frame (top %.3f)" % top)
	if not got.is_empty():
		var b: Node3D = got[0]
		var k: float = b.get_meta("soot_k", 1.0)
		var cloud_top := b.global_position.y + Fx.cloud_rise(&"soot", k)
		var px := cam.unproject_position(Vector3(b.global_position.x, cloud_top, b.global_position.z)).y
		_check(k < 1.0, "soot rise scaled down (k %.2f)" % k)
		_check(px >= min_px - 0.5, "capped soot cloud top inside the margin (%.1f px >= %.1f)" % [px, min_px])
		var v := ((b as GPUParticles3D).process_material as ParticleProcessMaterial).initial_velocity_max
		_check(absf(v - float(Fx.PUFFS[&"soot"]["speed"]) * k) < 0.001, "capped speed applied to the burst")
		var tmpl := (fx.emitters[&"soot"] as GPUParticles3D).process_material as ParticleProcessMaterial
		_check(absf(tmpl.initial_velocity_max - float(Fx.PUFFS[&"soot"]["speed"])) < 0.001, "template speed untouched")
	# Wide frame: no cap.
	cam.fov = 75.0
	got.clear()
	fx.puff(&"soot")
	_check(not got.is_empty() and float(got[0].get_meta("soot_k", 1.0)) == 1.0, "plenty of room: soot uncapped")
	cam.free()
	rig.free()
