## Nerve's HUD (design/nerve_v1.md §3): the "Nerve" pip with its uses left
## and state, the up / down arrows over the picked die, and the bust-rescue
## prompt with its Nerve and Bust buttons. Plain Controls added to the
## Bonfire HUD; all the logic lives in NerveTable.
class_name NerveUi
extends Control

var nerve: NerveTable
## The pip (button + state line), right of the Bank button.
var pip_box: VBoxContainer
## The pip: a button (it arms Nerve) that shows uses left and the state.
var pip: Button
var pip_state: Label
## The two arrows over the picked die.
var up_button: Button
var down_button: Button
## The rescue prompt (nerve_bust_save) with its two buttons.
var rescue_panel: PanelContainer
var rescue_label: Label
var rescue_nerve: Button
var rescue_bust: Button


## Space between the Nerve controls and the HUD buttons they sit beside
## (design px at 1920x1080; times the HUD's ui scale).
const GAP: float = 20.0
## Rescue prompt width (design px): the nerve_bust_save line wraps in it.
const RESCUE_W: float = 330.0
## Pip button size (design px).
const PIP_SIZE := Vector2(190, 52)
## Font size (design pt) of the Nerve text; times the HUD's ui_pt_px.
const FONT_PT: float = 11.0


## Hooks the HUD up to [param n] (the table's NerveTable): builds the pip,
## the arrows and the rescue prompt, then follows n.changed. Call once,
## after this node is added under the BonfireHud.
func setup(n: NerveTable) -> void:
	nerve = n
	name = "NerveUi"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	nerve.changed.connect(refresh)
	refresh()


