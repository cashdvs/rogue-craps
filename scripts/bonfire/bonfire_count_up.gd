## The Bonfire count-up after a pot (bonfire_map_events_juice.md section 3,
## Balatro style): pips tick into a blue BASE counter that starts at the
## combo's base, the red MULT chip slams in (extra chips for Hot Hands and
## the Hellfire factor), the "x" sweeps across, the total counts up, then the
## combo banner tinted by tier. Timing comes from JuicePlan.timeline (caps
## 1.2 s / 2.0 s, 1x / 2x / Instant). fast_forward() jumps to the end.
## Each beat is a signal (BonfireJuice plays sounds / VFX on them).
class_name BonfireCountUp
extends Control

signal pip(index: int)
signal slam(chip: int)
signal sweep
signal count_tick(progress: float)
signal banner(score_tier: int, banner_tier: int)
signal finished

const BASE_BLUE := Color("#2E6FD8")
const MULT_RED := Color("#C8281E")

var row: HBoxContainer
var base_box: PanelContainer
var base_label: Label
var x_label: Label
var chips_box: HBoxContainer
var eq_label: Label
var total_label: Label
var banner_panel: PanelContainer
var banner_label: Label

var data: Dictionary = {}
var plan: Dictionary = {}
## Clock speed (tests: Table3D.test_speed).
var speed: float = 1.0
var reduced_motion: bool = false
var elapsed: float = 0.0
## Real seconds the last sequence took (tests).
var last_duration: float = 0.0
var fast_forwarded: bool = false
var _playing: bool = false
var _next_pip: int = 0
var _next_chip: int = 0
var _slammed: bool = false
var _swept: bool = false
var _bannered: bool = false
var _base_now: int = 0
var _start_ms: int = 0


func _init() -> void:
	name = "BonfireCountUp"
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.position = Vector2(560, 760)
	row.size = Vector2(800, 100)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	base_box = PanelContainer.new()
	base_box.add_theme_stylebox_override("panel", Palette.ink_box(BASE_BLUE, 14, 5))
	base_box.custom_minimum_size = Vector2(170, 86)
	row.add_child(base_box)
	base_label = _lab(52, Palette.BONE)
	base_box.add_child(base_label)
	x_label = _lab(56, Palette.BONE)
	x_label.text = "x"
	row.add_child(x_label)
	chips_box = HBoxContainer.new()
	chips_box.add_theme_constant_override("separation", 8)
	row.add_child(chips_box)
	eq_label = _lab(56, Palette.BONE)
	eq_label.text = "="
	row.add_child(eq_label)
	total_label = _lab(64, Palette.BRASS_HI)
	total_label.custom_minimum_size = Vector2(200, 0)
	row.add_child(total_label)
	banner_panel = PanelContainer.new()
	banner_panel.position = Vector2(610, 620)
	banner_panel.custom_minimum_size = Vector2(700, 110)
	banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_panel)
	banner_label = _lab(76, Palette.PIT_BLACK, true)
	banner_panel.add_child(banner_label)
	_hide_all()


func _lab(px: int, col: Color, display: bool = false) -> Label:
	var l := Label.new()
	l.label_settings = Palette.label_settings(px, col, 7, display)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _hide_all() -> void:
	row.modulate.a = 0.0
	banner_panel.modulate.a = 0.0


func is_playing() -> bool:
	return _playing


## data: {base: int (combo base incl. Stair), values: Array[int] (one pip each),
## chips: JuicePlan.chips(), points, name, score_tier, banner_tier}.
func play(d: Dictionary, p: Dictionary, clock_speed: float = 1.0, reduced: bool = false) -> void:
	if _playing:
		fast_forward()
	data = d
	plan = p
	speed = maxf(clock_speed, 0.001)
	reduced_motion = reduced
	elapsed = 0.0
	fast_forwarded = false
	_next_pip = 0
	_next_chip = 0
	_slammed = false
	_swept = false
	_bannered = false
	_base_now = int(d.get("base", 0))
	_start_ms = Time.get_ticks_msec()
	base_label.text = "%d" % _base_now
	for c in chips_box.get_children():
		chips_box.remove_child(c)
		c.queue_free()
	x_label.modulate.a = 0.0
	eq_label.modulate.a = 0.0
	total_label.text = ""
	banner_panel.modulate.a = 0.0
	row.modulate.a = 1.0
	_playing = true


func _process(delta: float) -> void:
	if not _playing:
		return
	elapsed += delta / maxf(Engine.time_scale, 0.001) * speed
	_advance(elapsed)


