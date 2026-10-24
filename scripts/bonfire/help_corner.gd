## Top-left help (AD HANDOFF_SPEC Addendum A, G1).
##   - The controls text (the table's help_label) shows only on the run's
##     first table, until the first Bank or 30 s after the first pot, then
##     fades out (0.4 s; instant with reduced motion). Never again, unless
##     the player replays the tutorial.
##   - A round "?" button top-left (44 px: dark inlay, brass ring, cream "?")
##     or F1 opens a small controls card with a "Replay tutorial" link. It
##     never pauses the game.
class_name HelpCorner
extends Control

const BUTTON_SIZE := 44.0
const INLAY := Color("#141210")
const RING := Color("#C9A24A")
const CREAM := Color("#E8DCC0")
## Seconds after the first pot before the text fades on its own.
const POT_TIMEOUT := 30.0
const FADE_TIME := 0.4

## The table's controls text (Table3D.help_label); faded by this node.
var help_label: Label
var button: Button
var card: PanelContainer
var card_text: Label
var replay_button: Button
## True once the first-table text has been dismissed.
var dismissed: bool = false
var reduced_motion: bool = false
var _pot_timer: SceneTreeTimer


func _init() -> void:
	name = "HelpCorner"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button = Button.new()
	button.name = "HelpButton"
	button.text = "?"
	button.position = Vector2(24, 20)
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.tooltip_text = "Controls (F1)"
	var round := StyleBoxFlat.new()
	round.bg_color = INLAY
	round.border_color = RING
	round.set_border_width_all(3)
	round.set_corner_radius_all(int(BUTTON_SIZE / 2))
	for st in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(st, round)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(toggle_card)
	add_child(button)
	card = PanelContainer.new()
	card.name = "ControlsCard"
	card.position = Vector2(24, 74)
	card.visible = false
	var box := StyleBoxFlat.new()
	box.bg_color = INLAY
	box.border_color = RING
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", box)
	add_child(card)
	var col := VBoxContainer.new()
	card.add_child(col)
	card_text = Label.new()
	card_text.add_theme_color_override("font_color", CREAM)
	card_text.add_theme_font_size_override("font_size", 20)
	col.add_child(card_text)
	replay_button = Button.new()
	replay_button.name = "ReplayTutorial"
	replay_button.text = "Replay tutorial"
	replay_button.flat = true
	replay_button.add_theme_color_override("font_color", RING)
	replay_button.pressed.connect(replay_tutorial)
	col.add_child(replay_button)


## Called at each table start. [param first] = the run's first table.
func start_table(label: Label, first: bool, reduced: bool) -> void:
	help_label = label
	reduced_motion = reduced
	card_text.text = label.text
	card.visible = false
	_pot_timer = null
	dismissed = not first
	label.modulate.a = 1.0
	label.visible = first


## The first pot of the table: the text fades POT_TIMEOUT s later.
func on_pot() -> void:
	if dismissed or _pot_timer != null or not is_inside_tree():
		return
	_pot_timer = get_tree().create_timer(POT_TIMEOUT)
	_pot_timer.timeout.connect(dismiss)


## The first Bank (or the pot timeout): fade the controls text away.
func dismiss() -> void:
	if dismissed or help_label == null:
		return
	dismissed = true
	if reduced_motion or not is_inside_tree():
		help_label.visible = false
		return
	var tw := help_label.create_tween()
	tw.tween_property(help_label, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void: help_label.visible = false)


func toggle_card() -> void:
	card.visible = not card.visible


## The card's link: turns the Table 1 tutorial back on (the Settings flag).
func replay_tutorial() -> void:
	var gs := get_node_or_null("/root/GameSettings")
	if gs != null:
		gs.set_option(&"tutorial_enabled", true)
	card.visible = false


## G3: true when the white why-line only repeats the orange prompt, e.g.
## "Grab the 5 dice and flick them. Dice that can score glow." under
## "Grab the 5 dice and flick them.". Every word (3+ letters) of the
## prompt must be in the why-line's first sentence; unique info such as
## "4 lit. Click dice..." or risk odds is kept.
static func repeats_prompt(why: String, prompt: String) -> bool:
	var first := why.split(".")[0].to_lower()
	var have := _words(first)
	var need := _words(prompt.to_lower())
	if need.is_empty() or have.is_empty():
		return false
	for w in need:
		if not have.has(w):
			return false
	return true


static func _words(text: String) -> Array[String]:
	var out: Array[String] = []
	var word := ""
	for c in text + " ":
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			word += c
		else:
			if word.length() >= 3:
				out.append(word)
			word = ""
	return out
