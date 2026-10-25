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


func _fx(root: Node3D, mobile := false, reduced := false) -> Fx:
	var fx: Fx = Fx.new()
	fx.mobile = mobile
	fx.reduced_motion = reduced
	root.add_child(fx)
	fx.setup(root)
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
	_check(bool(fx.emitters[&"soot"].get("emitting")), "soot emitter is emitting after the slam")
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
