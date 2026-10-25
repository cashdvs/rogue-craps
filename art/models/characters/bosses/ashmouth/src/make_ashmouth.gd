extends SceneTree
## Ashmouth toon-noir materials + wrapper scenes, templated on pit_boss/src/make_pit_boss.gd (order: rebuild_ashmouth.sh):
##   godot --headless --path . --script res://art/models/characters/bosses/ashmouth/src/make_ashmouth.gd -- materials
##   godot --headless --path . --script res://art/models/characters/bosses/ashmouth/src/make_ashmouth.gd -- scenes
## Shared logic: ../../tools/boss_toon.gd. AD palette: brass, bone, greys, pewter; accents in their own slots.

const BT := preload("res://art/models/characters/bosses/tools/boss_toon.gd")
const R := "res://art/models/characters/bosses/ashmouth/"
const PUFF_FX := "res://scripts/fx/ashmouth_puff_fx.gd"  # VFX Dev, PR #165 (not copied here)
const SLOT_NAMES: Array[String] = ["ash_iron", "ash_iron_dark", "ash_skin", "ash_sleeve", "ash_brass", "ash_soot", "ash_coal", "ash_eye", "ash_tash"]
static func slots() -> Dictionary:
	return {
		"ash_iron": BT.cloth(0.28, {"rim_strength": 0.45}),
		"ash_iron_dark": BT.cloth(0.14),  # firebox door: cold iron
		"ash_skin": BT.skin(),
		"ash_sleeve": BT.cloth(0.45),
		"ash_brass": BT.brass(),
		"ash_soot": BT.cloth(0.20, {"rim_strength": 0.0}),  # firebox mouth + pipe throat: UNLIT, no rim, no emission
		"ash_coal": BT.cloth(0.42, {"rim_strength": 0.0}),  # grate coals: cold grey, never a glow
		"ash_eye": BT.eye(),
		"ash_tash": BT.bone({"albedo": Color("#CFC6B4"), "spec_size": 0.0, "spec_strength": 0.0}),
	}
const INKS := {"ash_eye": "none", "ash_coal": "thin", "ash_soot": "thin"}


func _initialize() -> void:
	var phase: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "materials"
	if phase == "materials":
		BT.materials(R, "ashmouth", slots(), INKS)
	elif phase == "slots":
		print("SLOTS " + " ".join(SLOT_NAMES))
	else:
		BT.scene(R, "ashmouth", "Ashmouth", {"sockets": [["PipeMouthAttach", "visor", "PipeMouth", Vector3(0, 0.026, -0.03)],
		["FireboxDoorAttach", "firebox_door", "FireboxDoor", Vector3(-0.075, 0, 0.028)]],
		"fx": [["AshmouthPuffFx", PUFF_FX]]})
	print("make_ashmouth: done (%s)" % phase)
	quit()
