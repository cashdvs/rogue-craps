extends SceneTree
## Collector toon-noir materials + wrapper scenes, templated on pit_boss/src/make_pit_boss.gd (order: rebuild_collector.sh):
##   godot --headless --path . --script res://art/models/characters/bosses/collector/src/make_collector.gd -- materials
##   godot --headless --path . --script res://art/models/characters/bosses/collector/src/make_collector.gd -- scenes
## Shared logic: ../../tools/boss_toon.gd. AD palette: brass, bone, greys, pewter; accents in their own slots.

const BT := preload("res://art/models/characters/bosses/tools/boss_toon.gd")
const R := "res://art/models/characters/bosses/collector/"
const SLOT_NAMES: Array[String] = ["col_fur", "col_fur_dark", "col_coat", "col_scarf", "col_brass", "col_bone", "col_glass", "col_eye", "col_black"]
static func slots() -> Dictionary:
	return {
		"col_fur": BT.cloth(0.50),
		"col_fur_dark": BT.cloth(0.30, {"rim_strength": 0.45}),  # ears: the silhouette key
		"col_coat": BT.cloth(0.22),
		"col_scarf": BT.cloth(0.62),
		"col_brass": BT.brass(),
		"col_bone": BT.bone(),
		"col_glass": BT.glass(0.80),  # cloche, as blocked (light grey glass, opaque toon)
		"col_eye": BT.eye(),
		"col_black": BT.cloth(0.11),
	}
const INKS := {"col_eye": "none", "col_black": "thin"}


func _initialize() -> void:
	var phase: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "materials"
	if phase == "materials":
		BT.materials(R, "collector", slots(), INKS)
	elif phase == "slots":
		print("SLOTS " + " ".join(SLOT_NAMES))
	else:
		BT.scene(R, "collector", "Collector")
	print("make_collector: done (%s)" % phase)
	quit()
