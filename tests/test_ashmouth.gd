## Headless test: Ashmouth (art/models/characters/bosses/ashmouth), templated on tests/test_pit_boss.gd via
## tests/support/boss_dealer_test.gd: Smiles rig + clips, tri budgets, toon-noir + ink in the AD dealer palette
## (+ the two ambient conditions), HeadTrack + HeadAnchor, brazier gap + felt in both game cams, plus
## the firebox-door hinge bone, FX sockets, the unlit firebox and the AshmouthPuffFx hookup (PR #165).
##
## Run:
##   godot --headless --path . --script res://tests/test_ashmouth.gd
extends "res://tests/support/boss_dealer_test.gd"


func _setup() -> void:
	title = "Ashmouth"
	boss = "ashmouth"
	parts = ["Ashmouth_Body", "Ashmouth_Head", "Ashmouth_Pipe"]
	slots = ["ash_iron", "ash_iron_dark", "ash_skin", "ash_sleeve", "ash_brass", "ash_soot", "ash_coal", "ash_eye", "ash_tash"]
	no_ink = ["ash_eye"]
	accents = ["ash_brass", "ash_tash"]
	prop = ""
	prop_slots = []
	swap_bone = {"Ashmouth_Pipe": "visor"}
	extra_bones = {"firebox_door": "spine"}
	scripted_ok = ["AshmouthPuffFx"]

const PUFF_FX := "res://scripts/fx/ashmouth_puff_fx.gd"  # VFX Dev, PR #165
const FIREBOX: Array[String] = ["ash_iron_dark", "ash_soot", "ash_coal"]  # door, mouth, grate


func _extra(s: Node3D, skel: Skeleton3D, ap: AnimationPlayer, _meshes: Dictionary, label: String) -> void:
	# FX sockets the puff listener reads (FireboxDoor on the hinge bone, PipeMouth on the stovepipe/visor bone)
	for pair: Array in [["FireboxDoorAttach", "firebox_door", "FireboxDoor"], ["PipeMouthAttach", "visor", "PipeMouth"]]:
		var att := s.get_node_or_null("Model/Smiles/Skeleton3D/" + pair[0]) as BoneAttachment3D
		t.ok(att != null and att.bone_name == pair[1] and att.get_node_or_null(pair[2]) is Marker3D,
			"%s: socket %s/%s on the %s bone" % [label, pair[0], pair[2], pair[1]])
	# PR #165 hookup: a plain Node child of the root with the puff script, present exactly when the script is
	if ResourceLoader.exists(PUFF_FX):
		var fx := s.get_node_or_null("AshmouthPuffFx")
		t.ok(fx != null and fx.get_parent() == s and fx.get_script() and (fx.get_script() as Script).resource_path == PUFF_FX,
			label + ": AshmouthPuffFx node (scripts/fx/ashmouth_puff_fx.gd) is a direct child of the root")
	else:
		t.ok(s.get_node_or_null("AshmouthPuffFx") == null, label + ": no AshmouthPuffFx yet (script lands with PR #165)")
	# the firebox stays cold: no emission, no rim, no spec on door / mouth / coals
	for n in FIREBOX:
		var m := load(dir() + "materials/" + n + ".tres") as ShaderMaterial
		t.ok(float(BD.param(m, "emission_energy")) == 0.0 and float(BD.param(m, "spec_strength")) == 0.0
			and (n == "ash_iron_dark" or float(BD.param(m, "rim_strength")) == 0.0),
			"%s: firebox %s unlit (no emission / spec%s)" % [label, n, "" if n == "ash_iron_dark" else " / rim"])
	# taunt timing the puffs key off: door opens by 0.19 s, slams by 1.2 s, clip ends at 1.4 s (soot overruns it)
	var door := skel.find_bone("firebox_door")
	ap.play("taunt")
	ap.seek(0.6, true)
	var open := skel.get_bone_pose_rotation(door).get_angle()
	ap.seek(1.25, true)
	var shut := skel.get_bone_pose_rotation(door).get_angle()
	t.ok(open > 0.5 and shut < 0.05, "%s: taunt opens the firebox door (%.2f rad @0.6) and slams it by 1.25 s (%.2f)" % [label, open, shut])
	t.ok(absf(ap.get_animation("taunt").length - 1.4) < 0.01, "%s: taunt is 1.4 s (soot puff at 1.2 s runs past it)" % label)
