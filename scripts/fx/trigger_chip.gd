## A factor chip popped beside a trigger icon (e.g. Hellfire's "×1.5"): the
## Art Director's chip_x1_5 / x2 / x3 sprite (oxblood body, brass border,
## gold numerals: a gain never reads as a loss), else drawn the same way in
## code (Barlow Condensed Bold). Stand-in for the mini chip until JuicePlan's factor chip carries
## trigger mini icons (spec 1.3, "chip mini icons later").
class_name TriggerChip
extends Control

var text: String = ""
var font_px: float = 18.0
var _art: Texture2D
const ART := {"×1.5": "chip_x1_5", "×2": "chip_x2", "×3": "chip_x3"}
## Chip height in px at 720p (the 2:1 sprite is then 44 x 22).
const HEIGHT_720: float = 22.0


func setup(label: String, px_scale: float) -> void:
	text = label
	font_px = roundf(18.0 * px_scale)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art = TriggerShapes.fixed(ART[label]) if ART.has(label) else null
	if _art != null:
		var h := HEIGHT_720 * px_scale
		size = Vector2(h * _art.get_width() / float(_art.get_height()), h)
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()
		return
	var font := Palette.number_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_px)).x
	size = Vector2(w + font_px * 0.7, font_px * 1.25)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _art != null:
		draw_texture_rect(_art, r, false)
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#4A1418")
	sb.border_color = Color("#C9A24A")
	sb.set_border_width_all(maxi(2, int(font_px * 0.11)))
	sb.set_corner_radius_all(int(size.y * 0.5))
	draw_style_box(sb, r)
	var font := Palette.number_font()
	var base := Vector2(font_px * 0.35, size.y * 0.5 + font_px * 0.36)
	draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_px), maxi(2, int(font_px * 0.15)), TriggerFxDefs.OXBLOOD)
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_px), Color("#FFD36A"))
