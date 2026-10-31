## HotHandPulseFx (AD spec): outline width 1.0-1.5x on a 0.9 s sine, colour
## #E8622A -> #FFA13A, emission <= 0.3, reduced motion static 1.25x, clean stop.
##   godot --headless --path . --script res://tests/test_hot_hand_pulse.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


class StubTable:
	extends Node3D
	signal hot_hand(count: int)
	signal banked(points: int)
	signal bust(soul_loss: int, die_ids: Array)
	signal table_started()
	signal table_cleared()
	var events: Object
	var dice: Array[DieVisual] = []
	var reduced: bool = false
	func is_reduced_motion() -> bool:
		return reduced


func _mat(d: DieVisual) -> ShaderMaterial:
	return d.hull_outline.material_override as ShaderMaterial


func _setup(reduced: bool) -> Array:
	var tb := StubTable.new()
	tb.events = tb
	tb.reduced = reduced
	root.add_child(tb)
	var lit := DieVisual.new()
	var plain := DieVisual.new()
	tb.add_child(lit)
	tb.add_child(plain)
	lit.set_glow_state(true, false, true)
	plain.set_glow_state(false, false, true)
	tb.dice = [lit, plain] as Array[DieVisual]
	var fx := HotHandPulseFx.new()
	tb.add_child(fx)
	return [tb, fx, lit, plain]


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.002 and absf(a.g - b.g) < 0.002 and absf(a.b - b.b) < 0.002


## What die_hull_outline.gdshader puts on screen: ALBEDO = color * (1 + emission).
func _screen(smp: Dictionary) -> Color:
	var c: Color = smp["color"]
	var e: float = smp["emission"]
	return Color(c.r * (1.0 + e), c.g * (1.0 + e), c.b * (1.0 + e))


func _mat_screen(d: DieVisual) -> Color:
	var m := _mat(d)
	return _screen({"color": m.get_shader_parameter("color"), "emission": float(m.get_shader_parameter("emission_energy"))})


