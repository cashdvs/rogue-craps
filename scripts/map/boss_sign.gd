## Art Director's 2D boss signs (Floor 3: Baron Vig, Odds Bodkin) and their
## HUD rule icons. Data lives on RunRuleData (sign_texture, sign_texture_2x,
## rule_icon, tooltip_text, sign_alt_text); a boss without them keeps the
## plain text panels and HUD row.
##  - Boss intro (RunScreen's table panel) and the table's pause menu: the
##    full sign, centred, ~1/3 of the layout width, never under 600x210
##    layout units; @2x when the window is 1080 px tall or more.
##  - Table HUD: the name plus the 128 px rule icon at ICON_PX, the full
##    rule text as a tooltip (mouse) or shown on focus / tap (pad, touch).
## Linear filtering with mipmaps everywhere (never nearest).
class_name BossSign
extends RefCounted

## Bosses that carry sign art. The table only sees {id, params}, so
## for_table_rule() matches on these resources.
const ART_RULES: Array[String] = [
	"res://resources/map/rules/baron_vig.tres",
	"res://resources/map/rules/odds_bodkin.tres",
]
const MIN_SIZE := Vector2(600, 210)
const MAX_WIDTH: float = 720.0
const ICON_PX: int = 56
const FILTER := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Does `r` have a sign to show (either size)?
static func has_sign(r: RunRuleData) -> bool:
	return r != null and (r.sign_texture != null or r.sign_texture_2x != null)


## The sign texture for a window `px_height` pixels tall: @2x at 1080 and
## above, else @1x; falls back to whichever exists (null = no sign).
static func sign_texture(r: RunRuleData, px_height: int) -> Texture2D:
	if not has_sign(r):
		return null
	if px_height >= 1080 and r.sign_texture_2x != null:
		return r.sign_texture_2x
	return r.sign_texture if r.sign_texture != null else r.sign_texture_2x


## Sign size in layout units for a layout `width`: a third of it, clamped
## to 600..720 wide, at the art's 600:210 aspect.
static func sign_size(layout_width: float) -> Vector2:
	var w := clampf(layout_width / 3.0, MIN_SIZE.x, MAX_WIDTH)
	return Vector2(w, w * MIN_SIZE.y / MIN_SIZE.x)


## A centred TextureRect with `r`'s sign (null if it has none).
static func make_sign(r: RunRuleData, px_height: int, layout_width: float = 1920.0) -> TextureRect:
	var tex := sign_texture(r, px_height)
	if tex == null:
		return null
	var t := TextureRect.new()
	t.name = "BossSign"
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = sign_size(layout_width)
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.texture_filter = FILTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.tooltip_text = r.sign_alt_text
	_set_accessible(t, r.sign_alt_text)
	return t


## Put `r`'s sign under the pause menu's PAUSED title. Returns false (and
## leaves the menu alone) without a sign or if the menu's layout changed.
static func attach_to_pause(menu: PauseMenu, r: RunRuleData, px_height: int) -> bool:
	if menu == null or menu.panel == null or not has_sign(r):
		return false
	var m := menu.panel.get_child(0) if menu.panel.get_child_count() > 0 else null
	var box: Node = m.get_child(0) if m is MarginContainer and m.get_child_count() > 0 else null
	if not box is VBoxContainer:
		return false
	var tr := make_sign(r, px_height)
	box.add_child(tr)
	box.move_child(tr, 1)
	return true


## The art-carrying boss behind a table rule {id, params}, or null. Matches
## the resource's id and params (Baron Vig is greedy_pot {min_pot: 3}, the
## Elite twist is greedy_pot {min_pot: 2}), or the boss's own id
## (baron_vig / odds_bodkin, as TableRules may register them).
static func for_table_rule(id: StringName, params: Dictionary = {}) -> RunRuleData:
	for path in ART_RULES:
		var r := load(path) as RunRuleData
		if r == null:
			continue
		if StringName(path.get_file().get_basename()) == id:
			return r
		if r.id == id and _params_match(r.params, params):
			return r
	return null


static func _params_match(want: Dictionary, have: Dictionary) -> bool:
	for k in want:
		if not have.has(k) or str(have[k]) != str(want[k]):
			return false
	return true


## HUD hook: for an art-carrying rule, put the icon before the name, show
## the boss's name, hide the one-line text and move it (with the sign's
## wording) into a tooltip, shown on focus / tap too. Returns false and
## changes nothing otherwise (the row keeps today's text).
static func decorate_hud_row(row: Control, name_l: Label, line: Label, id: StringName, params: Dictionary) -> bool:
	var r := for_table_rule(id, params)
	if r == null or r.rule_icon == null or row == null or name_l == null or name_l.get_parent() != row:
		return false
	var head := HBoxContainer.new()
	head.name = "RuleHead"
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.name = "RuleIcon"
	icon.texture = r.rule_icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon.texture_filter = FILTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var at := name_l.get_index()
	row.remove_child(name_l)
	head.add_child(icon)
	head.add_child(name_l)
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_l.text = r.display_name.to_upper()
	row.add_child(head)
	row.move_child(head, at)
	var tip := hud_tooltip(r)
	row.tooltip_text = tip
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.focus_mode = Control.FOCUS_ALL
	_set_accessible(row, tip)
	if line != null:
		line.text = r.description
		line.visible = false
		row.focus_entered.connect(func() -> void: line.visible = true)
		row.focus_exited.connect(func() -> void: line.visible = false)
	row.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
			row.grab_focus())
	return true


## The HUD tooltip: name, the sign's rule line, then the full rule text.
static func hud_tooltip(r: RunRuleData) -> String:
	var parts: Array[String] = [r.display_name]
	if r.tooltip_text != "":
		parts.append(r.tooltip_text)
	if r.description != "":
		parts.append(r.description)
	return "\n".join(parts)


static func _set_accessible(c: Control, text: String) -> void:
	if "accessibility_name" in c:
		c.set("accessibility_name", text)
