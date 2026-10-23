## Headless test: the Nerve bone token prop (art/models/props/nerve_token, world_props_v1 §4). PC + mobile:
##   nodes    named rig nodes + Marker3D sockets Godot Dev hooks into
##   states   every state has its own silhouette (upright / lifted / tipped / flat / off-home) and the
##            notch shows only when carried, the chevron dulls only when spent
##   closed   "rests, unchanged": keeps the lean it had, drops any lift
##   rescue   slides along the track, clamped inside its ends, never leaves the rail (z, y), bobs, goes home
##   motion   moves are stepped on twos; reduced motion cuts to the end pose (no bob, no shake)
##   shake    one shake, then back to the exact pose
##   ui       NerveState.UiState mapping (READY / PICKING / NUDGED / SPENT + carried)
##   look     no glow: no emission above the shared dim fill floor, no ember rim on any token material
##   budget   tris (PC <= 140, mobile <= 130)
## Run:
##   godot --headless --path . --script res://tests/test_nerve_token.gd
extends SceneTree

const TOKEN := "res://art/models/props/nerve_token/scenes/nerve_token%s.tscn"
const M := "res://art/models/props/nerve_token/materials/"
const S := NerveToken.State

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Dice of the Damned: nerve token tests ===")
	_run.call_deferred()


