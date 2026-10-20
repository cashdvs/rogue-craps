## The map key (design/first_time_clarity_v1.md §1): one line per node type
## plus the path and re-sit rules, docked on the map's right edge. Opens by
## itself on a profile's first map (RunProfile), collapsed from Floor 2 on;
## the Key button or K toggles it.
class_name MapKey
extends PanelContainer

## strings_v1 map_key_* lines, by node type, then the two footer lines.
const LINES := {
	MapGenData.NodeType.TABLE: "Table: claim every bounty for Embers and a free Seal.",
	MapGenData.NodeType.ELITE: "Elite: a harder table with a twist; win a special die.",
	MapGenData.NodeType.EVENT: "Event: a stranger offers a deal; pick one choice.",
	MapGenData.NodeType.SHOP: "Shop: spend Embers on dice, face mods and Seals.",
	MapGenData.NodeType.REST: "Rest: heal Soul, carve a free face mod, or level a Seal.",
	MapGenData.NodeType.BOSS: "Boss: beat the cheat to win a contract piece.",
}
const FOOTER := ["Move up a linked path; you can't go back.", "You get one re-sit; miss the boss twice and the run ends."]


func _init() -> void:
	var styled := RunTheme.panel()
	add_theme_stylebox_override("panel", styled.get_theme_stylebox("panel"))
	styled.free()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	custom_minimum_size = Vector2(360, 0)
	offset_left = -380
	offset_right = -20
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(RunTheme.label("Map key", 22, RunTheme.EMBER))
	for t in LINES:
		var l := RunTheme.label("%s  %s" % [MapView.GLYPHS[t], LINES[t]], 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	for f in FOOTER:
		var l := RunTheme.label(f, 15, RunTheme.ASH)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)


## Every line the key shows, in order (tests and tooltips).
static func all_lines() -> Array[String]:
	var out: Array[String] = []
	for t in LINES:
		out.append(LINES[t])
	out.append_array(FOOTER)
	return out
