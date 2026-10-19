## The event screen: title, art slot (the art, or a placeholder showing the
## art note), body text and 2-3 choices. A choice you can't take is greyed
## out with the reason as a tooltip. Choices that need a face picked open a
## FacePicker first. View only: emits choice_made(i, picks).
class_name EventView
extends Control

signal choice_made(index: int, picks: Array[Vector2i])

var _box: VBoxContainer
var _event: EventData
var _progress: RunProgress


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := RunTheme.panel()
	panel.custom_minimum_size = Vector2(1100, 0)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	panel.add_child(_box)


func show_event(e: EventData, p: RunProgress) -> void:
	_event = e
	_progress = p
	_clear()
	_box.add_child(RunTheme.label(e.title, 44, RunTheme.EMBER, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.add_child(_art(e))
	var body := RunTheme.label(e.body, 26)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	_box.add_child(row)
	for i in e.choices.size():
		var c := e.choices[i]
		var b := RunTheme.button(c.label)
		var why := EventApplier.why_not(c, p)
		b.disabled = why != ""
		b.tooltip_text = why
		b.pressed.connect(_on_choice.bind(i))
		_box.add_child(b)
		if why != "":
			_box.add_child(RunTheme.label("   " + why, 18, RunTheme.ASH))


func show_result(text: String, lines: Array[String], done: Callable) -> void:
	_clear()
	_box.add_child(RunTheme.label(_event.title, 40, RunTheme.EMBER, true))
	_box.add_child(RunTheme.label(text, 26))
	_box.add_child(RunTheme.label("\n".join(lines), 22, RunTheme.GOLD))
	var b := RunTheme.button("Back to the map")
	b.pressed.connect(done)
	_box.add_child(b)


func _art(e: EventData) -> Control:
	if e.art != null:
		var t := TextureRect.new()
		t.texture = e.art
		t.custom_minimum_size = Vector2(320, 320)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return t
	# Placeholder art slot: a framed dark card with the art note on it.
	var slot := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.02)
	sb.border_color = RunTheme.GOLD.darkened(0.3)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(18)
	slot.add_theme_stylebox_override("panel", sb)
	slot.custom_minimum_size = Vector2(320, 320)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(RunTheme.label("ART PLACEHOLDER", 20, RunTheme.EMBER))
	v.add_child(RunTheme.label(e.art_note, 20, RunTheme.ASH))
	slot.add_child(v)
	return slot


func _on_choice(i: int) -> void:
	var c := _event.choices[i]
	var picks: Array[Vector2i] = []
	for e in c.effects:
		if not e.needs_pick():
			continue
		var picker := FacePicker.new()
		var verb: String = "Pick a face to give up" if e.kind == EventEffectData.Kind.REMOVE_FACE_MOD \
			else "Pick a face for the %s" % e.mod.display_name
		picker.build(_progress, verb, func(at: Vector2i) -> bool: return EventApplier.pick_ok(e, _progress, at) and not picks.has(at))
		_clear()
		_box.add_child(RunTheme.label(_event.title, 40, RunTheme.EMBER, true))
		_box.add_child(picker)
		var back := RunTheme.button("Back")
		back.pressed.connect(func() -> void: show_event(_event, _progress))
		_box.add_child(back)
		picks.append(await picker.picked)
	choice_made.emit(i, picks)


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
