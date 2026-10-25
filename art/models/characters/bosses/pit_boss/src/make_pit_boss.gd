extends SceneTree
## Pit Boss toon-noir materials + wrapper scenes (reference dealer; see rebuild_pit_boss.sh for the order):
##   godot --headless --path . --script res://art/models/characters/bosses/pit_boss/src/make_pit_boss.gd -- materials
##   godot --headless --path . --script res://art/models/characters/bosses/pit_boss/src/make_pit_boss.gd -- scenes
## All shared logic lives in ../../tools/boss_toon.gd so the other five bosses only list their slots.

const BT := preload("res://art/models/characters/bosses/tools/boss_toon.gd")
const R := "res://art/models/characters/bosses/pit_boss/"
## glTF slot -> toon params. Skin is a warm bone-grey (AD: brass, bone, greys, pewter only).
static func slots() -> Dictionary:
	return {
		"pitboss_skin": BT.base(Color("#C2B9A8"), Color("#5A554C"), {"mid_tint": 0.74}),  # v2: +1 value step
		"pitboss_shirt": BT.bone({"spec_size": 0.0, "spec_strength": 0.0}),
		"pitboss_vest": BT.cloth(0.30),
		"pitboss_black": BT.cloth(0.11, {"rim_strength": 0.45}),
		"pitboss_brass": BT.brass(),
		"pitboss_bone": BT.bone({"shadow_color": Color("#787264"), "mid_tint": 0.8}),  # v2: plaque bone face lifted
		"pitboss_cap": BT.cloth(0.22),
		"pitboss_eye": BT.base(BT.grey(0.05), BT.grey(0.02), {"rim_strength": 0.0}),
		"pitboss_cigar": BT.base(Color("#625D57"), Color("#2A2826")),  # v2: +1 value step
		"pitboss_ash": BT.pewter({"albedo": Color("#9DA0A2"), "spec_size": 0.0, "spec_strength": 0.0}),
	}
## Un-inked (embedded) surfaces; numerals + cap band + cigar get the thin ink so they read at 48 px.
const INKS := {"pitboss_eye": "none", "pitboss_black": "thin", "pitboss_ash": "thin", "pitboss_cigar": "thin"}


func _initialize() -> void:
	var phase: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "materials"
	if phase == "materials":
		BT.materials(R, "pit_boss", slots(), INKS)
	else:
		BT.scene(R, "pit_boss", "PitBoss")
	print("make_pit_boss: done (%s)" % phase)
	quit()
