## Pieces of RunScreen's table preview and map, split out to keep
## run_screen.gd small: the boss rule line, the mini dice row and the boss
## intro sign that replaces the panel title.
class_name TablePreview
extends RefCounted


## The floor boss's cheat (and Floor 3's extra twist), for the map.
static func boss_rules(run: MapRun) -> String:
	var out: Array[String] = []
	if run.boss != null:
		out.append(run.boss.description)
	if run.boss_twist != null:
		out.append("Twist: %s - %s" % [run.boss_twist.display_name, run.boss_twist.description])
	return " / ".join(out)


## The mini dice row for `progress`; a tile calls `on_open` (Your dice).
static func dice_row(progress: RunProgress, on_open: Callable) -> MiniDiceRow:
	var row := MiniDiceRow.new()
	row.build(progress)
	row.opened.connect(on_open)
	return row


## Put the boss's intro sign (BossSign) in place of `box`'s title label;
## returns it, or null when the boss has no sign (the title stays).
static func add_boss_sign(box: VBoxContainer, run: MapRun, px_height: int, layout_width: float) -> TextureRect:
	var sign := BossSign.make_sign(run.boss, px_height, layout_width)
	if sign == null:
		return null
	var title := box.get_child(0)
	box.remove_child(title)
	title.queue_free()
	box.add_child(sign)
	box.move_child(sign, 0)
	return sign
