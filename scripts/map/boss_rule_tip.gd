## The HUD rule tooltip on a BossSign row: the full rule line in a bounty
## card style box (FELT_DARK fill, thin BRASS border, BONE Barlow text).
## Shows after DELAY s of mouse hover or while the row has focus (pad /
## touch tap), and hides whenever the tree is paused (pause menu) or the row
## is hidden. Top-level, so the row's container never lays it out; it sits
## to the left of the row.
class_name BossRuleTip
extends PanelContainer

const DELAY: float = 0.4
const WIDTH: float = 360.0
const GAP: float = 12.0

var row: Control
var label: Label
var _hovering: bool = false
var _hover_t: float = 0.0


func _init(text: String) -> void:
	name = "RuleTip"
	top_level = true
	z_index = 50
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", style())
	label = Label.new()
	label.text = text
	label.label_settings = Palette.label_settings(22, Palette.BONE, 4)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


## The bounty card's box (BonfireHud._refresh_checklist) with text margins.
static func style() -> StyleBoxFlat:
	var sb := Palette.ink_box(Color(Palette.FELT_DARK, 0.9), 8, 2, Palette.BRASS)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


## Add the tip to `r` and follow its hover.
func attach(r: Control) -> void:
	row = r
	r.add_child(self)
	r.mouse_entered.connect(_on_enter)
	r.mouse_exited.connect(_on_exit)


func _on_enter() -> void:
	_hovering = true
	_hover_t = 0.0


func _on_exit() -> void:
	_hovering = false


## Should the tip be drawn now (hover past DELAY or focus; never paused)?
func wanted() -> bool:
	if row == null or not row.is_visible_in_tree() or get_tree() == null or get_tree().paused:
		return false
	return (_hovering and _hover_t >= DELAY) or row.has_focus()


func _process(delta: float) -> void:
	if _hovering:
		_hover_t += delta
	visible = wanted()
	if visible:
		reset_size()
		global_position = Vector2(row.global_position.x - size.x - GAP, row.global_position.y)
