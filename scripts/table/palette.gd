## Art-direction palette and fonts (style_guide.md + poc_feel.md section 0).
## Soul Flame cyan is for the Soul meter ONLY; DANGER red is for loss ONLY.
class_name Palette
extends RefCounted

const OXBLOOD := Color("#3B0D14")
const BURGUNDY := Color("#6E1A24")
const EMBER := Color("#E8622A")
const UNDERFELT := Color("#123A36")
const PIT_BLACK := Color("#0E1414")
const BRASS := Color("#B08D3C")
const BONE := Color("#E8DCC0")
const SOUL_FLAME := Color("#4FE6E0")
const DANGER := Color("#FF2E3E")
# Derived (poc_feel.md).
const FELT_DARK := Color("#0B2724")
const FELT_STAIN := Color("#0F302C")
const RIM_WOOD := Color("#3A2416")
const RIM_WOOD_HI := Color("#5A3A24")
const BONE_SHADE := Color("#BFAF8E")
const BRASS_HI := Color("#E2C06A")
const SOUL_CORE := Color("#DFFFFD")
const SOUL_DEEP := Color("#1E8F8B")
const DANGER_DARK := Color("#8E0F1C")
const SMOKE := Color("#2A0608")

## Thick ink outline width.
const INK: float = 4.0

static var _display: Font
static var _numbers: Font


## Alfa Slab One (OFL): chunky labels and banners.
static func display_font() -> Font:
	if _display == null:
		_display = _load_font("res://fonts/AlfaSlabOne-Regular.ttf")
	return _display


## Barlow Condensed Bold (OFL): numbers and small UI.
static func number_font() -> Font:
	if _numbers == null:
		_numbers = _load_font("res://fonts/BarlowCondensed-Bold.ttf")
	return _numbers


static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f := load(path) as Font
		if f != null:
			return f
	return ThemeDB.fallback_font


## Outlined label style. display = Alfa Slab One, else Barlow Condensed.
static func label_settings(size: int, color: Color = BONE, outline: int = 6, display: bool = false) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = display_font() if display else number_font()
	s.font_size = size
	s.font_color = color
	s.outline_size = outline
	s.outline_color = PIT_BLACK
	s.shadow_size = 1
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_offset = Vector2(0, 4)
	return s


## A StyleBoxFlat with an ink border: the building block for panels/buttons.
static func ink_box(fill: Color, radius: int = 12, border: int = 4, border_color: Color = PIT_BLACK) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border_color
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


## Draws outlined text centered at pos on any CanvasItem.
static func draw_ink_text(ci: CanvasItem, pos: Vector2, text: String, size: int, color: Color = BONE, outline: int = 6, display: bool = false) -> void:
	var font := display_font() if display else number_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos + Vector2(-w * 0.5, size * 0.35)
	if outline > 0:
		ci.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, PIT_BLACK)
	ci.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