func _advance(now: float) -> void:
	var pips: Array = plan.get("pips", [])
	var vals: Array = data.get("values", [])
	while _next_pip < pips.size() and now >= float(pips[_next_pip]):
		_tick_pip(_next_pip, vals)
		_next_pip += 1
	if not _slammed and now >= float(plan.get("slam", 0.0)) and _next_pip >= pips.size():
		_do_slam(0)
	var extra: Array = plan.get("chips", [])
	while _slammed and _next_chip < extra.size() and now >= float(extra[_next_chip]):
		_next_chip += 1
		_do_slam(_next_chip)
	if not _swept and now >= float(plan.get("sweep", 0.0)) and _slammed and _next_chip >= extra.size():
		_do_sweep()
	var cs := float(plan.get("count_start", 0.0))
	var ce := float(plan.get("count_end", 0.0))
	if _swept and now >= cs and not _bannered:
		var f := 1.0 if ce <= cs else clampf((now - cs) / (ce - cs), 0.0, 1.0)
		total_label.text = "%d" % int(round(int(data.get("points", 0)) * f))
		count_tick.emit(f)
	if _swept and not _bannered and now >= float(plan.get("banner", 0.0)):
		_do_banner()
	if _bannered and now >= float(plan.get("end", 0.0)):
		_finish()


func _tick_pip(i: int, vals: Array) -> void:
	if i < vals.size():
		_base_now += int(vals[i])
	base_label.text = "%d" % _base_now
	_punch(base_box, 1.18)
	pip.emit(i)


func _do_slam(k: int) -> void:
	if k == 0:
		_slammed = true
	var chip_list: Array = data.get("chips", [])
	if k < chip_list.size():
		var c: Dictionary = chip_list[k]
		var p := PanelContainer.new()
		var col := MULT_RED if c.get("kind") != &"hot" else Palette.EMBER
		if c.get("kind") == &"factor":
			col = Color("#8E0F1C")
		p.add_theme_stylebox_override("panel", Palette.ink_box(col, 43, 5))
		p.custom_minimum_size = Vector2(110, 86)
		var l := _lab(40 if k > 0 else 50, Palette.BONE)
		l.text = str(c.get("text", ""))
		p.add_child(l)
		chips_box.add_child(p)
		_punch(p, 1.9 if not reduced_motion else 1.15)
	slam.emit(k)


func _do_sweep() -> void:
	_swept = true
	x_label.modulate.a = 1.0
	eq_label.modulate.a = 1.0
	if not reduced_motion:
		x_label.position.x -= 60.0
		var tw := create_tween().set_ignore_time_scale(true)
		tw.tween_property(x_label, "position:x", x_label.position.x + 60.0, 0.1 / speed)
	sweep.emit()


func _do_banner() -> void:
	_bannered = true
	total_label.text = "%d" % int(data.get("points", 0))
	var bt := clampi(int(data.get("banner_tier", 0)), 0, 3)
	var cols: Array = JuicePlan.BANNER_COLORS[bt]
	banner_panel.add_theme_stylebox_override("panel", Palette.ink_box(cols[0], 14, 6, cols[2]))
	banner_label.label_settings.font_color = JuicePlan.BANNER_TEXT[bt]
	banner_label.label_settings.outline_color = cols[3] if bt < 2 else cols[2]
	banner_label.text = "%s!" % str(data.get("name", "")).to_upper()
	banner_panel.modulate.a = 1.0
	if not reduced_motion:
		var x0 := banner_panel.position.x
		banner_panel.position.x = x0 - 320.0
		var tw := create_tween().set_ignore_time_scale(true)
		tw.tween_property(banner_panel, "position:x", x0, 0.12 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner.emit(int(data.get("score_tier", 0)), bt)


func _finish() -> void:
	_playing = false
	last_duration = (Time.get_ticks_msec() - _start_ms) / 1000.0
	finished.emit()


## Tap / click: skip the remaining ticks; the slam (if not yet), the final
## numbers and the banner happen now.
func fast_forward() -> void:
	if not _playing:
		return
	fast_forwarded = true
	var pips: Array = plan.get("pips", [])
	var vals: Array = data.get("values", [])
	# Remaining pips count silently.
	while _next_pip < pips.size():
		if _next_pip < vals.size():
			_base_now += int(vals[_next_pip])
		_next_pip += 1
	base_label.text = "%d" % _base_now
	if not _slammed:
		_do_slam(0)
	var chip_list: Array = data.get("chips", [])
	while _next_chip + 1 < chip_list.size():
		_next_chip += 1
		var c: Dictionary = chip_list[_next_chip]
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Palette.ink_box(MULT_RED if c.get("kind") != &"hot" else Palette.EMBER, 43, 5))
		p.custom_minimum_size = Vector2(110, 86)
		var l := _lab(40, Palette.BONE)
		l.text = str(c.get("text", ""))
		p.add_child(l)
		chips_box.add_child(p)
	if not _swept:
		_swept = true
		x_label.modulate.a = 1.0
		eq_label.modulate.a = 1.0
	if not _bannered:
		_do_banner()
	_finish()


## Fades the row and banner out (the hand ended).
func clear(fade: float = 0.25) -> void:
	if _playing:
		fast_forward()
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(row, "modulate:a", 0.0, fade)
	tw.tween_property(banner_panel, "modulate:a", 0.0, fade)


func _punch(c: Control, peak: float) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * peak
	var tw := c.create_tween().set_ignore_time_scale(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12 / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
