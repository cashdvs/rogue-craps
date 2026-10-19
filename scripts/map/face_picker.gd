## A grid of the handful's dice (rows) x faces 1-6 (columns) for picking one
## face, e.g. where to carve a mod. Each button shows the face's mod (or its
## number); `allowed` decides which faces can be picked. View only.
class_name FacePicker
extends VBoxContainer

signal picked(at: Vector2i)


func build(progress: RunProgress, prompt: String, allowed: Callable) -> void:
	for c in get_children():
		c.queue_free()
	add_child(RunTheme.label(prompt, 24, RunTheme.GOLD))
	for d in progress.dice.size():
		var row := HBoxContainer.new()
		var die := progress.dice[d]
		var name: String = "Die %d%s" % [d + 1, "" if die.special_id == &"" else " (%s)" % die.special_id]
		var l := RunTheme.label(name, 20)
		l.custom_minimum_size.x = 190
		row.add_child(l)
		for f in 6:
			var mod: StringName = die.faces[f]
			var b := RunTheme.button(str(f + 1) if mod == &"" else String(mod).capitalize(), 18)
			b.custom_minimum_size = Vector2(92, 40)
			var at := Vector2i(d, f)
			b.disabled = not bool(allowed.call(at))
			b.pressed.connect(func() -> void: picked.emit(at))
			row.add_child(b)
		add_child(row)
