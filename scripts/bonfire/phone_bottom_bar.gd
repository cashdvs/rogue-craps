## Phone landscape (844x390) bottom bar (#204, AD Oct 30): a dark strip along
## the bottom edge, 1 px brass hairline on top, holding the SEALS chip at its
## right end. PhoneFrame keeps the resting dice above it. Hidden elsewhere.
class_name PhoneBottomBar
extends Panel

## Bar height (pt).
const HEIGHT_PT := 44.0
## SEALS chip inset from the bar's right end (pt).
const SEALS_RIGHT_PT := 12.0


func _init() -> void:
	name = "PhoneBottomBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.PIT_BLACK, 0.82)
	sb.border_color = Palette.BRASS
	sb.border_width_top = 1
	add_theme_stylebox_override("panel", sb)


## Shows the bar on phone landscape (pt = design px per pt) and puts the
## SEALS chip in it; hides it on PC and portrait.
func place(hud: BonfireHud) -> void:
	visible = hud.is_phone_land
	if not visible:
		return
	var vs := hud.get_viewport_rect().size
	var pt := hud.ui_pt_px
	position = Vector2(0.0, vs.y - HEIGHT_PT * pt)
	size = Vector2(vs.x, HEIGHT_PT * pt)
	var chip := hud.target_plate.seals_chip
	chip.reset_size()
	chip.position = Vector2(vs.x - chip.size.x - SEALS_RIGHT_PT * pt, position.y + (size.y - chip.size.y) * 0.5)
