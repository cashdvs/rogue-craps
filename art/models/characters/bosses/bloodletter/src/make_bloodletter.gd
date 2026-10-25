extends SceneTree
## Bloodletter toon-noir materials + wrapper scenes, templated on pit_boss/src/make_pit_boss.gd (order: rebuild_bloodletter.sh):
##   godot --headless --path . --script res://art/models/characters/bosses/bloodletter/src/make_bloodletter.gd -- materials
##   godot --headless --path . --script res://art/models/characters/bosses/bloodletter/src/make_bloodletter.gd -- scenes
## Shared logic: ../../tools/boss_toon.gd. AD palette: brass, bone, greys, pewter; accents in their own slots.

const BT := preload("res://art/models/characters/bosses/tools/boss_toon.gd")
const R := "res://art/models/characters/bosses/bloodletter/"
const SLOT_NAMES: Array[String] = ["bl_skin", "bl_coat", "bl_apron", "bl_collar", "bl_brass", "bl_bone", "bl_hair", "bl_eye", "bl_glass", "bl_silver", "bl_pewter"]
static func slots() -> Dictionary:
	return {
		"bl_skin": BT.skin(),
		"bl_coat": BT.cloth(0.30),
		"bl_apron": BT.cloth(0.80),
		"bl_collar": BT.bone({"spec_size": 0.0, "spec_strength": 0.0}),
		"bl_brass": BT.brass(),
		"bl_bone": BT.bone(),
		"bl_hair": BT.cloth(0.45),
		"bl_eye": BT.eye(),
		"bl_glass": BT.glass(0.55),  # spectacle lenses, as blocked
		"bl_silver": BT.pewter({"albedo": Color("#C9CCCE"), "spec_strength": 0.6}),  # lancet blade, as blocked
		"bl_pewter": BT.pewter(),
	}
const INKS := {"bl_eye": "none", "bl_glass": "thin", "bl_silver": "thin"}


func _initialize() -> void:
	var phase: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "materials"
	if phase == "materials":
		BT.materials(R, "bloodletter", slots(), INKS)
	elif phase == "slots":
		print("SLOTS " + " ".join(SLOT_NAMES))
	else:
		BT.scene(R, "bloodletter", "Bloodletter")
	print("make_bloodletter: done (%s)" % phase)
	quit()
