## Art Director's 2D boss signs (Floor 3: Baron Vig, Odds Bodkin) and their
## HUD rule icons. Data lives on RunRuleData (sign_texture, sign_texture_2x,
## rule_icon, tooltip_text, sign_alt_text); a boss without them keeps the
## plain text panels and HUD row.
##  - Boss intro (RunScreen's table panel) and the table's pause menu: the
##    full sign, centred, ~1/3 of the layout width, never under 600x210
##    layout units; @2x when the window is 1080 px tall or more.
##  - Table HUD: the name plus the 128 px rule icon at ICON_PX, the rule's
##    description in a BossRuleTip (hover / focus / tap); a rule that states
##    a cost keeps its line visible instead (states_cost).
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
	_set_accessible(t, r.sign_alt())
	if r.sign_hand_pill:
		update_hand_pill(t, r)
	return t


## The "-1 HAND" brass pill over the sign's top-right corner (where the
## art leaves room), text from r.hands_delta; hidden when it is 0. Call
## again after hands_delta changes. Returns the pill Label.
static func update_hand_pill(sign_rect: TextureRect, r: RunRuleData) -> Label:
	var pill := sign_rect.get_node_or_null("HandPill") as Label
	if pill == null:
		pill = Label.new()
		pill.name = "HandPill"
		pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Same box as the art's old baked pill: 150x44 at (975, 74) of 1200x420.
		pill.anchor_left = 975.0 / 1200.0
		pill.anchor_right = 1125.0 / 1200.0
		pill.anchor_top = 74.0 / 420.0
		pill.anchor_bottom = 118.0 / 420.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = Palette.BRASS
		sb.border_color = Palette.BRASS_HI
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(999)
		pill.add_theme_stylebox_override("normal", sb)
		var ls := LabelSettings.new()
		ls.font = Palette.number_font()
		ls.font_color = Palette.OXBLOOD
		pill.label_settings = ls
		sign_rect.add_child(pill)
	pill.text = r.hand_pill_text()
	pill.visible = pill.text != ""
	pill.label_settings.font_size = maxi(10, int(sign_rect.custom_minimum_size.y * 32.0 / 420.0))
	_set_accessible(sign_rect, r.sign_alt())
	return pill


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


## Boss id -> the twist handler id it used before #99, so a table entry
## like greedy_pot {min_pot: 3} still finds Baron Vig.
const LEGACY_RULE_IDS := {&"baron_vig": &"greedy_pot", &"odds_bodkin": &"first_throw"}

## The art-carrying boss behind a table rule {id, params}, or null. Matches
## the resource's id and params (Baron Vig is greedy_pot {min_pot: 3}, the
## Elite twist is greedy_pot {min_pot: 2}), or the boss's own id
## (baron_vig / odds_bodkin, as TableRules registers them since #99).
## The old rule+params form still works through LEGACY_RULE_IDS.
static func for_table_rule(id: StringName, params: Dictionary = {}) -> RunRuleData:
	for path in ART_RULES:
		var r := load(path) as RunRuleData
		if r == null:
			continue
		if StringName(path.get_file().get_basename()) == id:
			return r
		if (r.id == id or LEGACY_RULE_IDS.get(r.id, &"") == id) and _params_match(r.params, params):
			return r
	return null


static func _params_match(want: Dictionary, have: Dictionary) -> bool:
	for k in want:
		if not have.has(k) or str(have[k]) != str(want[k]):
			return false
	return true


## HUD hook: for an art-carrying rule, put the icon before the name and
## show the boss's name. The rule line then moves into a BossRuleTip
## (hover / focus / tap; hidden while paused), unless the rule states a
## cost (states_cost), which keeps the line visible. Returns false and
## changes nothing otherwise (the row keeps today's text).
static func decorate_hud_row(row: Control, name_l: Label, line: Label, id: StringName, params: Dictionary) -> bool:
	return decorate_with(row, name_l, line, for_table_rule(id, params))


## decorate_hud_row() for a known rule resource `r` (null = no change).
static func decorate_with(row: Control, name_l: Label, line: Label, r: RunRuleData) -> bool:
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
	var rule_line := r.description
	_set_accessible(row, "%s. %s" % [r.display_name, rule_line])
	if line != null:
		line.text = rule_line
		line.visible = states_cost(r)
	if line == null or not line.visible:
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.focus_mode = Control.FOCUS_ALL
		BossRuleTip.new(rule_line).attach(row)
		row.gui_input.connect(func(e: InputEvent) -> void:
			if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
				row.grab_focus())
	return true


## Does `r` state a cost the player must always see (HUD line stays up)?
## hud_always_show_line, a bust cost (bust_soul_loss), a soul / ember /
## cost param, or "soul", "ember" or "cost" in its description.
static func states_cost(r: RunRuleData) -> bool:
	if r == null:
		return false
	if r.hud_always_show_line or r.bust_soul_loss >= 0:
		return true
	for k in r.params:
		var key := String(k).to_lower()
		if key.contains("soul") or key.contains("ember") or key.contains("cost"):
			return true
	var re := RegEx.create_from_string("\\b(soul|souls|ember|embers|cost|costs)\\b")
	return re.search(r.description.to_lower()) != null


static func _set_accessible(c: Control, text: String) -> void:
	if "accessibility_name" in c:
		c.set("accessibility_name", text)