func _run() -> void:
	# Pure curve.
	var lo := 1e9
	var hi := -1e9
	for i in 900:
		var s := HotHandPulseFx.sample(i * 0.001)
		lo = minf(lo, s["width_mult"]); hi = maxf(hi, s["width_mult"])
		check(float(s["emission"]) <= 0.3, "emission <= 0.3 at t=%.3f" % (i * 0.001))
	check(is_equal_approx(lo, 1.0) and absf(hi - 1.5) < 1e-4, "width range 1.0-1.5x: %f..%f" % [lo, hi])
	check(HotHandPulseFx.PERIOD == 0.9, "period 0.9 s")
	check(is_equal_approx(HotHandPulseFx.sample(0.0)["width_mult"], HotHandPulseFx.sample(0.9)["width_mult"]), "repeats every 0.9 s")
	check(absf(HotHandPulseFx.sample(0.45)["width_mult"] - 1.5) < 1e-6, "peak at 0.45 s")
	check(is_equal_approx(HotHandPulseFx.sample(0.45)["width"], 0.015), "peak width 0.015 m")
	check(_close(_screen(HotHandPulseFx.sample(0.0)), Color("#E8622A")), "on-screen low colour #E8622A")
	check(_close(_screen(HotHandPulseFx.sample(0.45)), Color("#FFA13A")), "on-screen peak colour #FFA13A")
	var e0: float = HotHandPulseFx.sample(0.0)["emission"]
	check(is_equal_approx(e0, HotHandPulseFx.sample(0.45)["emission"]), "no emission pulse")
	for t in [0.0, 0.2, 0.45, 0.7]:
		var r := HotHandPulseFx.sample(t, true)
		check(is_equal_approx(r["width_mult"], 1.25), "reduced: static 1.25x at %.2f" % t)
	# Live on dice.
	var a := _setup(false)
	var tb: StubTable = a[0]; var fx: HotHandPulseFx = a[1]; var lit: DieVisual = a[2]; var plain: DieVisual = a[3]
	var body_before: Color = lit.body_material.get_shader_parameter("albedo")
	tb.hot_hand.emit(1)
	check(fx.active, "hot_hand starts it")
	check(fx.is_igniting(), "ignite beat on start")
	check(is_equal_approx(float(_mat(lit).get_shader_parameter("width")), 0.015), "ignite: peak width at once")
	check(_close(_mat_screen(lit), Color("#FFA13A")), "ignite: on-screen peak colour")
	fx.step(0.1)
	check(fx.is_igniting() and is_equal_approx(float(_mat(lit).get_shader_parameter("width")), 0.015), "ignite holds the peak at 0.1 s")
	fx.step(0.05)
	check(not fx.is_igniting(), "ignite over after 0.15 s")
	check(is_equal_approx(HotHandPulseFx.IGNITE_TIME, 0.15) and is_equal_approx(DieGlow.HOT_IGNITE_TIME, 0.15), "ignite beat 0.15 s")
	fx.step(0.45)
	check(absf(float(_mat(lit).get_shader_parameter("width")) - 0.010) < 1e-6, "sine hands off from the peak: low 0.45 s later")
	check(_close(_mat_screen(lit), Color("#E8622A")), "lit die on-screen low colour")
	fx.step(0.45)
	check(is_equal_approx(float(_mat(lit).get_shader_parameter("width")), 0.015), "lit die outline at peak width")
	check(_close(_mat_screen(lit), Color("#FFA13A")), "lit die on-screen peak colour")
	check(float(_mat(lit).get_shader_parameter("emission_energy")) <= 0.3, "lit die emission <= 0.3")
	check(is_equal_approx(float(_mat(plain).get_shader_parameter("width")), 0.010), "plain die untouched")
	check(not plain.hull_outline.visible, "plain die outline stays hidden")
	check(lit.body_material.get_shader_parameter("albedo") == body_before, "die body never tinted")
	lit.set_dimmed(true)
	fx.step(0.1)
	check(_close(_mat(lit).get_shader_parameter("color"), DieVisual.DIM_OUTLINE_COLOR), "dimmed die keeps the dim outline")
	lit.set_glow_state(true, false, true)
	fx.step(0.1)
	tb.banked.emit(10)
	check(not fx.active, "bank stops it")
	check(is_equal_approx(float(_mat(lit).get_shader_parameter("width")), 0.010), "stop: width back to 0.010 m")
	check(_close(_mat(lit).get_shader_parameter("color"), Color("#E8622A")), "stop: colour back to ember")
	check(is_equal_approx(float(_mat(lit).get_shader_parameter("emission_energy")), 0.4), "stop: emission back to lit 0.4")
	for sig in ["bust", "table_started", "table_cleared"]:
		fx.start()
		match sig:
			"bust": tb.bust.emit(1, [])
			"table_started": tb.table_started.emit()
			"table_cleared": tb.table_cleared.emit()
		check(not fx.active, "%s stops it" % sig)
	tb.queue_free()
	# Reduced motion.
	var b := _setup(true)
	var fxr: HotHandPulseFx = b[1]; var litr: DieVisual = b[2]
	fxr.start()
	check(not fxr.is_igniting(), "reduced: no ignite jump")
	for i in 10:
		fxr.step(0.09)
		check(is_equal_approx(float(_mat(litr).get_shader_parameter("width")), 0.0125), "reduced: static 1.25x on die")
	check(litr.scale == Vector3.ONE, "reduced: no scale pulse")
	fxr.stop()
	check(is_equal_approx(float(_mat(litr).get_shader_parameter("width")), 0.010), "reduced: clean stop")
	(b[0] as Node).queue_free()
	# DieGlow.hot_hand_pulse: one-shot outline ignite, no body flare.
	var c := _setup(false)
	var litg: DieVisual = c[2]
	var fxroot := Node3D.new()
	(c[0] as Node).add_child(fxroot)
	var tw := DieGlow.hot_hand_pulse(litg, fxroot, false)
	check(float(litg.body_material.get_shader_parameter("emission_energy")) <= 0.3, "ignite: body emission <= 0.3")
	check(is_equal_approx(float(_mat(litg).get_shader_parameter("width")), 0.015), "ignite: outline at peak width")
	check(_close(_mat_screen(litg), Color("#FFA13A")), "ignite: on-screen peak colour")
	check(float(_mat(litg).get_shader_parameter("emission_energy")) <= 0.3, "ignite: outline emission <= 0.3")
	await tw.finished
	check(float(litg.body_material.get_shader_parameter("emission_energy")) <= 0.3, "after ignite: body emission still <= 0.3 (no 1.6 -> 1.0 flare)")
	var litr2: DieVisual = c[3]
	litr2.set_glow_state(true, false, true)
	DieGlow.hot_hand_pulse(litr2, fxroot, true)
	check(is_equal_approx(float(_mat(litr2).get_shader_parameter("width")), 0.010), "reduced ignite: no outline jump")
	(c[0] as Node).queue_free()
	await process_frame
	print("hot_hand_pulse: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
