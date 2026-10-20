## Nerve's HUD (design/nerve_v1.md §3): the "Nerve" pip with its uses left
## and state, the up / down arrows over the picked die, and the bust-rescue
## prompt with its Nerve and Bust buttons. Plain Controls added to the
## Bonfire HUD; all the logic lives in NerveTable.
class_name NerveUi
extends Control

var nerve: NerveTable
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
	box.position = Vector2(40, 600)
	add_child(box)
	pip = Button.new()
	pip.name = "NervePip"
	pip.text = NerveText.get_text("nerve_button")
	pip.tooltip_text = NerveText.get_text("nerve_tooltip")
	pip.custom_minimum_size = Vector2(160, 48)
	pip.pressed.connect(func() -> void: nerve.arm())
	box.add_child(pip)
	pip_state = Label.new()
	pip_state.name = "NerveState"
	box.add_child(pip_state)
	up_button = _arrow("▲", NerveState.UP)
	down_button = _arrow("▼", NerveState.DOWN)
	rescue_panel = PanelContainer.new()
	rescue_panel.name = "NerveRescue"
	rescue_panel.position = Vector2(660, 380)
	add_child(rescue_panel)
	var col := VBoxContainer.new()
	rescue_panel.add_child(col)
	rescue_label = Label.new()
	rescue_label.text = NerveText.get_text("nerve_bust_save")
	col.add_child(rescue_label)
	var row := HBoxContainer.new()
	col.add_child(row)
	rescue_nerve = Button.new()
	rescue_nerve.text = NerveText.get_text("nerve_button")
	rescue_nerve.pressed.connect(func() -> void: nerve.arm())
	row.add_child(rescue_nerve)
	rescue_bust = Button.new()
	rescue_bust.text = "Bust"
	rescue_bust.pressed.connect(func() -> void: nerve.take_bust())
	row.add_child(rescue_bust)


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
	pip.disabled = left <= 0 or st.nudged_die() >= 0
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
	rescue_nerve.disabled = left <= 0 or st.nudged_die() >= 0
	_place_arrows()


func _process(_delta: float) -> void:
	# Follow the table (roll, intro, count-up hide it) and the picked die.
	if nerve != null and nerve.run != null:
		var v := nerve.can_show()
		if v != visible:
			refresh()
		elif visible and nerve.arrows_die >= 0:
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
