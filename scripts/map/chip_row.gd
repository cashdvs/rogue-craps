## Owned-chip HUD row (AD chips_3d_nov5 §4): up to 3 discs at 36 px under the
## Soul/Embers bar. Empty slots are a 1 px #6E6046 ring. Fire = scale pop only
## (1.0 → 1.12 over 90 ms, back over 140 ms); no glow.
class_name ChipRow
extends HBoxContainer

const SLOT := 36.0
const EMPTY := Color("#6E6046")
const POP_UP := 0.09
const POP_DOWN := 0.14

var _discs: Array[Control] = []


## Attach under `host`'s top bar. Keeps run_screen.gd under the line budget.
static func attach(host: Node, chips: Array[StringName]) -> ChipRow:
	var row := ChipRow.new()
	row.name = "ChipRow"
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(row)
	row.refresh(chips)
	return row


## Rebuild the three slots from `chips` (ids; empty pads to 3).
func refresh(chips: Array[StringName]) -> void:
	for c in get_children():
		c.queue_free()
	_discs.clear()
	for i in 3:
		var id: StringName = chips[i] if i < chips.size() else &""
		var slot := _slot(id)
		add_child(slot)
		_discs.append(slot)


## Scale-pop the disc at `i` (chip fired). No glow.
func pop(i: int) -> void:
	if i < 0 or i >= _discs.size():
		return
	var d := _discs[i]
	var tw := d.create_tween()
	tw.tween_property(d, "scale", Vector2.ONE * 1.12, POP_UP)
	tw.tween_property(d, "scale", Vector2.ONE, POP_DOWN)


func _slot(id: StringName) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2.ONE * SLOT
	wrap.pivot_offset = Vector2.ONE * SLOT * 0.5
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if id == &"" or not ChipLooks.has(id):
		wrap.draw.connect(func() -> void:
			wrap.draw_arc(wrap.size / 2.0, SLOT * 0.45, 0, TAU, 40, EMPTY, 1.0, true))
		return wrap
	# Live 3/4 chip via the shared shop SubViewport.
	var nm: String = str(ChipLooks.look(id).get("name", ""))
	var o := ShopOffer._make(ShopOffer.Kind.CHIP, 0, id, nm, id, 0)
	var icon := ShopIcon.new()
	icon.setup(o, SLOT)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(icon)
	return wrap
