## Colours, fonts and small widget helpers for the run screens (map, event,
## shop, rest): the underworld casino look, dark with ember and gold.
class_name RunTheme
extends RefCounted

const BG := Color(0.05, 0.035, 0.045)
const PANEL := Color(0.11, 0.07, 0.07, 0.94)
const EMBER := Color(1.0, 0.42, 0.1)
const GOLD := Color(0.91, 0.69, 0.29)
const BONE := Color(0.91, 0.87, 0.78)
const ASH := Color(0.45, 0.4, 0.4)
const BLOOD := Color(0.75, 0.12, 0.12)

static var title_font: Font = load("res://fonts/AlfaSlabOne-Regular.ttf")
static var body_font: Font = load("res://fonts/BarlowCondensed-SemiBold.ttf")


static func label(text: String, size: int = 26, color: Color = BONE, title: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font if title else body_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", body_font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", BONE)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_disabled_color", ASH)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.08, 0.06) if state != "hover" else Color(0.26, 0.11, 0.06)
		if state == "disabled":
			sb.bg_color = Color(0.09, 0.07, 0.07)
		if state == "focus":
			sb.draw_center = false
		sb.border_color = GOLD if state == "hover" else Color(0.5, 0.3, 0.15)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override(state, sb)
	return b


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = Color(0.55, 0.32, 0.12)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(28)
	p.add_theme_stylebox_override("panel", sb)
	return p
