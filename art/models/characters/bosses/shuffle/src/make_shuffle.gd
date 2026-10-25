extends SceneTree
## Shuffle toon-noir materials + wrapper scenes, templated on pit_boss/src/make_pit_boss.gd (order: rebuild_shuffle.sh):
##   godot --headless --path . --script res://art/models/characters/bosses/shuffle/src/make_shuffle.gd -- materials
##   godot --headless --path . --script res://art/models/characters/bosses/shuffle/src/make_shuffle.gd -- scenes
## Shared logic: ../../tools/boss_toon.gd. AD palette: brass, bone, greys, pewter; accents in their own slots.

const BT := preload("res://art/models/characters/bosses/tools/boss_toon.gd")
const R := "res://art/models/characters/bosses/shuffle/"
const SLOT_NAMES: Array[String] = ["shuffle_skin", "shuffle_gown", "shuffle_glove", "shuffle_hair", "shuffle_trim", "shuffle_eye", "shuffle_lip", "shuffle_card", "shuffle_cardback"]
static func slots() -> Dictionary:
	return {
		"shuffle_skin": BT.skin(),
		"shuffle_gown": BT.cloth(0.34),
		"shuffle_glove": BT.bone({"spec_size": 0.0, "spec_strength": 0.0}),
		"shuffle_hair": BT.cloth(0.22, {"rim_strength": 0.45}),  # hair tower: its silhouette is the read
		"shuffle_trim": BT.brass(),
		"shuffle_eye": BT.eye(),
		"shuffle_lip": BT.base(Color("#7E7870"), Color("#3A3732")),
		"shuffle_card": BT.bone({"shadow_color": Color("#787264"), "mid_tint": 0.8}),
		"shuffle_cardback": BT.pewter({"spec_size": 0.0, "spec_strength": 0.0}),
	}
const INKS := {"shuffle_eye": "none", "shuffle_lip": "none", "shuffle_cardback": "thin", "shuffle_card": "thin"}


func _initialize() -> void:
	var phase: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "materials"
	if phase == "materials":
		BT.materials(R, "shuffle", slots(), INKS)
	elif phase == "slots":
		print("SLOTS " + " ".join(SLOT_NAMES))
	else:
		BT.scene(R, "shuffle", "Shuffle")
	print("make_shuffle: done (%s)" % phase)
	quit()
