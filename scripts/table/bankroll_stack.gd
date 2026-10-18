## Bankroll + chip stack, bottom-left (poc_feel.md 1, 3). Click to add a chip
## to the Pass Line, right-click to take the bet down. Shakes on refusal.
class_name BankrollStack
extends Control

signal add_chip_requested
signal take_down_requested

const STACK_POS := Vector2(70, 105)  # local: bottom chip center
const MAX_VISIBLE: int = 10

## Shown value (animated count-up). Set target with show_coin().
var displayed: float = 0.0
var chip_value: int = 5
var target_coin: int = 40
var hover: bool = false
var _shake_t: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	position = Vector2(60, 900)
	size = Vector2(300, 140)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: hover = true)
	mouse_exited.connect(func() -> void: hover = false)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func show_coin(coin: int, seconds: float = 0.4) -> void:
	if seconds <= 0.0:
		displayed = coin
		return
	var tw := create_tween()
	tw.tween_property(self, "displayed", float(coin), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func refuse_shake() -> void:
	_shake_t = 0.25


## Where the top chip of the stack sits (global), for chip tweens.
func top_chip_global() -> Vector2:
	var n := mini(int(displayed) / maxi(chip_value, 1), MAX_VISIBLE)
	return global_position + STACK_POS + Vector2(0, ChipView.STACK_STEP * n)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			add_chip_requested.emit()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			take_down_requested.emit()
			accept_event()


func _process(delta: float) -> void:
	_shake_t = maxf(_shake_t - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var off := Vector2.ZERO
	if _shake_t > 0.0:
		off = Vector2(_rng.randf_range(-5, 5), 0)
	draw_set_transform(off, 0.0, Vector2.ONE)
	draw_style_box(Palette.ink_box(Color(Palette.PIT_BLACK, 0.75), 18, 4, Palette.BRASS if hover else Color(Palette.BRASS, 0.5)), Rect2(Vector2.ZERO, size))
	var coin := int(round(displayed))
	@warning_ignore("integer_division")
	var chips := coin / maxi(chip_value, 1)
	var shown := mini(chips, MAX_VISIBLE)
	var col := ChipView.color_for(chip_value)
	for i in shown:
		var p := STACK_POS + Vector2(0, ChipView.STACK_STEP * i)
		draw_circle(p + Vector2(0, 3), ChipView.RADIUS + 2, Palette.PIT_BLACK)
		draw_circle(p, ChipView.RADIUS + 2, Palette.PIT_BLACK)
		draw_circle(p, ChipView.RADIUS - 1, col)
		draw_arc(p, ChipView.RADIUS - 10, 0.0, TAU, 28, Color(Palette.BONE, 0.7), 3.0)
	if chips > MAX_VISIBLE:
		Palette.draw_ink_text(self, STACK_POS + Vector2(0, ChipView.STACK_STEP * shown - 30), "x%d" % chips, 26, Palette.BONE, 6)
	Palette.draw_ink_text(self, Vector2(200, 30), "BANKROLL", 24, Palette.BRASS, 5)
	Palette.draw_ink_text(self, Vector2(200, 78), str(coin), 64, Palette.BONE, 10, true)
	Palette.draw_ink_text(self, Vector2(200, 120), "target %d" % target_coin, 22, Color(Palette.BONE, 0.8), 5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
