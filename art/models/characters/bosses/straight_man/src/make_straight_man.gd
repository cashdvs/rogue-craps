extends SceneTree
## StraightMan toon-noir materials + wrapper scenes, templated on pit_boss/src/make_pit_boss.gd (order: rebuild_straight_man.sh):
##   godot --headless --path . --script res://art/models/characters/bosses/straight_man/src/make_straight_man.gd -- materials
##   godot --headless --path . --script res://art/models/characters/bosses/straight_man/src/make_straight_man.gd -- scenes
## Shared logic: ../../tools/boss_toon.gd. AD palette: brass, bone, greys, pewter; accents in their own slots.

const BT := preload("res://art/models/characters/bosses/tools/boss_toon.gd")
const R := "res://art/models/characters/bosses/straight_man/"
const SLOT_NAMES: Array[String] = ["sm_skin", "sm_suit", "sm_chalk", "sm_shirt", "sm_brass", "sm_bone", "sm_black", "sm_hair", "sm_eye", "sm_rod"]
static func slots() -> Dictionary:
	return {
		"sm_skin": BT.skin(),
		"sm_suit": BT.cloth(0.34),
		"sm_chalk": BT.cloth(0.72),
		"sm_shirt": BT.bone({"spec_size": 0.0, "spec_strength": 0.0}),
		"sm_brass": BT.brass(),
		"sm_bone": BT.bone({"shadow_color": Color("#787264"), "mid_tint": 0.8}),
		"sm_black": BT.cloth(0.11, {"rim_strength": 0.45}),
		"sm_hair": BT.cloth(0.18, {"rim_strength": 0.45}),
		"sm_eye": BT.eye(),
		"sm_rod": BT.pewter(),
	}
const INKS := {"sm_eye": "none", "sm_black": "thin", "sm_chalk": "thin"}


func _initialize() -> void:
	var phase: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "materials"
	if phase == "materials":
		BT.materials(R, "straight_man", slots(), INKS)
	elif phase == "slots":
		print("SLOTS " + " ".join(SLOT_NAMES))
	else:
		BT.scene(R, "straight_man", "StraightMan")
	print("make_straight_man: done (%s)" % phase)
	quit()