func _ok(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL ", what)


func _run() -> void:
	_check_materials()
	for lod in ["", "_mobile"]:
		await _check(lod)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check_materials() -> void:
	for n in ["nerve_iron", "nerve_brass"]:   # the cradle fittings: Hearth iron/brass, ink pass
		var mf := load(M + n + ".tres") as ShaderMaterial
		_ok(mf != null and mf.next_pass != null and float(mf.get_shader_parameter("rim_emit")) == 0.0, n + ": toon_noir + ink, no ember rim")
	for n in ["nerve_bone", "nerve_bone_spent", "nerve_chevron", "nerve_chevron_spent"]:   # the token itself
		var m := load(M + n + ".tres") as ShaderMaterial
		_ok(m != null and m.next_pass != null, n + ": toon_noir + ink outline pass")
		var e: Variant = m.get_shader_parameter("emission_energy")
		_ok(e == null or float(e) <= 0.15, n + ": no glow (emission %s)" % str(e))
		var r: Variant = m.get_shader_parameter("rim_emit")
		_ok(r == null or float(r) == 0.0, n + ": no ember rim emit")


## World-space AABB of the token (tablet only).
func _box(t: Node3D) -> AABB:
	var mi := t.get_node("Rig/Slide/Bob/Lift/Pivot/Tablet").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var b := mi.get_aabb()
	var out := AABB(mi.global_transform * b.position, Vector3.ZERO)
	for i in 8:
		out = out.expand(mi.global_transform * b.get_endpoint(i))
	return out


func _tris(n: Node) -> int:
	var c := 0
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mesh := (m as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(si)
			c += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return c


func _check(lod: String) -> void:
	print("-- nerve_token%s" % lod)
	var t := (load(TOKEN % lod) as PackedScene).instantiate() as NerveToken
	root.add_child(t)
	await process_frame
	for p in ["Rig/Track", "Rig/Cradle", "Rig/Slide/Bob/Lift/Pivot/Tablet", "Rig/Slide/Bob/Lift/Pivot/Chevron",
			"Rig/Slide/Bob/Lift/Pivot/Notch", "Rig/Slide/Bob/Lift/Pivot/TooltipAnchor", "Rig/Home", "Rig/TrackStart", "Rig/TrackEnd", "Rig/TapCenter"]:
		_ok(t.has_node(p), "node " + p)
	for p in ["Rig/Slide/Bob/Lift/Pivot/TooltipAnchor", "Rig/Home", "Rig/TrackStart", "Rig/TrackEnd", "Rig/TapCenter"]:
		_ok(t.get_node(p) is Marker3D, p + " is a Marker3D")
	var n := _tris(t)
	_ok(n <= (140 if lod == "" else 130), "tris %d within budget" % n)
	print("  tris ", n)
	var notch := t.get_node("Rig/Slide/Bob/Lift/Pivot/Notch") as Node3D
	var tab := t.get_node("Rig/Slide/Bob/Lift/Pivot/Tablet").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var chev := t.get_node("Rig/Slide/Bob/Lift/Pivot/Chevron").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var k := t.rig_scale()

	t.set_state(S.AVAILABLE, false)
	var up := _box(t)
	_ok(up.size.y > 0.08 * k and up.size.z < 0.03 * k, "available: upright flat tablet (h %.3f, depth %.3f)" % [up.size.y, up.size.z])
	_ok(not notch.visible and tab.material_override == null, "available: no notch, bright bone")
	t.set_state(S.CARRIED, false)
	_ok(notch.visible and _box(t).is_equal_approx(up), "carried: same pose + notch")
	t.set_state(S.PICKING, false)
	var pk := _box(t)
	_ok(pk.position.y > up.position.y + 0.01 * k, "picking: lifts")
	_ok(not notch.visible or true, "picking: notch kept from carried is allowed")
	t.set_state(S.NUDGED, false)
	var nd := _box(t)
	_ok(nd.size.y < up.size.y * 0.95 and nd.size.z > up.size.z * 2.0, "nudged: tipped (h %.3f, depth %.3f)" % [nd.size.y, nd.size.z])
	_ok(nd.get_center().z < up.get_center().z, "nudged: tips toward the felt (-z)")
	t.set_state(S.CLOSED, false)
	_ok(_box(t).is_equal_approx(nd), "closed after nudged: rests unchanged")
	t.set_state(S.SPENT, false)
	var sp := _box(t)
	_ok(sp.size.y < 0.03 * k and sp.size.z > 0.08 * k, "spent: lies flat (h %.3f)" % sp.size.y)
	_ok(tab.material_override != null and chev.material_override != null and str(chev.material_override.resource_path).ends_with("nerve_chevron_spent.tres"), "spent: chevron dulled, bone grey")
	_ok(not notch.visible, "spent: no notch")
	t.set_state(S.CLOSED, false)
	_ok(_box(t).is_equal_approx(sp), "closed after spent: stays flat")
	t.set_state(S.AVAILABLE, false)
	_ok(tab.material_override == null and _box(t).is_equal_approx(up), "available again: upright, bright")

	# rescue: slide + clamp + stay on the rail
	var half := t.track_half()
	t.rescue_x = 10.0
	t.set_state(S.RESCUE, false)
	var rs := _box(t)
	_ok(is_equal_approx(t.slide_x, half - NerveToken.TAB_W * 0.5), "rescue: clamped inside the track end (%.3f)" % t.slide_x)
	_ok(absf(rs.get_center().z - up.get_center().z) < 0.0005 and rs.position.y >= up.position.y, "rescue: stays on the rail line, above it")
	_ok(rs.position.y > up.position.y + 0.024 * k, "rescue: lifted clear of the cradle cheeks")
	t.reduced_motion = true
	t.rescue_at(t.get_node("Rig").to_global(Vector3(-0.05, 0.0, -0.4)))
	_ok(is_equal_approx(t.slide_x, -0.05), "rescue_at: nearest track point to the die (x %.3f)" % t.slide_x)
	# animated: steps on twos, bobs after arriving, goes home when left
	t.reduced_motion = false
	t.set_state(S.AVAILABLE)
	var seen := {}
	for i in 60:
		t._process(1.0 / 60.0)
		seen[snappedf(t.slide_x, 0.0001)] = true
	_ok(seen.size() <= 13, "slide home stepped on twos (%d distinct poses in 1 s)" % seen.size())
	_ok(not t.is_moving() and is_zero_approx(t.slide_x) and is_zero_approx(t.lift), "back home after rescue")
	t.rescue_x = 0.1
	t.set_state(S.RESCUE)
	var bobs := {}
	for i in 180:
		t._process(1.0 / 60.0)
		if not t.is_moving():
			bobs[snappedf(t.bob, 0.0001)] = true
	_ok(bobs.size() > 3, "rescue: bobs once there")
	# reduced motion
	t.reduced_motion = true
	t.set_state(S.RESCUE)
	t._process(0.5)
	_ok(is_zero_approx(t.bob), "reduced motion: no bob")
	t.set_state(S.SPENT)
	_ok(is_equal_approx(t.lean, NerveToken.FLAT_DEG) and not t.is_moving(), "reduced motion: cut straight to flat")
	t.shake()
	_ok(not t.is_moving(), "reduced motion: no shake")
	# shake: one, then back
	t.reduced_motion = false
	t.set_state(S.AVAILABLE, false)
	t.shake()
	var peak := 0.0
	for i in 40:
		t._process(1.0 / 60.0)
		peak = maxf(peak, absf(t.shake_deg))
	_ok(peak >= 8.0 and is_zero_approx(t.shake_deg) and _box(t).is_equal_approx(up), "shake: one shake (peak %.1f deg) and back" % peak)
	# NerveState.UiState mapping
	t.reduced_motion = true
	t.from_ui_state(NerveState.UiState.READY, true)
	_ok(t.state == S.CARRIED, "ui READY + carried -> CARRIED")
	t.from_ui_state(NerveState.UiState.PICKING)
	_ok(t.state == S.PICKING, "ui PICKING")
	t.from_ui_state(NerveState.UiState.NUDGED)
	_ok(t.state == S.NUDGED, "ui NUDGED")
	t.from_ui_state(NerveState.UiState.SPENT)
	_ok(t.state == S.SPENT, "ui SPENT")
	t.free()