func _build() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	pip_box = box
	add_child(box)
	pip = Button.new()
	pip.name = "NervePip"
	pip.text = NerveText.get_text("nerve_button")
	pip.tooltip_text = NerveText.get_text("nerve_tooltip")
	pip.custom_minimum_size = PIP_SIZE
	pip.pressed.connect(func() -> void: nerve.token_pressed())
	pip.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(pip)
	pip_state = Label.new()
	pip_state.name = "NerveState"
	pip_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(pip_state)
	up_button = _arrow("▲", NerveState.UP)
	down_button = _arrow("▼", NerveState.DOWN)
	rescue_panel = PanelContainer.new()
	rescue_panel.name = "NerveRescue"
	add_child(rescue_panel)
	var col := VBoxContainer.new()
	rescue_panel.add_child(col)
	rescue_label = Label.new()
	rescue_label.text = NerveText.get_text("nerve_bust_save")
	rescue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rescue_label.custom_minimum_size.x = RESCUE_W
	col.add_child(rescue_label)
	var row := HBoxContainer.new()
	col.add_child(row)
	rescue_nerve = Button.new()
	rescue_nerve.text = NerveText.get_text("nerve_button")
	rescue_nerve.pressed.connect(func() -> void: nerve.token_pressed())
	row.add_child(rescue_nerve)
	rescue_bust = Button.new()
	rescue_bust.text = "Bust"
	rescue_bust.pressed.connect(func() -> void: nerve.take_bust())
	row.add_child(rescue_bust)
	for b: Button in [rescue_nerve, rescue_bust]:
		b.custom_minimum_size = Vector2(150, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pip_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pip_state.custom_minimum_size.x = RESCUE_W


func _arrow(text: String, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(56, 44)
	b.visible = false
	b.pressed.connect(func() -> void:
		if nerve.arrows_die >= 0:
			nerve.nudge(nerve.arrows_die, dir))
	add_child(b)
	return b


## Shows / hides everything from NerveTable's state.
func refresh() -> void:
	if nerve == null or nerve.run == null:
		visible = false
		return
	visible = nerve.can_show()
	var st := nerve.state
	var left := st.uses_left()
	pip.text = "%s  %d" % [NerveText.get_text("nerve_button"), left]
	pip.disabled = not nerve.can_undo() and (left <= 0 or st.nudged_die() >= 0)  # enabled while it can undo
	match st.ui_state():
		NerveState.UiState.PICKING:
			pip_state.text = NerveText.get_text("nerve_pick")
		NerveState.UiState.NUDGED:
			pip_state.text = NerveText.get_text("nerve_undo")
		NerveState.UiState.SPENT:
			pip_state.text = NerveText.get_text("nerve_spent")
		_:
			pip_state.text = NerveText.get_text("nerve_pick") if nerve.armed else NerveText.get_text("nerve_ready")
	rescue_panel.visible = nerve.run.bust_pending
	# The rescue prompt has its own Nerve button: no pip beside it.
	pip_box.visible = not rescue_panel.visible
	_place_panels()
	rescue_nerve.disabled = not nerve.can_undo() and (left <= 0 or st.nudged_die() >= 0)  # enabled while it can undo
	_place_arrows()


func _process(_delta: float) -> void:
	# Follow the table (roll, intro, count-up hide it) and the picked die.
	if nerve != null and nerve.run != null:
		var v := nerve.can_show()
		if v != visible:
			refresh()
		elif visible:
			_place_panels()
			if nerve.arrows_die >= 0:
				_place_arrows()


## The arrows sit above the picked die; one that can't move is greyed out
## (can_nudge_dir) and its tooltip says why.
func _place_arrows() -> void:
	var i := nerve.arrows_die
	var shown: bool = visible and i >= 0 and i < nerve.table.throw_dice.size()
	up_button.visible = shown
	down_button.visible = shown
	if not shown:
		return
	var h := nerve.hid(i)
	var d: DieVisual = nerve.table.throw_dice[i]
	var at: Vector2 = nerve.table.camera.cam.unproject_position(d.global_position)
	up_button.position = at + Vector2(-28, -110)
	down_button.position = at + Vector2(-28, 50)
	for pair in [[up_button, NerveState.UP], [down_button, NerveState.DOWN]]:
		var b: Button = pair[0]
		var ok := nerve.state.can_nudge_dir(h, pair[1])
		b.disabled = not ok
		b.tooltip_text = "" if ok else NerveText.get_text(nerve.state.refusal(h, pair[1]))


## Puts the pip and the rescue prompt (one at a time) on the dark rail
## under the bounty cards, right-aligned with them (QA #126: clear of the
## Soul meter, the dealer, the cards and the pot text at 1920x1080,
## 1280x720 and phone portrait, where it goes under the goal readout).
## Sizes follow the HUD's ui scale so they match its buttons.
func _place_panels() -> void:
	var hud := get_parent() as BonfireHud
	if hud == null or hud.bank_button == null:
		return
	var k: float = hud.ui_pt_px / 2.0
	var font := int(round(FONT_PT * hud.ui_pt_px))
	for c: Control in [pip, pip_state, rescue_label, rescue_nerve, rescue_bust]:
		c.add_theme_font_size_override("font_size", font)
	pip.custom_minimum_size = PIP_SIZE * k
	pip_state.custom_minimum_size.x = RESCUE_W * k
	rescue_label.custom_minimum_size.x = RESCUE_W * k
	for b: Button in [rescue_nerve, rescue_bust]:
		b.custom_minimum_size = Vector2(150, 52) * k
	var gap := GAP * k
	_dodge_rules(hud)
	var above := _cards_rect(hud)
	if hud.rules_panel != null and hud.rules_panel.is_visible_in_tree():
		above = above.merge(hud.rules_panel.get_global_rect())  # QA: go under the rules plaque (Powder Barrel), not over it
	for c: Control in [pip_box, rescue_panel]:
		c.reset_size()
		var sz := c.get_combined_minimum_size()
		c.global_position = Vector2(above.end.x - sz.x, above.end.y + gap)
		var view := get_viewport_rect().size
		c.global_position.x = clampf(c.global_position.x, gap, maxf(gap, view.x - gap - sz.x))
		# PM / QA #198: never sit on a landed die (the phone d4 hid under
		# "Nerve ready") or on other text (the combo strip's "Five of a Kind").
		c.global_position = RulesPlaqueDodge.place(Rect2(c.global_position, sz), _blockers(hud), get_viewport_rect())


## QA #201: moves the rules plaque off any thrown die it covers (phone
## landscape, die near the right edge). Starts from the HUD's own spot each
## frame: if the HUD moved the plaque since, that is the new home.
func _dodge_rules(hud: BonfireHud) -> void:
	var p := hud.rules_panel
	if p == null or not p.is_visible_in_tree():
		return
	if not p.has_meta("dodged") or p.global_position != p.get_meta("dodged"):
		p.set_meta("home", p.global_position)
	var home: Vector2 = p.get_meta("home")
	p.global_position = RulesPlaqueDodge.place(Rect2(home, p.get_global_rect().size), _dice_rects(), get_viewport_rect())
	p.set_meta("dodged", p.global_position)


## What the pip / rescue panels must not cover: the landed dice and every
## other text on screen (HudTextRects), except the Nerve UI's own labels and
## the bounty cards they hang under (their home spot is just below those).
func _blockers(hud: BonfireHud) -> Array[Rect2]:
	var skip: Array[Node] = [self]
	for c: Control in hud.bounty_cards.values():
		skip.append(c)
	var out := _dice_rects()
	out.append_array(HudTextRects.collect(get_viewport(), nerve.table.camera.cam, skip))
	return out


## Screen rects of the thrown dice in view (what the panels must not cover).
func _dice_rects() -> Array[Rect2]:
	var dice: Array[Rect2] = []
	if nerve == null or nerve.table == null or nerve.table.camera == null:
		return dice
	var cam: Camera3D = nerve.table.camera.cam
	for d: DieVisual in nerve.table.throw_dice:
		if is_instance_valid(d) and d.is_visible_in_tree() and not cam.is_position_behind(d.global_position):
			dice.append(RulesPlaqueDodge.die_rect(cam, d))
	return dice


## The screen rect the Nerve controls go under: the bounty cards (PC,
## landscape) or the portrait goal readout.
func _cards_rect(hud: BonfireHud) -> Rect2:
	if hud.portrait_goal != null and hud.portrait_goal.visible:
		# Portrait: under the whole top stack (goal, buttons, pot line),
		# right-aligned on the felt.
		var r := hud.portrait_goal.get_global_rect()
		for c: Control in [hud.bank_button, hud.throw_button, hud.pot_label, hud.throw_label, hud.result_label, hud.tutorial]:
			if c != null and c.is_visible_in_tree():
				r = r.merge(c.get_global_rect())
		r.end.x = get_viewport_rect().size.x
		return r
	var r := Rect2()
	for c: Control in hud.bounty_cards.values():
		if c.is_visible_in_tree():
			r = c.get_global_rect() if r.size == Vector2.ZERO else r.merge(c.get_global_rect())
	return r if r.size != Vector2.ZERO else hud.points_label.get_global_rect()
